# Radxa Cubie A5E Router Configuration for Route Pi²

This document defines the complete router configuration for the Radxa Cubie A5E dual-NIC device in the Route Pi² deployment. The configuration establishes VLAN 20 routing with DHCP and DNS relay to both Pi-hole instances.

## Network Topology

```
Internet -- [end0: WAN/DHCP] Radxa Cubie A5E [end1: LAN/VLAN 20] -- LAN Clients
                                      |
                                      |-- VLAN 20 (10.10.20.0/24)
                                      |-- Gateway: 10.10.20.1
                                      |-- Pi-hole Primary: 10.10.20.10
                                      |-- Pi-hole Secondary: 10.10.20.11
                                      |-- DHCP Range: 10.10.20.100-199
```

## systemd-networkd Configuration

### 01-end0-wan.network (WAN Interface)

```ini
[Match]
Name=end0

[Network]
DHCP=yes
DNS=1.1.1.1 8.8.8.8
DNSSEC=no

[DHCP]
UseDNS=yes
UseNTP=yes
UseMTU=yes
```

### 02-end1-lan.network (LAN Interface Base)

```ini
[Match]
Name=end1

[Network]
VLAN=vlan20
```

### 03-vlan20.netdev (VLAN 20 Definition)

```ini
[NetDev]
Name=vlan20
Kind=vlan

[VLAN]
Id=20
```

### 04-vlan20.network (VLAN 20 Network)

```ini
[Match]
Name=vlan20

[Network]
Address=10.10.20.1/24
DHCPServer=yes
IPForward=yes
IPMasquerade=yes

[DHCPServer]
PoolOffset=100
PoolSize=100
EmitDNS=yes
DNS=10.10.20.10 10.10.20.11
EmitNTP=yes
NTP=10.10.20.1
```

## Firewall Configuration (nftables)

### /etc/nftables.conf

```nftables
flush ruleset

table inet filter {
    chain input {
        type filter hook input priority 0; policy drop;

        # Allow loopback
        iif lo accept

        # Allow established and related
        ct state established,related accept

        # Allow ICMP
        icmp type echo-request accept

        # Allow SSH from LAN
        iif vlan20 tcp dport 22 accept

        # Allow DHCP from LAN
        iif vlan20 udp dport 67 accept
        iif vlan20 udp dport 68 accept

        # Allow DNS queries to Pi-hole instances
        iif vlan20 ip daddr { 10.10.20.10, 10.10.20.11 } udp dport 53 accept
        iif vlan20 ip daddr { 10.10.20.10, 10.10.20.11 } tcp dport 53 accept

        # Allow HTTP to Pi-hole web interfaces (optional, for management)
        iif vlan20 ip daddr { 10.10.20.10, 10.10.20.11 } tcp dport 80 accept

        # Drop everything else
        drop
    }

    chain forward {
        type filter hook forward priority 0; policy drop;

        # Allow LAN to WAN forwarding
        iif vlan20 oif end0 accept

        # Allow established and related
        ct state established,related accept

        # Drop everything else
        drop
    }

    chain output {
        type filter hook output priority 0; policy accept;
    }
}

table ip nat {
    chain prerouting {
        type nat hook prerouting priority 0; policy accept;
    }

    chain postrouting {
        type nat hook postrouting priority 0; policy accept;

        # NAT LAN traffic to WAN
        oif end0 masquerade
    }
}
```

## System Configuration

### /etc/sysctl.d/99-router.conf

```bash
net.ipv4.ip_forward=1
net.ipv6.conf.all.forwarding=1
```

## DHCP Server Configuration

### /etc/dhcp/dhcpd.conf

```dhcp
option domain-name "lan";
option domain-name-servers 10.10.20.10, 10.10.20.11;

default-lease-time 600;
max-lease-time 7200;

ddns-update-style none;

subnet 10.10.20.0 netmask 255.255.255.0 {
    range 10.10.20.100 10.10.20.199;
    option routers 10.10.20.1;
    option domain-name-servers 10.10.20.10, 10.10.20.11;
    option ntp-servers 10.10.20.1;
}
```

