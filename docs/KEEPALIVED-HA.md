# Route: π² (Pi-squared)

Dual Pi-hole + Router HA using Keepalived/VRRP.

This guide describes a highly available Pi-hole setup using Keepalived (VRRP) to provide a virtual IP (VIP) that fails over automatically between two Pi-hole instances.

## 1. Overview

Goal:

- Two Pi‑hole servers (`pihole1` and `pihole2`) share a Virtual IP (VIP).
- Clients always point to the VIP for DNS/DHCP.
- If the master Pi‑hole goes down, the backup takes over automatically.

Example:

```plaintext
Pi‑hole 1: 10.20.20.11
Pi‑hole 2: 10.20.20.12
VIP:       10.20.20.10
```

---

## 2. Install Keepalived on Both Pi‑hole Nodes

```bash
sudo apt update
sudo apt install -y keepalived
```

---

## 3. Keepalived Config — Master Node (`pihole1`)

Edit `/etc/keepalived/keepalived.conf`:

```conf
vrrp_instance VI_1 {
	state MASTER
	interface eth0                # Change to your Pi-hole's LAN NIC
	virtual_router_id 51
	priority 150                   # Higher = preferred master
	advert_int 1
	authentication {
		auth_type PASS
		auth_pass piholeHApass
	}
	virtual_ipaddress {
		10.20.20.10/24 dev eth0
	}
	track_script {
		chk_pihole
	}
}

vrrp_script chk_pihole {
	script "/usr/local/bin/check_pihole.sh"
	interval 5
	weight -20
}
```

---

## 4. Keepalived Config — Backup Node (`pihole2`)

```conf
vrrp_instance VI_1 {
	state BACKUP
	interface eth0
	virtual_router_id 51
	priority 100                   # Lower than master
	advert_int 1
	authentication {
		auth_type PASS
		auth_pass piholeHApass
	}
	virtual_ipaddress {
		10.20.20.10/24 dev eth0
	}
	track_script {
		chk_pihole
	}
}

vrrp_script chk_pihole {
	script "/usr/local/bin/check_pihole.sh"
	interval 5
	weight -20
}
```

---

## 5. Health Check Script

Create `/usr/local/bin/check_pihole.sh` on both nodes. The script below has three optional checks (DNS, FTL process, Web UI). Adjust which checks run by enabling/disabling the blocks.

```bash
#!/bin/bash
# check_pihole.sh - keepalived health check for Pi-hole
# Exit codes: 0 = healthy, non-zero = fail

set -e

# 1) DNS check (local resolver)
dig @127.0.0.1 pi.hole +short >/dev/null 2>&1
DNS_OK=$?

# 2) FTL process check (recommended)
pgrep pihole-FTL >/dev/null 2>&1
FTL_OK=$?

# 3) Web UI check (local HTTP request)
curl -sS --connect-timeout 2 http://127.0.0.1/admin/ > /dev/null 2>&1
UI_OK=$?

# Combine checks - require DNS and at least one of FTL or UI
if [ $DNS_OK -eq 0 ] && { [ $FTL_OK -eq 0 ] || [ $UI_OK -eq 0 ]; }; then
	exit 0
else
	# Optional: log reason for debugging
	echo "Health check failed: DNS=$DNS_OK, FTL=$FTL_OK, UI=$UI_OK" >&2
	exit 1
fi
```

Make it executable:

```bash
sudo chmod +x /usr/local/bin/check_pihole.sh
```

Tip: keepalived will run the script as root. Avoid long-running checks (keep interval ~5s) and prefer fast probes.

---

## 6. Enable and Start Keepalived

```bash
sudo systemctl enable keepalived
sudo systemctl start keepalived
```

---

## 7. DHCP/DNS Settings

- In Pi‑hole admin UI on both nodes, set:
  - Interface listening behavior: Listen on all interfaces
  - Permit all origins (if needed for VLANs)
- Configure DHCP (if Pi‑hole is DHCP server) identically on both nodes.
- Clients should use VIP (10.20.20.10) as their DNS server.

---

## 8. Testing Failover

1. Ping the VIP from a client — should respond from master.
2. Stop keepalived on master:

```bash
sudo systemctl stop keepalived
```

3. VIP should move to backup within ~2 seconds.
4. Restart master keepalived — VIP should return.

---

## 9. Notes

- Priority: Higher number wins when both are healthy.
- VRID: Must match on both nodes.
- Auth pass: Must match on both nodes.
- Health check: Can be expanded to check Pi‑hole web UI or FTL process.
- Proxmox tip: If running in LXC, enable `nesting` and `cap_net_admin` for the container.

### LXC / Proxmox Notes

- If deploying Pi-hole inside unprivileged LXC containers, set the container config on the Proxmox host:

```
# Enable nesting and allow network capabilities (run on Proxmox host)
pct set <CTID> -features nesting=1
# Grant cap_net_admin for VRRP and IP management
echo 'lxc.cap.drop =' >> /etc/pve/lxc/<CTID>.conf || true
# For unprivileged containers you may need to explicitly set capabilities. Example (Privileged):
pct set <CTID> -net0 name=eth0,bridge=vmbr0,ip=dhcp
pct set <CTID> -features nesting=1
```

- For LXC, you may prefer to run Pi-hole in a privileged container when using keepalived (trade-offs in security).

- If keepalived needs to manipulate routing or addresses on the host, consider running keepalived on the Proxmox host (or use a dedicated virtual machine) rather than in an unprivileged LXC.

### Test Checklist (Expanded)

1. Confirm both nodes have `keepalived` running:

```bash
systemctl status keepalived
```

2. Verify VIP present on master:

```bash
ip addr show dev eth0 | grep 10.20.20.10
```

3. Simulate Pi-hole failure: stop FTL or block DNS and confirm failover

```bash
sudo systemctl stop pihole-FTL
# wait ~5s and check VIP moved to backup
ip addr show dev eth0
```

4. Restore services and confirm VIP returns:

```bash
sudo systemctl start pihole-FTL
# wait and verify VIP returned to master
```

5. Check keepalived logs for transitions:

```bash
journalctl -u keepalived -f
```

---

## 10. Change Log

| Date       | Change                    | Notes                  |
|------------|---------------------------|------------------------|
| 2025-09-14 | Initial keepalived config | VRRP + Pi‑hole health  |
| 2025-09-14 | Added health check script | DNS query to localhost |
