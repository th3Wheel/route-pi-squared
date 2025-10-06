# Quick Reference Guide

Quick reference for common Route: π² operations and commands.

## Installation

```bash
# Clone repository
git clone https://github.com/th3Wheel/route-pi-squared.git
cd route-pi-squared

# Install on master node
sudo ./scripts/install.sh master

# Install on backup node
sudo ./scripts/install.sh backup

# Edit configuration
sudo nano /etc/keepalived/keepalived.conf

# Start service
sudo systemctl start keepalived
```

## Status & Monitoring

```bash
# Check keepalived status
sudo systemctl status keepalived

# View keepalived logs (live)
sudo journalctl -u keepalived -f

# View keepalived logs (last 50 lines)
sudo journalctl -u keepalived -n 50

# Check VIP presence
ip addr show | grep '10.20.20.10'

# Check Pi-hole FTL status
sudo systemctl status pihole-FTL

# Test health check script manually
sudo /usr/local/bin/check_pihole.sh && echo "Healthy" || echo "Unhealthy"
```

## Failover Testing

```bash
# Simulate master failure (on master)
sudo systemctl stop keepalived
# or
sudo systemctl stop pihole-FTL

# Restore master (on master)
sudo systemctl start keepalived
# or
sudo systemctl start pihole-FTL

# Force failover to backup
# On master, lower priority temporarily then restart
```

## Configuration Changes

```bash
# Edit keepalived config
sudo nano /etc/keepalived/keepalived.conf

# Test configuration syntax
sudo keepalived -t -f /etc/keepalived/keepalived.conf

# Reload configuration (apply changes)
sudo systemctl restart keepalived

# Edit health check script
sudo nano /usr/local/bin/check_pihole.sh
```

## Network Diagnostics

```bash
# Check network interfaces
ip addr show

# Test DNS resolution
dig @127.0.0.1 pi.hole +short
dig @10.20.20.10 google.com +short

# Test VIP accessibility (from client)
ping 10.20.20.10

# Check VRRP multicast traffic
sudo tcpdump -i eth0 -n proto 112

# Check which node has VIP
# On master
ip addr show dev eth0 | grep 10.20.20.10 && echo "VIP present" || echo "VIP absent"

# On backup
ip addr show dev eth0 | grep 10.20.20.10 && echo "VIP present" || echo "VIP absent"
```

## Troubleshooting

### VIP not appearing

```bash
# Check keepalived is running
sudo systemctl status keepalived

# Check logs for errors
sudo journalctl -u keepalived -n 100 --no-pager

# Verify interface name is correct
ip link show

# Check for firewall blocking VRRP (protocol 112)
sudo iptables -L -n -v | grep 112
```

### Split-brain (both nodes think they're master)

```bash
# Check VRRP traffic between nodes
sudo tcpdump -i eth0 proto 112 -n

# Verify virtual_router_id matches on both nodes
grep virtual_router_id /etc/keepalived/keepalived.conf

# Verify auth_pass matches on both nodes
grep auth_pass /etc/keepalived/keepalived.conf

# Check network connectivity between nodes
ping 10.20.20.11  # From backup to master
ping 10.20.20.12  # From master to backup
```

### Health checks failing

```bash
# Test health check manually with debug output
sudo bash -x /usr/local/bin/check_pihole.sh

# Check DNS resolution
dig @127.0.0.1 pi.hole +short

# Check FTL process
pgrep pihole-FTL

# Check web UI
curl -v http://127.0.0.1/admin/

# Check Pi-hole status
pihole status
```

## Performance & Optimization

```bash
# Monitor keepalived transitions
sudo journalctl -u keepalived | grep "Entering MASTER STATE"
sudo journalctl -u keepalived | grep "Entering BACKUP STATE"

# Check health check execution time
time sudo /usr/local/bin/check_pihole.sh

# Monitor system resources
htop
free -h
df -h
```

## Maintenance

```bash
# Graceful shutdown (move VIP to backup first)
# On master:
sudo systemctl stop keepalived
# Wait for VIP to move
sleep 5
# Now safe to reboot/update

# Update keepalived
sudo apt update
sudo apt upgrade keepalived

# Restart keepalived after config changes
sudo systemctl restart keepalived

# Backup configuration
sudo cp /etc/keepalived/keepalived.conf /etc/keepalived/keepalived.conf.backup

# Restore configuration
sudo cp /etc/keepalived/keepalived.conf.backup /etc/keepalived/keepalived.conf
sudo systemctl restart keepalived
```

## Common Configuration Values

| Setting | Master | Backup | Notes |
|---------|--------|--------|-------|
| state | MASTER | BACKUP | Initial state |
| priority | 150 | 100 | Higher wins |
| virtual_router_id | 51 | 51 | Must match |
| auth_pass | same | same | Must match |
| virtual_ipaddress | 10.20.20.10 | 10.20.20.10 | Must match |
| interface | eth0 | eth0 | May differ |

## For More Help

- 📖 Full documentation: [docs/KEEPALIVED-HA.md](docs/KEEPALIVED-HA.md)
- 🐛 Report issues: [GitHub Issues](https://github.com/th3Wheel/route-pi-squared/issues)
- 💬 Ask questions: [GitHub Discussions](https://github.com/th3Wheel/route-pi-squared/discussions)
