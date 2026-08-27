#!/bin/bash
# deploy_pihole_lxc.sh
#
# Purpose:
#   Clone the Pi-hole LXC template (created by pihole-lxc-template.sh) into a
#   production container on Proxmox VE 9 and install Pi-hole natively inside it.
#   No Docker is required — Proxmox VE 9 hosts containers directly via LXC.
#
# Usage (run on the Proxmox VE host):
#   sudo ./deploy_pihole_lxc.sh \
#     --ctid 200 \
#     --template-ctid 9200 \
#     --hostname pihole-1 \
#     --ip 10.20.20.11/24 \
#     --gateway 10.20.20.1
#
# Options:
#   --ctid <id>              Numeric CT ID for the new production container (required)
#   --template-ctid <id>     CT ID of the existing template to clone from (required)
#   --hostname <name>        Container hostname (default: pihole-lxc)
#   --bridge <bridge>        Proxmox bridge to attach (default: vmbr1)
#   --ip <cidr>              IPv4 address in CIDR format (required)
#   --gateway <ip>           IPv4 gateway (required)
#   --vlan <tag>             VLAN tag (optional; omit if not using VLANs)
#   --rootfs-storage <id>    Storage ID for the cloned rootfs (default: local-lvm)
#   --cores <n>              CPU cores to assign (default: 2)
#   --memory <mb>            RAM in MiB (default: 512)
#   --swap <mb>              Swap in MiB (default: 0)
#   --webpassword <pass>     Pi-hole web UI password (required)
#   --tz <timezone>          Timezone string passed to Pi-hole (default: UTC)
#   --dns-upstream <ip>      Upstream DNS server for Pi-hole (default: 8.8.8.8)
#   -h, --help               Show this help message and exit
#
# Notes:
#   * Requires execution on a Proxmox VE 9 host with pct available.
#   * Run pihole-lxc-template.sh first to create the cloneable template.
#   * The new container is started, Pi-hole is installed, then the container
#     is left running. Keepalived should be configured separately for HA.
#   * See examples/keepalived-master.conf / keepalived-backup.conf for VRRP config.

set -euo pipefail

# ── Defaults ─────────────────────────────────────────────────────────────────
CTID=""
TEMPLATE_CTID=""
HOSTNAME="pihole-lxc"
BRIDGE="vmbr1"
IPV4_ADDRESS=""
GATEWAY=""
VLAN_TAG=""
ROOTFS_STORAGE="local-lvm"
CPU_CORES="2"
MEMORY_MB="512"
SWAP_MB="0"
WEBPASSWORD=""
TZ="UTC"
DNS_UPSTREAM="8.8.8.8"

# ── Colours ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ── Helpers ───────────────────────────────────────────────────────────────────
info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
die()   { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "Command '$1' not found. Is this a Proxmox VE host?"
}

usage() {
  sed -n '/^# Options:/,/^[^#]/p' "$0" | grep '^#' | sed 's/^# \{0,2\}//'
}

# ── Argument parsing ──────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --ctid)             CTID="${2:-}";            shift 2 ;;
    --template-ctid)    TEMPLATE_CTID="${2:-}";   shift 2 ;;
    --hostname)         HOSTNAME="${2:-}";         shift 2 ;;
    --bridge)           BRIDGE="${2:-}";           shift 2 ;;
    --ip)               IPV4_ADDRESS="${2:-}";     shift 2 ;;
    --gateway)          GATEWAY="${2:-}";          shift 2 ;;
    --vlan)             VLAN_TAG="${2:-}";         shift 2 ;;
    --rootfs-storage)   ROOTFS_STORAGE="${2:-}";   shift 2 ;;
    --cores)            CPU_CORES="${2:-}";         shift 2 ;;
    --memory)           MEMORY_MB="${2:-}";         shift 2 ;;
    --swap)             SWAP_MB="${2:-}";           shift 2 ;;
    --webpassword)      WEBPASSWORD="${2:-}";       shift 2 ;;
    --tz)               TZ="${2:-}";               shift 2 ;;
    --dns-upstream)     DNS_UPSTREAM="${2:-}";      shift 2 ;;
    -h|--help)          usage; exit 0 ;;
    *)                  die "Unknown option: $1" ;;
  esac
done

# ── Validation ────────────────────────────────────────────────────────────────
[[ $EUID -eq 0 ]]           || die "This script must be run as root on the Proxmox VE host."
[[ -n "$CTID" ]]            || die "--ctid is required."
[[ -n "$TEMPLATE_CTID" ]]   || die "--template-ctid is required."
[[ -n "$IPV4_ADDRESS" ]]    || die "--ip is required."
[[ -n "$GATEWAY" ]]         || die "--gateway is required."
[[ -n "$WEBPASSWORD" ]]     || die "--webpassword is required."

require_command pct

# Guard against cloning over an existing container
if pct status "$CTID" >/dev/null 2>&1; then
  die "CTID ${CTID} already exists. Choose a different ID or remove it first."
fi

