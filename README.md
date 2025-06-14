# LAMP Development Environment Setup

This repository contains scripts and configurations for setting up a complete LAMP (Linux, Apache, MySQL, PHP) development environment.

## Features

- Automated environment setup with modular scripts
- Configurable installation process
- Support for multiple projects and repositories
- Apache virtual hosts configuration
- Node.js ecosystem configuration

## Prerequisites

- Linux-based operating system
- Root/sudo access
- GitHub account with personal access token

## Quick Start

1. Clone this repository:
   ```bash
   git clone <repository-url>
   cd LAMP-env
   ```

2. Run the setup script with your GitHub token:
   ```bash
   sudo ./entry.sh your_github_token
   ```

## Configuration

### Script Options

The setup script supports the following options:

- `--exclude`: Skip specific setup scripts (comma-separated)
- `--only`: Run only specific setup scripts (comma-separated)

Example:
```bash
sudo ./entry.sh your_github_token --exclude docker,node
```

### Project Configuration

- Edit `configs/repos.json` to configure your project repositories
- Modify `configs/vhosts/` for Apache virtual host configurations
- Update `configs/ecosystem.config.js` for Node.js application settings

## Directory Structure

```
.
├── configs/                        # Configuration files
│   ├── vhosts/                     # Apache virtual host configurations
│   ├── ecosystem.config.js
│   └── repos.json
├── scripts/                        # Setup scripts
│   └── env/                        # Environment setup scripts
│       ├── 01-dependencies.sh
│       ├── 02-environment.sh
│       ├── 03-setup-projects.sh
│       └── helpers.sh
└── entry.sh                        # Main entry point script
```

## Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a new Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.