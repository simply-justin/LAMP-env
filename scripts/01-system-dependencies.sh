#!/usr/bin/env bash

#==============================================================================
# System Dependencies Installation
#==============================================================================
# Installs and configures core system dependencies for LAMP development:
# - System utilities (ACL, cURL, JQ, etc.)
# - Web server (Apache2)
# - Database (MariaDB)
# - PHP with extensions
# - Node.js and PM2
# - Composer
#==============================================================================

set -euo pipefail
IFS=$'\n\t'

# Load shared helpers
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/helpers/include.sh"

# Reconstruct PHP_VERSIONS array from string if present
IFS=',' read -r -a PHP_VERSIONS <<< "${PHP_VERSIONS_STR:-}"

#------------------------------------------------------------------------------
# System Update
#------------------------------------------------------------------------------
log_info "Updating system packages"
sudo apt-get update -y && sudo apt-get upgrade -y

#------------------------------------------------------------------------------
# Dependency Installation
#------------------------------------------------------------------------------
dependencies=(
    "acl"                             # Advanced file permissions
    "ufw"                             # Firewall
    "curl"                            # Download utility
    "jq"                              # JSON parsing
    "apache2"                         # Web server
    "mariadb-server"                  # Database server
    "software-properties-common"      # For add-apt-repository
    "unzip"                           # Unzip utility
)

for dependency in "${dependencies[@]}"; do
    require_package "$dependency" || exit 1
done

#------------------------------------------------------------------------------
# PHP Installation
#------------------------------------------------------------------------------
# Add PHP repository and install required PHP versions and extensions
log_info "Setting up PHP repository..."
add_apt_repo "ppa:ondrej/php"

for php_version in "${PHP_VERSIONS[@]}"; do
    php_version="php${php_version}"

    # List of PHP packages to install
    php_extensions=(
        "${php_version}"              # Core PHP package
        "${php_version}-bcmath"       # BCMath support
        "${php_version}-cli"          # Command line interface
        "${php_version}-common"       # Common PHP files
        "${php_version}-curl"         # cURL support
        "${php_version}-gd"           # GD graphics library
        "${php_version}-intl"         # Internationalization
        "${php_version}-mbstring"     # Multi-byte string support
        "${php_version}-mysql"        # MySQL support
        "${php_version}-opcache"      # OPcache
        "${php_version}-redis"        # Redis
        "${php_version}-xml"          # XML support
        "${php_version}-zip"          # ZIP support
        "${php_version}-fpm"          # FPM
    )

    # Install PHP packages
    log_info "Installing PHP ${php_version} and extensions"
    for package in "${php_extensions[@]}"; do
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
# Package Manager Installation
#------------------------------------------------------------------------------
if [ -n "$PACKAGE_MANAGER" ] && [ "$PACKAGE_MANAGER" != ' ' ] && ! package_exists "$PACKAGE_MANAGER"; then
    log_info "Installing $PACKAGE_MANAGER"
    if ! sudo npm install -g "$PACKAGE_MANAGER"; then
        log_error "Failed to install $PACKAGE_MANAGER"
        exit 1
    fi
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
# RabbitMQ Configuration
#------------------------------------------------------------------------------
log_info "Installing RabbitMQ"

# Check if RabbitMQ is already installed
if package_exists rabbitmq-server; then
    log_debug "RabbitMQ is already installed. Skipping installation."
