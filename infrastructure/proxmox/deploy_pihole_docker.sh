#!/bin/bash
# deploy_pihole_docker.sh
#
# Purpose:
#   Prepare a Proxmox VM or privileged LXC container to run Pi-hole in Docker.
#   Installs Docker Engine, Docker Compose plugin, and copies the example
#   Compose manifest and .env template to /opt/pihole-docker on the target host.
#
# Usage (run on the Proxmox guest, not on the Proxmox host itself):
#   sudo ./deploy_pihole_docker.sh [options]
#
# Options:
#   --node-ip <ip>          Static IP of this node (required)
#   --webpassword <pass>    Pi-hole web UI password (required)
#   --tz <timezone>         Timezone (default: UTC)
#   --rev-server            Enable reverse DNS for the local LAN
#   --rev-cidr <cidr>       LAN CIDR for reverse DNS (default: 192.168.1.0/24)
#   --rev-target <ip>       Router IP for reverse DNS (default: 192.168.1.1)
#   --rev-domain <domain>   Local domain name (default: lan)
#   --dhcp                  Enable Pi-hole DHCP (default: disabled)
#   --data-dir <path>       Data directory for Pi-hole volumes (default: /srv/pihole)
#   --compose-dir <path>    Directory to deploy Compose files (default: /opt/pihole-docker)
#   -h, --help              Show this help message and exit
#
# Notes:
#   * Must be run as root inside the Proxmox guest (VM or LXC).
#   * For LXC containers: ensure nesting=1 and keyctl=1 are set in the container
#     features before running this script (see infrastructure/proxmox/pihole-lxc-template.sh).
#   * After deployment, start the stack with:
#       cd /opt/pihole-docker && docker compose -f docker-compose.pihole.proxmox.yaml up -d
#   * Configure Keepalived separately for HA failover (see examples/keepalived-*.conf).

set -euo pipefail

# ── Defaults ─────────────────────────────────────────────────────────────────
NODE_IP=""
WEBPASSWORD=""
TZ="UTC"
REV_SERVER="false"
REV_CIDR="192.168.1.0/24"
REV_TARGET="192.168.1.1"
REV_DOMAIN="lan"
DHCP_ACTIVE="false"
DATA_DIR="/srv/pihole"
COMPOSE_DIR="/opt/pihole-docker"

# ── Colours ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ── Helpers ───────────────────────────────────────────────────────────────────
info()    { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
die()     { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

usage() {
  sed -n '/^# Options:/,/^[^#]/p' "$0" | grep '^#' | sed 's/^# \{0,2\}//'
}

# ── Argument parsing ──────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --node-ip)       NODE_IP="${2:-}";       shift 2 ;;
    --webpassword)   WEBPASSWORD="${2:-}";   shift 2 ;;
    --tz)            TZ="${2:-}";            shift 2 ;;
    --rev-server)    REV_SERVER="true";      shift   ;;
    --rev-cidr)      REV_CIDR="${2:-}";      shift 2 ;;
    --rev-target)    REV_TARGET="${2:-}";    shift 2 ;;
    --rev-domain)    REV_DOMAIN="${2:-}";    shift 2 ;;
    --dhcp)          DHCP_ACTIVE="true";     shift   ;;
    --data-dir)      DATA_DIR="${2:-}";      shift 2 ;;
    --compose-dir)   COMPOSE_DIR="${2:-}";   shift 2 ;;
    -h|--help)       usage; exit 0 ;;
    *) die "Unknown option: $1" ;;
  esac
done

# ── Validation ────────────────────────────────────────────────────────────────
[[ $EUID -eq 0 ]]       || die "This script must be run as root."
[[ -n "$NODE_IP" ]]     || die "--node-ip is required."
[[ -n "$WEBPASSWORD" ]] || die "--webpassword is required."

# Validate that NODE_IP looks like an IPv4 address
if ! [[ "$NODE_IP" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]]; then
  die "--node-ip '${NODE_IP}' does not look like a valid IPv4 address."
fi

# ── Detect OS ─────────────────────────────────────────────────────────────────
if [[ ! -f /etc/os-release ]]; then
  die "Cannot detect OS: /etc/os-release not found."
