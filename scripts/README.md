# Scripts

This directory contains helper scripts for the Route: π² project.

## install.sh

Automated installation script for deploying Route: π² on a node.

**Usage:**
```bash
# For master node
sudo ./install.sh master

# For backup node
sudo ./install.sh backup
```

**What it does:**
1. Installs keepalived and required dependencies
2. Copies health check script to `/usr/local/bin/`
3. Deploys appropriate keepalived configuration
4. Enables keepalived service

**After installation:**
You must edit `/etc/keepalived/keepalived.conf` to customize:
- Network interface name
- Virtual IP address
- Authentication password

---

## check_pihole.sh

Health check script for Keepalived VRRP.

**Purpose:** Monitors Pi-hole health and determines if the node should serve as active master.

**Installation:**
```bash
sudo cp check_pihole.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/check_pihole.sh
```

**Checks Performed:**
1. **DNS Resolution** - Queries `pi.hole` via local resolver
2. **FTL Process** - Verifies `pihole-FTL` is running
3. **Web UI** - HTTP request to admin interface

**Exit Codes:**
- `0` - All checks passed (healthy)
- `1` - One or more checks failed (unhealthy)

**Testing:**
```bash
# Test the script manually
sudo /usr/local/bin/check_pihole.sh
echo $?  # Should print 0 if healthy

# Test with debug output
sudo bash -x /usr/local/bin/check_pihole.sh
```

**Customization:**
Edit the script to adjust which checks are performed or to add additional health checks (e.g., checking specific DNS records, monitoring query response times).

**Keepalived Integration:**
This script is called by Keepalived every 5 seconds (configurable). If the script returns a non-zero exit code, Keepalived reduces the node's priority by the configured weight (-20 by default), potentially triggering a failover.