else
    # Add signing keys if not present
    if [ ! -f /usr/share/keyrings/com.rabbitmq.team.gpg ]; then
        log_debug "Adding RabbitMQ Team signing key"
        if ! curl -1sLf "https://keys.openpgp.org/vks/v1/by-fingerprint/0A9AF2115F4687BD29803A206B73A36E6026DFCA" | sudo gpg --dearmor | sudo tee /usr/share/keyrings/com.rabbitmq.team.gpg > /dev/null; then
            log_error "Failed to add RabbitMQ Team signing key"
            exit 1
        fi
    fi
    if [ ! -f /usr/share/keyrings/rabbitmq.E495BB49CC4BBE5B.gpg ]; then
        log_debug "Adding Erlang signing key"
        if ! curl -1sLf https://github.com/rabbitmq/signing-keys/releases/download/3.0/cloudsmith.rabbitmq-erlang.E495BB49CC4BBE5B.key | sudo gpg --dearmor | sudo tee /usr/share/keyrings/rabbitmq.E495BB49CC4BBE5B.gpg > /dev/null; then
            log_error "Failed to add Erlang signing key"
            exit 1
        fi
    fi
    if [ ! -f /usr/share/keyrings/rabbitmq.9F4587F226208342.gpg ]; then
        log_debug "Adding RabbitMQ server signing key"
        if ! curl -1sLf https://github.com/rabbitmq/signing-keys/releases/download/3.0/cloudsmith.rabbitmq-server.9F4587F226208342.key | sudo gpg --dearmor | sudo tee /usr/share/keyrings/rabbitmq.9F4587F226208342.gpg > /dev/null; then
            log_error "Failed to add RabbitMQ server signing key"
            exit 1
        fi
    fi

    # Add sources list if not present
    if [ ! -f /etc/apt/sources.list.d/rabbitmq.list ]; then
        log_debug "Adding RabbitMQ and Erlang repositories"
        if ! sudo tee /etc/apt/sources.list.d/rabbitmq.list > /dev/null <<EOF
## Provides modern Erlang/OTP releases
##
deb [arch=amd64 signed-by=/usr/share/keyrings/rabbitmq.E495BB49CC4BBE5B.gpg] https://ppa1.rabbitmq.com/rabbitmq/rabbitmq-erlang/deb/ubuntu jammy main
deb-src [signed-by=/usr/share/keyrings/rabbitmq.E495BB49CC4BBE5B.gpg] https://ppa1.rabbitmq.com/rabbitmq/rabbitmq-erlang/deb/ubuntu jammy main

# another mirror for redundancy
deb [arch=amd64 signed-by=/usr/share/keyrings/rabbitmq.E495BB49CC4BBE5B.gpg] https://ppa2.rabbitmq.com/rabbitmq/rabbitmq-erlang/deb/ubuntu jammy main
deb-src [signed-by=/usr/share/keyrings/rabbitmq.E495BB49CC4BBE5B.gpg] https://ppa2.rabbitmq.com/rabbitmq/rabbitmq-erlang/deb/ubuntu jammy main

## Provides RabbitMQ
##
deb [arch=amd64 signed-by=/usr/share/keyrings/rabbitmq.9F4587F226208342.gpg] https://ppa1.rabbitmq.com/rabbitmq/rabbitmq-server/deb/ubuntu jammy main
deb-src [signed-by=/usr/share/keyrings/rabbitmq.9F4587F226208342.gpg] https://ppa1.rabbitmq.com/rabbitmq/rabbitmq-server/deb/ubuntu jammy main

# another mirror for redundancy
deb [arch=amd64 signed-by=/usr/share/keyrings/rabbitmq.9F4587F226208342.gpg] https://ppa2.rabbitmq.com/rabbitmq/rabbitmq-server/deb/ubuntu jammy main
deb-src [signed-by=/usr/share/keyrings/rabbitmq.9F4587F226208342.gpg] https://ppa2.rabbitmq.com/rabbitmq/rabbitmq-server/deb/ubuntu jammy main
EOF
        then
            log_error "Failed to add RabbitMQ sources list"
            exit 1
        fi
    fi

    log_info "Updating apt repositories"
    if ! sudo apt-get update -y; then
        log_error "Failed to update apt repositories"
        exit 1
    fi

    log_info "Installing Erlang dependencies"
    if ! sudo apt-get install -y erlang-base \
        erlang-asn1 erlang-crypto erlang-eldap erlang-ftp erlang-inets \
        erlang-mnesia erlang-os-mon erlang-parsetools erlang-public-key \
        erlang-runtime-tools erlang-snmp erlang-ssl \
        erlang-syntax-tools erlang-tftp erlang-tools erlang-xmerl; then
        log_error "Failed to install Erlang dependencies"
        exit 1
    fi

    require_package rabbitmq-server
fi
