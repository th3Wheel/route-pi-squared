#!/bin/bash
# install.sh - Quick installation script for Route π²
# Usage: sudo ./install.sh [master|backup]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Error: This script must be run as root (use sudo)${NC}"
    exit 1
fi

# Check argument
if [ "$#" -ne 1 ] || { [ "$1" != "master" ] && [ "$1" != "backup" ]; }; then
    echo -e "${RED}Usage: $0 [master|backup]${NC}"
    echo "  master - Install as master (primary) node"
    echo "  backup - Install as backup (secondary) node"
    exit 1
fi

NODE_TYPE=$1

echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   Route π² - Installation Script          ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Installing ${NODE_TYPE} node...${NC}"
echo ""

# Install keepalived
echo -e "${YELLOW}[1/4] Installing keepalived...${NC}"
apt update
apt install -y keepalived dnsutils curl

# Copy health check script
echo -e "${YELLOW}[2/4] Installing health check script...${NC}"
cp scripts/check_pihole.sh /usr/local/bin/
chmod +x /usr/local/bin/check_pihole.sh

# Copy configuration
echo -e "${YELLOW}[3/4] Installing keepalived configuration...${NC}"
if [ "$NODE_TYPE" == "master" ]; then
    cp examples/keepalived-master.conf /etc/keepalived/keepalived.conf
else
    cp examples/keepalived-backup.conf /etc/keepalived/keepalived.conf
fi

echo -e "${YELLOW}[4/4] Enabling keepalived service...${NC}"
systemctl enable keepalived

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   Installation Complete!                   ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Edit /etc/keepalived/keepalived.conf"
echo "   - Change interface name (default: eth0)"
echo "   - Change VIP address (default: 10.20.20.10)"
echo "   - Change auth_pass to a secure password"
echo ""
echo "2. Start keepalived:"
echo "   systemctl start keepalived"
echo ""
echo "3. Check status:"
echo "   systemctl status keepalived"
echo "   journalctl -u keepalived -f"
echo ""
echo "4. Verify VIP (on master):"
echo "   ip addr show | grep '10.20.20.10'"
echo ""
echo -e "${GREEN}For more information, see: docs/KEEPALIVED-HA.md${NC}"