# Verify the template exists and is marked as a template
TEMPLATE_STATUS="$(pct config "$TEMPLATE_CTID" 2>/dev/null | grep '^template:' | awk '{print $2}' || true)"
if [[ "$TEMPLATE_STATUS" != "1" ]]; then
  die "CTID ${TEMPLATE_CTID} is not a template. Run pihole-lxc-template.sh first."
fi

# ── Build net0 string ─────────────────────────────────────────────────────────
NET0="name=eth0,bridge=${BRIDGE},firewall=1,gw=${GATEWAY},ip=${IPV4_ADDRESS}"
[[ -n "$VLAN_TAG" ]] && NET0="${NET0},tag=${VLAN_TAG}"

# ── Clone the template ────────────────────────────────────────────────────────
info "Cloning template ${TEMPLATE_CTID} → CT ${CTID} (${HOSTNAME})..."
pct clone "$TEMPLATE_CTID" "$CTID" \
  --hostname "$HOSTNAME" \
  --storage "$ROOTFS_STORAGE" \
  --full

info "Applying network and resource configuration..."
pct set "$CTID" \
  --cores "$CPU_CORES" \
  --memory "$MEMORY_MB" \
  --swap "$SWAP_MB" \
  --net0 "$NET0" \
  --onboot 1

# ── Start the container ───────────────────────────────────────────────────────
info "Starting CT ${CTID}..."
pct start "$CTID"

# Give the container a moment to initialise networking
sleep 5

# ── Install Pi-hole inside the container ──────────────────────────────────────
info "Installing Pi-hole inside CT ${CTID}..."

# Set timezone
pct exec "$CTID" -- bash -c "ln -sf /usr/share/zoneinfo/${TZ} /etc/localtime && echo '${TZ}' > /etc/timezone"

# Ensure curl is available (template should already have it)
pct exec "$CTID" -- bash -c "command -v curl >/dev/null || apt-get install -y --no-install-recommends curl"

# Run the official Pi-hole installer non-interactively using setupVars.conf
info "Writing Pi-hole setup configuration..."
pct exec "$CTID" -- bash -c "
  mkdir -p /etc/pihole
  cat > /etc/pihole/setupVars.conf <<'SETUPVARS'
PIHOLE_INTERFACE=eth0
IPV4_ADDRESS=${IPV4_ADDRESS}
IPV6_ADDRESS=
QUERY_LOGGING=true
INSTALL_WEB_SERVER=true
INSTALL_WEB_INTERFACE=true
LIGHTTPD_ENABLED=true
CACHE_SIZE=10000
DNS_FQDN_REQUIRED=true
DNS_BOGUS_PRIV=true
DNSSEC=true
TEMPERATUREUNIT=C
WEBUIBOXEDLAYOUT=boxed
API_EXCLUDE_DOMAINS=
API_EXCLUDE_CLIENTS=
API_QUERY_LOG_SHOW=all
API_PRIVACY_MODE=false
DNSMASQ_LISTENING=local
PIHOLE_DNS_1=${DNS_UPSTREAM}
PIHOLE_DNS_2=
BLOCKING_ENABLED=true
WEBPASSWORD=PLACEHOLDER
SETUPVARS
"

# Install Pi-hole, then set the web password separately so it is not in setupVars.conf
pct exec "$CTID" -- bash -c "
  curl -sSL https://install.pi-hole.net | bash /dev/stdin --unattended
"

info "Setting Pi-hole web UI password..."
# Write the password to a temporary file inside the container so it is never
# visible in ps output and single quotes in the password cannot break the
# shell command string.
TMPPASS="$(pct exec "$CTID" -- mktemp)"
printf '%s' "${WEBPASSWORD}" | pct exec "$CTID" -- tee "${TMPPASS}" >/dev/null
pct exec "$CTID" -- bash -c "pihole -a -p \"\$(cat '${TMPPASS}')\" && rm -f '${TMPPASS}'"

# ── Verify Pi-hole is running ─────────────────────────────────────────────────
info "Verifying Pi-hole FTL service..."
if pct exec "$CTID" -- bash -c "systemctl is-active pihole-FTL" >/dev/null 2>&1; then
  info "pihole-FTL is running."
else
  warn "pihole-FTL does not appear to be active — check logs with: pct exec ${CTID} -- journalctl -u pihole-FTL"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
CT_IP="${IPV4_ADDRESS%%/*}"   # strip CIDR suffix for display
echo ""
echo -e "${GREEN}===== CT ${CTID} deployed =====${NC}"
echo ""
echo "  Hostname     : ${HOSTNAME}"
echo "  IP address   : ${CT_IP}"
echo "  Pi-hole UI   : http://${CT_IP}/admin"
echo ""
echo "Next steps:"
echo "  1. Repeat this script for the second node (different --ctid, --hostname, --ip)"
echo "  2. Install and configure Keepalived inside each container for HA failover:"
echo "       pct exec ${CTID} -- apt-get install -y keepalived"
echo "       See examples/keepalived-master.conf and examples/keepalived-backup.conf"
echo "  3. Copy the health-check script into each container:"
echo "       pct push ${CTID} scripts/check_pihole.sh /usr/local/bin/check_pihole.sh"
echo "       pct exec ${CTID} -- chmod +x /usr/local/bin/check_pihole.sh"
echo ""
