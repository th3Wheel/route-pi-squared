# Contributing to Route: π² (Pi-squared)

First off, thank you for considering contributing to Route: π²! It's people like you that make this project better for everyone.

## Code of Conduct

This project and everyone participating in it is governed by our commitment to creating a welcoming and inclusive environment. Please be respectful and constructive in all interactions.

## How Can I Contribute?

### Reporting Bugs

Before creating bug reports, please check existing issues to avoid duplicates. When you create a bug report, include as many details as possible:

- **Use a clear and descriptive title**
- **Describe the exact steps to reproduce the problem**
- **Provide specific examples** (configuration files, logs, etc.)
- **Describe the behavior you observed and what you expected**
- **Include environment details** (OS, Pi-hole version, keepalived version)
- **Add relevant logs** from `journalctl -u keepalived`

### Suggesting Enhancements

Enhancement suggestions are tracked as GitHub issues. When creating an enhancement suggestion:

- **Use a clear and descriptive title**
- **Provide a detailed description** of the proposed enhancement
- **Explain why this enhancement would be useful** to most users
- **List any alternatives you've considered**

### Pull Requests

1. **Fork the repository** and create your branch from `main`
2. **Make your changes** following the guidelines below
3. **Test your changes** thoroughly
4. **Update documentation** if you've changed functionality
5. **Ensure your code follows existing style**
6. **Write a clear commit message**

#### Commit Message Guidelines

Follow conventional commits format:

```
<type>(<scope>): <subject>

<body>

<footer>
```

**Types:**
- `feat:` New feature
- `fix:` Bug fix
- `docs:` Documentation changes
- `style:` Formatting, missing semicolons, etc.
- `refactor:` Code restructuring without changing behavior
- `test:` Adding tests
- `chore:` Maintenance tasks

**Examples:**
```
feat(health-check): add monitoring for DHCP service

docs(readme): update installation instructions

fix(config): correct VRRP priority calculation
```

## Development Setup

### Prerequisites

- Two Linux systems (VMs, containers, or bare metal)
- Pi-hole installed on both systems
- Git for version control

### Testing Changes

1. **Configuration Changes:**
   - Test on both master and backup nodes
   - Verify failover works correctly
   - Check logs for any errors

2. **Script Changes:**
   - Test with `bash -x` for debugging
   - Verify exit codes are correct
   - Test edge cases (service down, network issues)

3. **Documentation Changes:**
   - Ensure markdown is properly formatted
   - Verify all links work
   - Check that examples are accurate

### Documentation Standards

- Use clear, concise language
- Include code examples where helpful
- Keep formatting consistent with existing docs
- Add screenshots or diagrams when appropriate
- Update the changelog in `docs/KEEPALIVED-HA.md`

## Project Structure

```
route-pi-squared/
├── README.md              # Main project documentation
├── LICENSE                # MIT License
├── CONTRIBUTING.md        # This file
├── docs/                  # Detailed documentation
│   └── KEEPALIVED-HA.md  # HA setup guide
├── scripts/               # Helper scripts
│   └── check_pihole.sh   # Health check script
└── examples/              # Configuration examples
    ├── master.conf       # Master node config
    └── backup.conf       # Backup node config
```

## Style Guidelines

### Shell Scripts

- Use `#!/bin/bash` shebang
- Include comments for complex logic
- Use meaningful variable names
- Set `set -e` for error handling
- Exit with appropriate codes (0 = success, non-zero = failure)

### Configuration Files

- Include inline comments for clarity
- Use consistent indentation (tabs or spaces, not mixed)
- Group related settings together

### Documentation

- Use Markdown for all documentation
- Include code blocks with proper syntax highlighting
- Keep lines under 100 characters when possible
- Use headings to organize content

## Questions?

Don't hesitate to ask questions by:
- Opening an issue with the `question` label
- Starting a discussion in GitHub Discussions

## Recognition

Contributors will be recognized in:
- The project's contributor list
- Release notes for significant contributions

Thank you for contributing to Route: π²! 🎉
