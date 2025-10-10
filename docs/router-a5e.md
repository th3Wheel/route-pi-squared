# Radxa Cubie A5E Router Setup Guide for Route Pi²

## Overview

This guide provides step-by-step instructions for configuring the Radxa Cubie A5E as a router in the Route Pi² deployment. The router establishes VLAN 20 for network services and provides DHCP/DNS relay to both Pi-hole instances.

## Prerequisites

### Hardware Requirements
- Radxa Cubie A5E with dual NICs
- Debian/Armbian installed
- Internet connection for initial setup

### Software Requirements
```bash
# Required packages
apt update
apt install -y systemd-networkd isc-dhcp-server nftables net-tools dnsutils
```

### Network Requirements
- WAN uplink providing DHCP
- LAN switch supporting VLAN 802.1Q tagging
- VLAN 20 trunk configured on LAN switch port

## Configuration Steps

### Step 1: Network Interface Identification

Identify the network interfaces on your Radxa Cubie A5E:

```bash
ip addr show
```

Expected output should show two interfaces (typically `end0` and `end1`). Note which is which - `end0` will be connected to WAN, `end1` to LAN.

### Step 2: Create Network Configuration Files

Copy the configuration files from `a5e-router-config.md` to the appropriate locations:

```bash
# Create systemd-networkd configuration directory
mkdir -p /etc/systemd/network

# Copy network configuration files
cp /path/to/a5e-router-config.md /etc/systemd/network/01-end0-wan.network
cp /path/to/a5e-router-config.md /etc/systemd/network/02-end1-lan.network
cp /path/to/a5e-router-config.md /etc/systemd/network/03-vlan20.netdev
cp /path/to/a5e-router-config.md /etc/systemd/network/04-vlan20.network
```

**Note**: Extract the individual configuration sections from the markdown code blocks in `a5e-router-config.md`.

### Step 3: Configure Firewall

```bash
# Copy nftables configuration
cp /path/to/a5e-router-config.md /etc/nftables.conf

# Enable and start nftables
systemctl enable nftables
systemctl start nftables
```

### Step 4: Configure System Parameters

```bash
# Copy sysctl configuration
cp /path/to/a5e-router-config.md /etc/sysctl.d/99-router.conf

# Apply sysctl settings
sysctl -p /etc/sysctl.d/99-router.conf
```

### Step 5: Configure DHCP Server

```bash
# Copy DHCP configuration
cp /path/to/a5e-router-config.md /etc/dhcp/dhcpd.conf

# Configure DHCP server to listen on vlan20
echo 'INTERFACESv4="vlan20"' > /etc/default/isc-dhcp-server

# Enable and start DHCP server
systemctl enable isc-dhcp-server
systemctl start isc-dhcp-server
```

### Step 6: Enable Network Services

```bash
# Enable systemd-networkd
systemctl enable systemd-networkd

# Start network services
systemctl start systemd-networkd

# Reload network configuration
networkctl reload
```

### Step 7: Install Health Check Script

```bash
# Copy health check script
cp /path/to/a5e-router-config.md /usr/local/bin/router-health.sh

# Make executable
chmod +x /usr/local/bin/router-health.sh
```

## Validation

### Network Interface Validation

Check that interfaces are configured correctly:

```bash
# Check network status
networkctl status

# Check VLAN interface
ip addr show vlan20

# Expected output: vlan20 should have IP 10.10.20.1/24
```

### Connectivity Testing

Test WAN connectivity:

```bash
# Test internet connectivity
ping -c 3 8.8.8.8

# Test DNS resolution
nslookup google.com
```

### DHCP Server Testing

Connect a client device to the LAN and verify DHCP:

```bash
# Check DHCP leases
dhcp-lease-list

# Expected: Client should receive IP in 10.10.20.100-199 range
# DNS servers should be 10.10.20.10 and 10.10.20.11
```

### Firewall Validation

Test firewall rules:

```bash
# List current rules
nft list ruleset

# Test DNS access to Pi-hole
dig @10.10.20.10 google.com
dig @10.10.20.11 google.com
```

### Health Check

Run the comprehensive health check:

```bash
/usr/local/bin/router-health.sh
```

Expected output:
```
=== Route Pi² Router Health Check ===
Timestamp: [current date/time]
WAN connectivity: ✓ OK
VLAN 20 interface: ✓ OK
IP forwarding: ✓ OK
DHCP leases: [number] active
Pi-hole 10.10.20.10: ✓ OK
Pi-hole 10.10.20.11: ✓ OK
```

## VLAN 20 Setup Details

### Switch Configuration

Configure your LAN switch to trunk VLAN 20 to the port connected to the Radxa Cubie A5E:

**Cisco Switch Example:**
```cisco
interface GigabitEthernet0/1
 switchport mode trunk
 switchport trunk allowed vlan 20
 switchport trunk native vlan 1
```

**Ubiquiti UniFi Example:**
- Edit the port profile for the Radxa connection
- Set VLAN mode to "Trunk"
- Allow VLAN 20 (and optionally VLAN 1 for management)

### Network Segmentation

VLAN 20 isolates network services:
- **Gateway**: 10.10.20.1 (Radxa router)
- **Pi-hole Primary**: 10.10.20.10
- **Pi-hole Secondary**: 10.10.20.11
- **DHCP Range**: 10.10.20.100-199
- **Subnet**: 10.10.20.0/24

