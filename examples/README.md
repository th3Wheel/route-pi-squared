# Configuration Examples

This directory contains example configuration files for Route: π².

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