fi
# shellcheck source=/dev/null
source /etc/os-release
OS_ID="${ID:-unknown}"
info "Detected OS: ${PRETTY_NAME:-$OS_ID}"

# ── Install Docker ────────────────────────────────────────────────────────────
if command -v docker &>/dev/null; then
  info "Docker is already installed: $(docker --version)"
else
  info "Installing Docker Engine..."
  case "$OS_ID" in
    debian|ubuntu)
      apt-get update -qq
      apt-get install -y --no-install-recommends \
        ca-certificates curl gnupg lsb-release

      install -m 0755 -d /etc/apt/keyrings
      curl -fsSL "https://download.docker.com/linux/${OS_ID}/gpg" \
        | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
      chmod a+r /etc/apt/keyrings/docker.gpg

      echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/${OS_ID} \
$(lsb_release -cs) stable" \
        > /etc/apt/sources.list.d/docker.list

      apt-get update -qq
      apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
      ;;
    *)
      die "Unsupported OS '${OS_ID}'. Install Docker manually, then re-run this script."
      ;;
  esac
  info "Docker installed: $(docker --version)"
fi

# Enable and start Docker service
systemctl enable --now docker
info "Docker service is running."

# ── Create data directories ───────────────────────────────────────────────────
info "Creating Pi-hole data directories under ${DATA_DIR}..."
mkdir -p \
  "${DATA_DIR}/etc-pihole" \
  "${DATA_DIR}/etc-dnsmasq.d" \
  "${DATA_DIR}/var-log"
mkdir -p /srv/unbound

# ── Deploy Compose files ──────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_SRC="${SCRIPT_DIR}/../../examples/docker/docker-compose.pihole.proxmox.yaml"

info "Deploying Compose files to ${COMPOSE_DIR}..."
mkdir -p "$COMPOSE_DIR"

if [[ -f "$COMPOSE_SRC" ]]; then
  cp "$COMPOSE_SRC" "${COMPOSE_DIR}/docker-compose.yaml"
  info "Copied docker-compose.yaml"
else
  warn "Compose template not found at ${COMPOSE_SRC}. Skipping copy."
  warn "Manually place docker-compose.pihole.proxmox.yaml in ${COMPOSE_DIR}/docker-compose.yaml"
fi

# ── Generate .env ─────────────────────────────────────────────────────────────
ENV_FILE="${COMPOSE_DIR}/.env"
if [[ -f "$ENV_FILE" ]]; then
  warn ".env already exists at ${ENV_FILE}. Skipping generation to avoid overwriting."
else
  info "Generating ${ENV_FILE}..."
  cat > "$ENV_FILE" <<EOF
# Generated by deploy_pihole_docker.sh — $(date -u '+%Y-%m-%dT%H:%M:%SZ')
# Edit as needed, then run: docker compose up -d

NODE_IP=${NODE_IP}
PIHOLE_HOSTNAME=pihole-$(hostname -s)
PIHOLE_WEBPASSWORD=${WEBPASSWORD}
TZ=${TZ}
PIHOLE_DNS=127.0.0.1#5335
REV_SERVER=${REV_SERVER}
REV_SERVER_DOMAIN=${REV_DOMAIN}
REV_SERVER_TARGET=${REV_TARGET}
REV_SERVER_CIDR=${REV_CIDR}
DHCP_ACTIVE=${DHCP_ACTIVE}
UNBOUND_HOSTNAME=unbound-$(hostname -s)
EOF
  chmod 600 "$ENV_FILE"
  info ".env written (permissions set to 600)."
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}===== Deployment ready =====${NC}"
echo ""
echo "  Compose directory : ${COMPOSE_DIR}"
echo "  Data directory    : ${DATA_DIR}"
echo "  Node IP           : ${NODE_IP}"
echo ""
echo "Next steps:"
echo "  1. Review/edit ${COMPOSE_DIR}/.env"
echo "  2. Start the stack:"
echo "       cd ${COMPOSE_DIR} && docker compose up -d"
echo "  3. Verify Pi-hole is running:"
echo "       docker compose logs -f pihole"
echo "  4. Install and configure Keepalived for HA failover:"
echo "       See examples/keepalived-master.conf and examples/keepalived-backup.conf"
echo ""
