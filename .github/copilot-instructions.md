# GitHub Copilot Instructions for Route: π²

## Project Overview

Route: π² (Pi-squared) is a high-availability Pi-hole DNS/DHCP solution using Keepalived VRRP. This project provides automatic failover between two Pi-hole instances using a Virtual IP (VIP) address, ensuring zero downtime for DNS and DHCP services.

**Key Technologies:**
- Shell scripting (Bash)
- Keepalived configuration
- Pi-hole integration
- VRRP (Virtual Router Redundancy Protocol)
- Markdown documentation

## Project Structure

```
route-pi-squared/
├── README.md              # Main project documentation
├── LICENSE                # MIT License
├── CONTRIBUTING.md        # Contributing guidelines
├── CHANGELOG.md           # Version history
├── QUICKREF.md            # Quick reference guide
├── docs/                  # Detailed documentation
│   └── KEEPALIVED-HA.md  # HA setup guide
├── scripts/               # Helper scripts
│   ├── check_pihole.sh   # Health check script
│   ├── install.sh        # Installation script
│   └── README.md         # Scripts documentation
└── examples/              # Configuration examples
    ├── keepalived-master.conf  # Master node config
    ├── keepalived-backup.conf  # Backup node config
    └── README.md               # Examples documentation
```

## Coding Standards

### Shell Scripts

- **Always use** `#!/bin/bash` shebang
- **Set error handling** with `set -e` at the beginning
- **Use meaningful variable names** (e.g., `NODE_TYPE`, `DNS_OK`)
- **Include comments** for complex logic
- **Exit codes:**
  - `0` = success
  - Non-zero = failure (with appropriate error code)
- **Color codes for output** (when applicable):
  - `RED='\033[0;31m'` for errors
  - `GREEN='\033[0;32m'` for success
  - `YELLOW='\033[1;33m'` for warnings
  - `NC='\033[0m'` to reset

### Configuration Files

- **Include inline comments** for clarity
- **Use consistent indentation** (spaces preferred, no mixed tabs/spaces)
- **Group related settings** together
- **Document required vs optional parameters**

### Documentation

- **Use Markdown** for all documentation
- **Include code blocks** with proper syntax highlighting (```bash, ```plaintext, etc.)
- **Keep lines under 100 characters** when possible
- **Use clear headings** to organize content
- **Include examples** where helpful
- **Add links** to related documentation

## Commit Message Guidelines

Follow the conventional commits format:

```
<type>(<scope>): <subject>

<body>

<footer>
```

**Types:**
- `feat:` New feature
- `fix:` Bug fix
- `docs:` Documentation changes
- `style:` Formatting changes
- `refactor:` Code restructuring without changing behavior
- `test:` Adding tests
- `chore:` Maintenance tasks

**Scopes (examples):**
- `health-check` - Health check script changes
- `config` - Configuration file changes
- `install` - Installation script changes
- `readme` - README updates
- `docs` - Documentation updates

**Examples:**
```
feat(health-check): add monitoring for DHCP service

docs(readme): update installation instructions

fix(config): correct VRRP priority calculation

chore(scripts): update install script with better error handling
```

## Key Concepts

### VRRP & Keepalived
- **VRRP (Virtual Router Redundancy Protocol)** provides automatic failover
- **VIP (Virtual IP)** is the shared IP address clients use
- **Priority** determines which node is preferred (higher = master)
- **virtual_router_id** must match on both nodes
- **auth_pass** must be identical on both nodes

### Health Checking
The health check script monitors:
1. **DNS Resolution** - Queries local Pi-hole resolver
2. **FTL Process** - Ensures pihole-FTL is running
3. **Web UI** - Verifies admin interface is accessible

### Configuration Parameters
- Master: state=MASTER, priority=150
- Backup: state=BACKUP, priority=100
- Both must have matching: virtual_router_id, auth_pass, virtual_ipaddress

## Testing Guidelines

### Script Testing
```bash
# Test script manually
sudo /usr/local/bin/check_pihole.sh
echo $?  # Should print 0 if healthy

# Debug mode
sudo bash -x /usr/local/bin/check_pihole.sh
```

### Configuration Testing
```bash
# Validate keepalived config syntax
sudo keepalived -t -f /etc/keepalived/keepalived.conf

# Check logs
sudo journalctl -u keepalived -f
```

### Failover Testing
```bash
# Verify VIP presence
ip addr show dev eth0 | grep <VIP_ADDRESS>

# Simulate failure on master
sudo systemctl stop keepalived

# Verify VIP moved to backup (should happen within ~2 seconds)
```

## Common Patterns

### Health Check Script Pattern
```bash
#!/bin/bash
set -e

# Perform check
check_command >/dev/null 2>&1
CHECK_OK=$?

# Exit with appropriate code
if [ $CHECK_OK -eq 0 ]; then
    exit 0
else
    echo "Check failed: reason" >&2
    exit 1
fi
```

### Installation Script Pattern
```bash
#!/bin/bash
set -e

# Validate arguments
if [ "$EUID" -ne 0 ]; then
    echo "Error: This script must be run as root"
    exit 1
fi

# Install dependencies
apt update
apt install -y package-name

# Configure service
cp config.file /etc/service/
systemctl enable service
```

## Important Notes

- **Always test on both master and backup nodes** when changing configurations
- **Verify failover works** after any changes to health checks or configurations
- **Check logs** for errors: `journalctl -u keepalived -f`
- **Network interface names** vary (eth0, ens18, enp0s3) - make them configurable
- **LXC/Proxmox deployments** require special capabilities (nesting=1)
- **Firewall rules** must allow VRRP traffic (IP protocol 112)

## Documentation References

- **Main README**: Overview, quick start, troubleshooting
- **CONTRIBUTING.md**: Detailed contribution guidelines, style guide
- **QUICKREF.md**: Quick reference for common commands
- **docs/KEEPALIVED-HA.md**: Complete HA configuration guide
- **examples/README.md**: Configuration examples documentation
- **scripts/README.md**: Scripts documentation

## When Making Changes

1. **Read existing code** and documentation to understand patterns
2. **Follow existing style** and conventions
3. **Update documentation** if changing functionality
4. **Test thoroughly** on both master and backup configurations
5. **Check logs** to ensure no errors are introduced
6. **Validate syntax** before committing (especially for configs and scripts)
7. **Keep changes minimal** and focused
8. **Write clear commit messages** following conventional commits format

## Project Goals

- **Reliability**: Zero downtime DNS/DHCP services
- **Simplicity**: Easy to deploy and maintain
- **Clarity**: Well-documented and easy to understand
- **Flexibility**: Works on bare metal, VMs, and containers
- **Best practices**: Following industry standards and conventions
