---
post_title: Radxa Cubie A5E Docker Host Bootstrap Guide
author1: Network Automation Team
post_slug: radxa-docker-bootstrap
microsoft_alias: network-automation
featured_image: https://example.com/images/radxa-cubie-a5e.png
categories:
  - infrastructure
tags:
  - radxa
  - docker
  - route-pi-squared
ai_note: Generated with AI assistance
summary: Deterministic procedure for preparing the Radxa Cubie A5E as the Docker-based Pi-hole node on VLAN 20.
post_date: 2025-10-07
---

## Overview

This guide defines the deterministic steps for preparing the Radxa Cubie A5E platform to host the Docker-based `pihole-docker` stack for Route Pi². It covers image flashing, kernel and firmware updates, Docker Engine provisioning, VLAN 20 tagging for the Pi-hole service network (`10.10.20.0/24`), and validation checkpoints. Execute every section in order to guarantee reproducible results.

## Prerequisites

- Radxa Cubie A5E board with eMMC or microSD boot media.
- Management workstation with access to the Radxa image repository (<https://docs.radxa.com/en/cubie/a5e>).
- USB-C power delivery adapter meeting Radxa specifications.
- LAN uplink that can trunk VLAN 20 alongside the management VLAN.
- Credentials for Route Pi² Git repository and configuration artefacts under `projects/route-pi-squared/`.

## Step 1: Flash the Base Operating System

1. Download the latest Debian-based Radxa image (or Armbian if officially recommended) for the Cubie A5E.
2. Verify the sha256 checksum published alongside the image.

   ```bash
   sha256sum -c radxa-cubie-debian.img.sha256
   ```

3. Flash the image to the target boot media.

   ```bash
   # Replace X with the removable media identifier on the workstation
   sudo dd if=radxa-cubie-debian.img of=/dev/sdX bs=8M status=progress conv=fsync
   ```
4. Insert the media into the Cubie A5E and power on.
5. Complete the first-boot wizard, ensuring the management interface receives an IP on the default VLAN.

## Step 2: Apply Firmware and Kernel Updates

1. Log in via SSH using the management IP.
2. Update package indexes and upgrade the base image.

   ```bash
   sudo apt-get update
   sudo apt-get -y dist-upgrade
   ```

3. Install Radxa firmware and kernel meta-packages if not already included:

   ```bash
   sudo apt-get install -y linux-image-current-radxa-aarch64 linux-headers-current-radxa-aarch64 radxa-firmware
   ```

4. Reboot and confirm the new kernel version:

   ```bash
   uname -a
   ```

## Step 3: Configure Network Interfaces with VLAN 20

1. Identify the primary Ethernet interface (typically `end0`).
2. Create a systemd-networkd configuration to extend VLAN 20:

   ```bash
   sudo tee /etc/systemd/network/20-end0.network > /dev/null <<'EOF'
   [Match]
   Name=end0

   [Network]
   DHCP=yes
   EOF

   sudo tee /etc/systemd/network/30-end0.20.netdev > /dev/null <<'EOF'
   [NetDev]
   Name=end0.20
   Kind=vlan

   [VLAN]
   Id=20
   EOF

   sudo tee /etc/systemd/network/40-end0.20.network > /dev/null <<'EOF'
   [Match]
   Name=end0.20

   [Network]
   Address=10.10.20.11/24
   Gateway=10.10.20.1
   DNS=127.0.0.1
   DNS=10.10.20.10
   EOF
   ```
3. Enable and restart systemd-networkd:

   ```bash
   sudo systemctl enable systemd-networkd.service
   sudo systemctl restart systemd-networkd.service
   ```
4. Validate connectivity to the Route Pi² router and the Proxmox Pi-hole node:

   ```bash
   ping -c 4 10.10.20.1
   ping -c 4 10.10.20.10
   ```

## Step 4: Harden the Base System

1. Create a dedicated automation user for repository interactions:

   ```bash
   sudo adduser --disabled-password --gecos "RoutePi Automation" routepi
   sudo usermod -aG sudo,docker routepi
   ```
2. Enforce unattended security updates:

   ```bash
   sudo apt-get install -y unattended-upgrades apt-listchanges
   sudo dpkg-reconfigure -plow unattended-upgrades
   ```

3. Configure basic firewall defaults (optional but recommended):

   ```bash
   sudo apt-get install -y nftables
   sudo tee /etc/nftables.conf > /dev/null <<'EOF'
   flush ruleset

   table inet filter {
     chain input {
       type filter hook input priority 0;
       policy drop;

       ct state established,related accept
       iifname "lo" accept
       ip saddr 10.10.0.0/18 accept
       ip6 saddr fc00::/7 accept
       tcp dport { 22, 80, 443 } accept
     }

     chain forward { type filter hook forward priority 0; policy drop; }
     chain output { type filter hook output priority 0; policy accept; }
   }
   EOF
   sudo systemctl enable --now nftables.service
   ```

## Step 5: Install Docker Engine

1. Install Docker repository prerequisites and the engine:

   ```bash
   sudo apt-get install -y ca-certificates curl gnupg lsb-release
   curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
   echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | \
     sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
   sudo apt-get update
   sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
   ```

2. Enable and start Docker:

   ```bash
   sudo systemctl enable --now docker.service
   sudo systemctl enable --now containerd.service
   ```

3. Add the automation account to the Docker group:

   ```bash
   sudo usermod -aG docker routepi
   ```

## Step 6: Prepare Pi-hole Deployment Artefacts

1. Create persistent storage directories for the Docker stack:

   ```bash
   sudo mkdir -p /srv/pihole-docker/etc-pihole
   sudo mkdir -p /srv/pihole-docker/etc-dnsmasq.d
   sudo chown -R routepi:routepi /srv/pihole-docker
   ```

2. Clone or update the Route Pi² repository under `/opt/route-pi-squared`:

   ```bash
   sudo mkdir -p /opt/route-pi-squared
   sudo chown routepi:routepi /opt/route-pi-squared
   # Replace <REPO_URL> with your actual Route Pi² Git repository URL
   sudo -u routepi git clone <REPO_URL> /opt/route-pi-squared
   ```

3. Symlink the compose manifest once authored:

   ```bash
   sudo ln -s /opt/route-pi-squared/projects/route-pi-squared/examples/docker/docker-compose.pihole.yaml \
     /srv/pihole-docker/docker-compose.yaml
   ```

## Step 7: Validate the Environment

1. Confirm Docker info and VLAN presence:

   ```bash
   docker info --format '{{.Name}}: {{.OperatingSystem}}'
   ip -d link show end0.20
   ```

2. Dry-run the Docker Compose stack once the manifest is available:

   ```bash
   docker compose --file /srv/pihole-docker/docker-compose.yaml config
   ```

3. Record the system state in Route Pi² documentation and update `projects/route-pi-squared/docs/hardware-inventory.md` with the Cubie A5E serial and interface mapping.

---

### Change Log

- 2025-10-07: Initial deterministic bootstrap procedure authored for Route Pi² deployment.
