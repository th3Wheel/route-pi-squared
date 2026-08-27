# Proxmox Docker Pi-hole Bootstrap Guide

This guide configures a Proxmox-hosted node (VM or nested LXC) to run Pi-hole in Docker.

## Prerequisites

- Debian 12 guest on Proxmox with static IP in your Route Pi² subnet.
- Root or sudo access in the guest.
- If using LXC: run as privileged LXC and enable nested container support on Proxmox host.

## 1. Proxmox LXC Settings (LXC only)

Run these commands on the Proxmox host before installing Docker in the LXC guest:

```bash
# Replace <CTID> with your container ID
pct set <CTID> -features nesting=1,keyctl=1
echo "lxc.apparmor.profile: unconfined" >> /etc/pve/lxc/<CTID>.conf
echo "lxc.cgroup2.devices.allow: a" >> /etc/pve/lxc/<CTID>.conf
echo "lxc.cap.drop:" >> /etc/pve/lxc/<CTID>.conf
```

Restart the LXC after changing the config:

```bash
pct restart <CTID>
```

## 2. Install Docker Engine

Run these commands inside the Proxmox guest:

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  $(. /etc/os-release && echo \"$VERSION_CODENAME\") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
sudo systemctl enable --now docker
```

## 3. Create Persistent Directories

```bash
sudo mkdir -p /srv/pihole-docker/pihole/etc-pihole
sudo mkdir -p /srv/pihole-docker/pihole/etc-dnsmasq.d
```

## 4. Deploy Compose Configuration

Copy the example compose file from this repository:

```bash
sudo cp examples/docker/docker-compose.pihole.proxmox.yaml /srv/pihole-docker/docker-compose.yaml
```

Set runtime variables before starting:

```bash
export PIHOLE_WEBPASSWORD='replace-with-strong-password'
export LOCAL_IPV4='10.10.20.12'
export TZ='UTC'
export PIHOLE_UPSTREAM_DNS='1.1.1.1;1.0.0.1'
```

Start Pi-hole:

```bash
cd /srv/pihole-docker
sudo -E docker compose up -d
```

## 5. Validate Pi-hole Container

```bash
sudo docker ps --filter name=pihole-proxmox
sudo docker logs --tail=50 pihole-proxmox
dig @127.0.0.1 pi.hole +short
```

## 6. Keepalived Health Check Integration

Keepalived can continue using the same health check script on the guest:

```bash
sudo cp scripts/check_pihole.sh /usr/local/bin/check_pihole.sh
sudo chmod +x /usr/local/bin/check_pihole.sh
sudo /usr/local/bin/check_pihole.sh && echo "Healthy"
```

For full VRRP configuration, use:

- `examples/keepalived-master.conf`
- `examples/keepalived-backup.conf`
- `docs/KEEPALIVED-HA.md`
