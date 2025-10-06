# Route: π² (Pi-squared)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

> **High-Availability Pi-hole DNS/DHCP with Keepalived VRRP**

A robust, production-ready solution for running dual Pi-hole servers in a high-availability configuration using Keepalived (VRRP). Provides automatic failover for DNS and DHCP services with zero downtime.

## 🎯 Overview

Route: π² creates a highly available Pi-hole setup where two Pi-hole instances share a Virtual IP (VIP) address. Clients always use the VIP for DNS/DHCP, and if the primary server fails, the secondary automatically takes over within seconds.

**Key Features:**
- 🔄 Automatic failover between Pi-hole instances
- 🚀 Sub-second failover time (~2 seconds)
- 🏥 Comprehensive health checking (DNS, FTL process, Web UI)
- 🎯 Single VIP for all clients (no DNS changes needed)
- 🔧 Easy configuration and deployment
- 📊 Built-in monitoring and logging

## 📐 Architecture

```plaintext
┌─────────────────────────────────────────────────┐
│                  Network Clients                 │
│         (DNS/DHCP requests to VIP)              │
└────────────────┬────────────────────────────────┘
                 │
                 ▼
         Virtual IP: 10.20.20.10
                 │
        ┌────────┴────────┐
        │                 │
   ┌────▼─────┐     ┌────▼─────┐
   │ Pi-hole 1 │     │ Pi-hole 2 │
   │  (MASTER) │     │  (BACKUP) │
   │ 10.20.20.11│     │ 10.20.20.12│
   └───────────┘     └───────────┘
   Keepalived        Keepalived
      VRRP             VRRP
```

## 🚀 Quick Start

### Prerequisites

- Two Pi-hole servers (bare metal, VM, or LXC containers)
- Both servers on the same network subnet
- Root or sudo access on both servers
- Network interface that supports VRRP (most do)

### Installation

1. **Install Keepalived on both nodes:**

```bash
sudo apt update
sudo apt install -y keepalived
```

2. **Configure the master node** (pihole1):

See [Keepalived HA Configuration Guide](docs/KEEPALIVED-HA.md#3-keepalived-config--master-node-pihole1)

3. **Configure the backup node** (pihole2):

See [Keepalived HA Configuration Guide](docs/KEEPALIVED-HA.md#4-keepalived-config--backup-node-pihole2)

4. **Deploy the health check script:**

See [Health Check Script](docs/KEEPALIVED-HA.md#5-health-check-script)

5. **Enable and start Keepalived:**

```bash
sudo systemctl enable keepalived
sudo systemctl start keepalived
```

6. **Verify the setup:**

```bash
# On master, confirm VIP is present
ip addr show dev eth0 | grep 10.20.20.10

# Test failover
sudo systemctl stop keepalived  # on master
# VIP should move to backup within ~2 seconds
```

## 📚 Documentation

- **[Keepalived HA Configuration Guide](docs/KEEPALIVED-HA.md)** - Complete setup instructions
  - Installation steps
  - Configuration examples
  - Health check scripts
  - Testing procedures
  - Troubleshooting
- **[Quick Reference Guide](QUICKREF.md)** - Common commands and operations at a glance
- **[Contributing Guidelines](CONTRIBUTING.md)** - How to contribute to the project
- **[Changelog](CHANGELOG.md)** - Project version history

## ⚙️ Configuration

### Example Network Setup

```plaintext
Pi-hole 1 (Master):  10.20.20.11
Pi-hole 2 (Backup):  10.20.20.12
Virtual IP (VIP):    10.20.20.10/24
Interface:           eth0
```

### Key Configuration Parameters

| Parameter | Master | Backup | Notes |
|-----------|--------|--------|-------|
| `state` | MASTER | BACKUP | Initial state |
| `priority` | 150 | 100 | Higher = preferred master |
| `virtual_router_id` | 51 | 51 | Must match on both |
| `auth_pass` | Same | Same | Must match on both |

## 🔍 Health Checking

The health check script monitors:
1. **DNS Resolution** - Queries local Pi-hole resolver
2. **FTL Process** - Ensures pihole-FTL is running
3. **Web UI** - Verifies admin interface is accessible

Failover occurs when any critical check fails for the configured interval.

## 🧪 Testing

```bash
# Test 1: Verify VIP presence
ip addr show dev eth0 | grep 10.20.20.10

# Test 2: Simulate failure
sudo systemctl stop pihole-FTL

# Test 3: Check failover
journalctl -u keepalived -f

# Test 4: Restore service
sudo systemctl start pihole-FTL
```

## 🐳 Deployment Options

### Bare Metal / Virtual Machines
Standard installation works out of the box.

### Proxmox LXC Containers

For LXC containers, enable required capabilities:

```bash
# On Proxmox host
pct set <CTID> -features nesting=1

# Grant network capabilities
echo 'lxc.cap.drop =' >> /etc/pve/lxc/<CTID>.conf
```

See [LXC/Proxmox Notes](docs/KEEPALIVED-HA.md#lxc--proxmox-notes) for details.

## 🛠️ Troubleshooting

### VIP not appearing
- Check `systemctl status keepalived`
- Verify network interface name matches config
- Ensure VRRP is not blocked by firewall

### Failover not working
- Verify health check script is executable
- Check script path in keepalived config
- Review logs: `journalctl -u keepalived -f`

### Split-brain (both nodes think they're master)
- Verify `virtual_router_id` matches on both nodes
- Check `auth_pass` is identical
- Ensure network connectivity between nodes

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [Pi-hole](https://pi-hole.net/) - Network-wide ad blocking
- [Keepalived](https://www.keepalived.org/) - Load balancing and high-availability framework
- VRRP Protocol (RFC 5798) - Virtual Router Redundancy Protocol

## 📧 Support

- 📖 Documentation: See [docs/](docs/)
- 🐛 Issues: [GitHub Issues](https://github.com/th3Wheel/route-pi-squared/issues)
- 💬 Discussions: [GitHub Discussions](https://github.com/th3Wheel/route-pi-squared/discussions)

## 📊 Project Status

This project is actively maintained. See the [changelog](docs/KEEPALIVED-HA.md#10-change-log) for recent updates.

---

**Made with ❤️ for reliable network infrastructure**
