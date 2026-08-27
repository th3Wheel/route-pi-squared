# Configuration Examples

This directory contains example configuration files for Route: π².

## Proxmox VE 9 — native LXC deployment (recommended)

Proxmox VE 9 supports hosting containers directly via LXC — no Docker required on the
Proxmox host. Use the scripts in `infrastructure/proxmox/` to provision Pi-hole natively:

```bash
# 1. On the Proxmox VE host — create a reusable LXC template
sudo infrastructure/proxmox/pihole-lxc-template.sh \
  --ctid 9200 \
  --hostname pihole-template \
  --bridge vmbr1 \
  --ip 10.20.20.250/24 \
  --gateway 10.20.20.1

# 2. Clone the template and install Pi-hole for the first node
sudo infrastructure/proxmox/deploy_pihole_lxc.sh \
  --ctid 200 \
  --template-ctid 9200 \
  --hostname pihole-1 \
  --ip 10.20.20.11/24 \
  --gateway 10.20.20.1 \
  --webpassword <your-password>

# 3. Repeat for the second node (different --ctid, --hostname, --ip)
```

Then configure Keepalived inside each container using the examples below.

---

## docker/docker-compose.pihole.proxmox.yaml

Docker Compose manifest for running Pi-hole + Unbound in Docker on a **Proxmox VM guest**
(not on the Proxmox host itself). Uses `network_mode: host` so Pi-hole binds directly to
the VM's static IP, which is required for Keepalived VRRP to move the VIP between nodes
without port-mapping conflicts.

> **Note:** For bare-metal Proxmox deployments, prefer the native LXC approach above.
> This Docker Compose file is intended for VM guests where Docker is already in use.

**Prerequisites:**
- Docker Engine and the Docker Compose plugin installed on the VM guest
- Static IP assigned to the VM guest (not using DHCP)

**Quick start:**
```bash
# 1. Copy the .env example and fill in your values
cp examples/docker/.env.proxmox.example /opt/pihole-docker/.env
# Note: .env is excluded by .gitignore — never commit it

# 2. Edit /opt/pihole-docker/.env — set NODE_IP and PIHOLE_WEBPASSWORD at minimum

# 3. Start the stack
cd /opt/pihole-docker
docker compose -f docker-compose.yaml up -d
```

## docker/.env.proxmox.example

Annotated template for environment variables used by `docker-compose.pihole.proxmox.yaml`.
Copy to `.env` (in the same directory as the Compose file) and fill in your values.
The `.env` file is excluded by `.gitignore` to prevent secrets from being committed.

## docker/docker-compose.pihole.yaml

Docker Compose manifest for Pi-hole + Unbound on a Radxa Zero 3E (uses macvlan networking
on VLAN 20). See comments inside the file for network configuration details.

## keepalived-master.conf

Example Keepalived configuration for the master (primary) node.

**Installation:**
```bash
sudo cp keepalived-master.conf /etc/keepalived/keepalived.conf
```

**Important:** Edit the following values before use:
- `interface eth0` - Change to **YOUR_NETWORK_INTERFACE** (e.g., eth0, ens18)
- `auth_pass YOUR_SECRET_PASSWORD_HERE` - Change to **YOUR_SECURE_PASSWORD**
- `10.20.20.10/24` - Change to **YOUR_VIRTUAL_IP** (e.g., 192.168.1.10/24)

## keepalived-backup.conf

Example Keepalived configuration for the backup (secondary) node.

**Installation:**
```bash
sudo cp keepalived-backup.conf /etc/keepalived/keepalived.conf
```

**Important:** Edit the following values before use:
- `interface eth0` - Change to **YOUR_NETWORK_INTERFACE** (must match master if using same interface)
- `auth_pass YOUR_SECRET_PASSWORD_HERE` - **Must match YOUR_SECURE_PASSWORD from master**
- `10.20.20.10/24` - **Must match YOUR_VIRTUAL_IP from master**

## Configuration Notes

### Key Differences Between Master and Backup

| Parameter | Master | Backup | Notes |
|-----------|--------|--------|-------|
| `state` | MASTER | BACKUP | Initial state only |
| `priority` | 150 | 100 | Higher value = preferred master |
| `virtual_router_id` | 51 | 51 | **Must be identical** |
| `auth_pass` | Same | Same | **Must be identical** |
| `virtual_ipaddress` | Same | Same | **Must be identical** |

### Network Interface

Find your network interface name:
```bash
ip addr show
# or
ip link show
```

Common interface names:
- `eth0` - Ethernet
- `ens18` - Modern naming scheme
- `enp0s3` - VirtualBox/Proxmox
- `wlan0` - Wireless (not recommended for HA)

### Testing Configuration

Before starting Keepalived, verify syntax:
```bash
sudo keepalived -t -f /etc/keepalived/keepalived.conf
```

Check for errors:
```bash
sudo journalctl -u keepalived -f
```

## Complete Setup Sequence

1. Install Keepalived on both nodes
2. Copy health check script to both nodes
3. Deploy master config to primary node
4. Deploy backup config to secondary node
5. Enable and start Keepalived on both nodes
6. Verify VIP appears on master node

See the [main documentation](../docs/KEEPALIVED-HA.md) for detailed instructions.
