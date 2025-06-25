#!/usr/bin/env bash

#==============================================================================
# System Dependencies Installation
#==============================================================================
# Installs and configures core system dependencies for LAMP development:
# - System utilities (ACL, cURL, JQ, etc.)
# - Web server (Apache2)
# - Database (MariaDB)
# - Cache (Redis)
# - PHP with extensions
# - Node.js and PM2
# - Composer
#==============================================================================

set -euo pipefail
IFS=$'\n\t'

# Load shared helpers
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/helpers/include.sh"

#------------------------------------------------------------------------------
# System Update
#------------------------------------------------------------------------------
# Update and upgrade system packages to ensure latest security and features
log_info "Updating system packages"
sudo apt-get update -y && sudo apt-get upgrade -y

#------------------------------------------------------------------------------
# Dependency Installation
#------------------------------------------------------------------------------
dependencies=(
    acl                             # Advanced file permissions
    ufw                             # Firewall
    curl                            # Download utility
    gettext                         # Internationalization
    gnupg                           # Secure package signing
    apt-transport-https             # HTTPS transport for APT
    jq                              # JSON parsing
    apache2                         # Web server
    mariadb-server                  # Database server
    software-properties-common      # For add-apt-repository
    unzip                           # Unzip utility
)

for dependency in "${dependencies[@]}"; do
    require_package "$dependency" || exit 1
done

#------------------------------------------------------------------------------
# PHP Installation
#------------------------------------------------------------------------------
# Add PHP repository and install required PHP versions and extensions
log_info "Setting up PHP repository..."

# Add PHP repository
if ! grep -q "ondrej/php" /etc/apt/sources.list.d/*.list; then
    if ! sudo add-apt-repository -y ppa:ondrej/php; then
        log_error "Failed to add PHP repository"
        exit 1
    fi

    if ! sudo apt-get update -y; then
        log_error "Failed to update package lists"
        exit 1
    fi
else
    log_info "PHP repository is already configured"
fi

for php_version in "${PHP_VERSIONS[@]}"; do
    php_version="php${php_version}"

    # List of PHP packages to install
    php_packages=(
        "${php_version}"            # Core PHP package
        "${php_version}-mysql"      # MySQL support
        "${php_version}-mbstring"   # Multibyte string support
        "${php_version}-xml"        # XML support
        "${php_version}-curl"       # cURL support
        "${php_version}-bcmath"     # BCMath support
        "${php_version}-zip"        # ZIP support
        "${php_version}-common"     # Common PHP files
        "${php_version}-cli"        # Command line interface
        "${php_version}-gd"         # GD graphics library
        "${php_version}-intl"       # Internationalization
        "${php_version}-redis"      # Redis
        "${php_version}-fpm"        # FPM
        "unzip"                     # Unzip utility
    )

    # Install PHP packages
    log_info "Installing PHP ${php_version} and extensions"
    for package in "${php_packages[@]}"; do
        require_package "$package" || exit 1
    done
done

#------------------------------------------------------------------------------
# Composer Installation
#------------------------------------------------------------------------------
# Install Composer globally if not already present
if ! package_exists composer; then
    log_info "Installing Composer"
    if ! curl -sS https://getcomposer.org/installer | sudo php -- --install-dir=/usr/local/bin --filename=composer; then
        log_error "Failed to install Composer"
        exit 1
    fi

    if [ -n "${GITHUB_TOKEN:-}" ]; then
        log_info "Setting Composer GitHub token"
        composer config --global github-oauth.github.com "$GITHUB_TOKEN"
    fi
fi

#------------------------------------------------------------------------------
# Node.js Installation
#------------------------------------------------------------------------------
# Install Node.js 20.x and npm if not already present
if ! package_exists node; then
    # Add NodeSource repository for Node.js 20.x
    log_debug "Fetching node repository"
    if ! curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -; then
        log_error "Failed to add NodeSource repository"
        exit 1
    fi

    # Install Node.js
    require_package nodejs || exit 1
fi

#------------------------------------------------------------------------------
# PM2 Installation
#------------------------------------------------------------------------------
# Install PM2 globally for Node.js process management
if ! package_exists pm2; then
    log_info "Installing PM2"
    if ! sudo npm install -g pm2; then
        log_error "Failed to install PM2"
        exit 1
    fi
fi

#------------------------------------------------------------------------------
# Redis Installation
#------------------------------------------------------------------------------

# Add Redis repository
if ! file_exists "/usr/share/keyrings/redis-archive-keyring.gpg"; then
    log_debug "Retrieving the redis keyring for signing"
    if ! curl -fsSL https://packages.redis.io/gpg | sudo gpg --yes --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg; then
        log_error "Failed to add Redis GPG key"
        exit 1
    fi
fi

if ! echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb $(lsb_release -cs) main" | \
    sudo tee /etc/apt/sources.list.d/redis.list > /dev/null; then
    log_error "Failed to add Redis repository"
    exit 1
fi

require_package redis || exit 1
