# Development Environment Setup

This repository contains scripts and configurations for setting up a complete development environment for web applications.

## Quick Start

1. Clone this repository:
   ```bash
   git clone <repository-url>
   cd <repository-name>
   ```

2. Run the setup scripts in order:
   ```bash
   ./scripts/01-dependencies.sh
   ./scripts/02-environment.sh
   ./scripts/03-setup-projects.sh
   ```

## Prerequisites

- Ubuntu/Debian-based system
- Git
- Sudo privileges
- Internet connection

## Directory Structure

```
.
├── configs/               # Configuration files
│   └── vhosts/           # Apache virtual host configurations
├── scripts/              # Setup scripts
│   ├── 01-dependencies.sh # Dependencies installation
│   ├── 02-environment.sh  # Environment configuration
│   └── 03-setup-projects.sh # Project setup
└── env/                  # Environment helpers
    └── helpers/          # Helper scripts
```

## Scripts Overview

### 01-dependencies.sh
Installs core development dependencies (PHP, Node.js, Composer, etc.)

### 02-environment.sh
Configures web server, database, and caching services

### 03-setup-projects.sh
Sets up development projects and process management

## Configuration

See the [configs/README.md](configs/README.md) for detailed configuration instructions.

## Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.