## Troubleshooting

### Common Issues

#### Interfaces Not Detected

**Symptoms:** `networkctl` shows interfaces as "off" or "failed"

**Solutions:**
```bash
# Check interface names
ip addr show

# If interfaces have different names, update .network files
# Example: change "end0" to "eth0" if needed

# Restart systemd-networkd
systemctl restart systemd-networkd
```

#### VLAN Interface Not Created

**Symptoms:** `ip addr show vlan20` shows no interface

**Solutions:**
```bash
# Load 802.1q kernel module
modprobe 8021q

# Make permanent
echo "8021q" >> /etc/modules

# Restart network
systemctl restart systemd-networkd
```

#### DHCP Not Working

**Symptoms:** Clients not receiving IP addresses

**Solutions:**
```bash
# Check DHCP server status
systemctl status isc-dhcp-server

# Check DHCP configuration
dhcpd -t -cf /etc/dhcp/dhcpd.conf

# Check logs
journalctl -u isc-dhcp-server -f
```

#### Firewall Blocking Traffic

**Symptoms:** Clients can't access internet or DNS

**Solutions:**
```bash
# Check firewall rules
nft list ruleset

# Temporarily disable firewall for testing
systemctl stop nftables

# Re-enable after testing
systemctl start nftables
```

#### DNS Resolution Issues

**Symptoms:** Clients can't resolve domain names

**Solutions:**
```bash
# Test direct Pi-hole access
dig @10.10.20.10 google.com

# Check Pi-hole status
curl -s http://10.10.20.10/admin/api.php?status | jq .status

# Verify DHCP DNS options
dhcp-lease-list | grep dns
```

### Diagnostic Commands

```bash
# Network interface status
networkctl status

# Routing table
ip route show

# Firewall rules
nft list ruleset

# DHCP leases
dhcp-lease-list

# System logs
journalctl -u systemd-networkd -f
journalctl -u isc-dhcp-server -f
journalctl -u nftables -f

# Network traffic monitoring
tcpdump -i vlan20 -n port 53  # DNS traffic
tcpdump -i end0 -n icmp       # WAN connectivity
```

## Monitoring

### Regular Health Checks

Set up a cron job for regular health monitoring:

```bash
# Add to crontab
crontab -e

# Add this line for hourly checks
0 * * * * /usr/local/bin/router-health.sh >> /var/log/router-health.log 2>&1
```

### Key Metrics to Monitor

- **Network Interfaces**: Status and traffic statistics
- **DHCP Leases**: Active leases and utilization
- **DNS Resolution**: Response times and success rates
- **Firewall**: Dropped packets and rule hits
- **System Resources**: CPU, memory, and disk usage

### Log Files

Monitor these log files for issues:

```bash
# System logs
/var/log/syslog
/var/log/kern.log

# Service logs
journalctl -u systemd-networkd
journalctl -u isc-dhcp-server
journalctl -u nftables

# Custom logs
/var/log/router-health.log
```

## Security Considerations

### Access Restrictions

- SSH access restricted to LAN only (VLAN 20)
- Router management interfaces not exposed to WAN
- Firewall drops all unauthorized inbound traffic

### Best Practices

- Regularly update system packages
- Monitor firewall logs for suspicious activity
- Use strong passwords for any management interfaces
- Keep backups of configuration files
- Test configuration changes in a lab environment first

## Backup and Recovery

### Configuration Backup

```bash
# Backup network configuration
tar -czf /root/network-config-backup.tar.gz /etc/systemd/network/ /etc/nftables.conf /etc/sysctl.d/99-router.conf /etc/dhcp/dhcpd.conf
```

### Full System Backup

```bash
# Create system image backup
dd if=/dev/mmcblk0 of=/path/to/backup.img bs=1M status=progress
```

### Recovery Procedure

1. Boot from backup image or reinstall OS
2. Restore configuration files from backup
3. Restart network services
4. Run health check validation

## Performance Tuning

### Network Optimization

```bash
# Increase network buffer sizes
echo "net.core.rmem_max=262144" >> /etc/sysctl.d/99-router.conf
echo "net.core.wmem_max=262144" >> /etc/sysctl.d/99-router.conf

# Apply changes
sysctl -p /etc/sysctl.d/99-router.conf
```

### DHCP Server Tuning

```bash
# Adjust DHCP lease times for better performance
# Edit /etc/dhcp/dhcpd.conf
default-lease-time 3600;    # 1 hour
max-lease-time 7200;        # 2 hours
```

## Support and Resources

### Documentation Links

- [systemd-networkd documentation](https://www.freedesktop.org/software/systemd/man/systemd.network.html)
- [ISC DHCP documentation](https://kb.isc.org/docs/isc-dhcp-44-manual-pages-dhcpdconf)
- [nftables documentation](https://wiki.nftables.org/)
- [Radxa Cubie A5E documentation](https://docs.radxa.com/en/cubie/a5e)

### Community Support

- [nMapping+ GitHub Issues](https://github.com/your-org/nmapping-plus/issues)
- [Route Pi² Discussion](https://github.com/your-org/route-pi-squared/discussions)

---

**Last Updated:** 2025-10-07
**Version:** 1.0
**Applies to:** Route Pi² Phase 2 - Router Infrastructure