## Monitoring and Health Checks

### /usr/local/bin/router-health.sh

```bash
#!/bin/bash
# Router health check script for Route Pi²

echo "=== Route Pi² Router Health Check ==="
echo "Timestamp: $(date)"

# Check WAN connectivity
echo -n "WAN connectivity: "
ping -c 1 -W 2 8.8.8.8 > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "✓ OK"
else
    echo "✗ FAIL"
fi

# Check VLAN 20 interface
echo -n "VLAN 20 interface: "
ip link show vlan20 > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "✓ OK"
else
    echo "✗ FAIL"
fi

# Check IP forwarding
echo -n "IP forwarding: "
if [ "$(cat /proc/sys/net/ipv4/ip_forward)" = "1" ]; then
    echo "✓ OK"
else
    echo "✗ FAIL"
fi

# Check DHCP leases
echo -n "DHCP leases: "
leases=$(dhcp-lease-list 2>/dev/null | wc -l)
echo "$leases active"

# Check Pi-hole connectivity
for pihole in 10.10.20.10 10.10.20.11; do
    echo -n "Pi-hole $pihole: "
    nc -z -w 2 $pihole 53 > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "✓ OK"
    else
        echo "✗ FAIL"
    fi
done

# Check network statistics
echo ""
echo "=== Network Statistics ==="
echo "VLAN 20 traffic:"
ip -s link show vlan20 | grep -A 2 "RX\|TX"

echo ""
echo "DHCP leases:"
dhcp-lease-list 2>/dev/null || echo "dhcp-lease-list not available"
```

## Deployment Instructions

### Prerequisites

1. **Hardware**: Radxa Cubie A5E with Debian/Armbian installed
2. **Network**: Dual NICs identified as `end0` (WAN) and `end1` (LAN)
3. **Packages**: Install required software

```bash
apt update
apt install -y systemd-networkd isc-dhcp-server nftables net-tools dnsutils
```

### Configuration Steps

1. **Create network configuration files**:

```bash
# Copy the systemd-networkd files above to /etc/systemd/network/
cp 01-end0-wan.network /etc/systemd/network/
cp 02-end1-lan.network /etc/systemd/network/
cp 03-vlan20.netdev /etc/systemd/network/
cp 04-vlan20.network /etc/systemd/network/
```

2. **Configure firewall**:

```bash
cp nftables.conf /etc/nftables.conf
systemctl enable nftables
systemctl start nftables
```

3. **Configure system parameters**:

```bash
cp 99-router.conf /etc/sysctl.d/
sysctl -p /etc/sysctl.d/99-router.conf
```

4. **Configure DHCP server**:

```bash
cp dhcpd.conf /etc/dhcp/
# Edit /etc/default/isc-dhcp-server to set INTERFACESv4="vlan20"
systemctl enable isc-dhcp-server
systemctl start isc-dhcp-server
```

5. **Enable and start network services**:

```bash
systemctl enable systemd-networkd
systemctl start systemd-networkd
networkctl reload
```

6. **Install health check script**:

```bash
cp router-health.sh /usr/local/bin/
chmod +x /usr/local/bin/router-health.sh
```

### Validation

Run the health check script:

```bash
/usr/local/bin/router-health.sh
```

Expected output should show all components as "OK".

### Troubleshooting

- **NIC naming**: If interfaces are not `end0`/`end1`, update the `[Match]` sections
- **VLAN module**: Ensure `8021q` kernel module is loaded: `modprobe 8021q`
- **DHCP conflicts**: Check for other DHCP servers on the network
- **Firewall issues**: Use `nft list ruleset` to verify rules are loaded

## Security Considerations

- SSH access restricted to LAN only
- DNS queries allowed only to designated Pi-hole instances
- All other inbound traffic dropped by default
- IP forwarding enabled for NAT functionality
- Regular firewall rule audits recommended