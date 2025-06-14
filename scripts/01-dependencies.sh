#!/usr/bin/env bash

#==============================================================================
# Dependencies Installation Script
#==============================================================================
# This script installs and configures core development dependencies including:
# - PHP 8.3 and extensions
# - Node.js and npm
# - Composer
# - UFW firewall
# - JQ
# - PM2
#
# Usage:
#   ./01-dependencies.sh
#
# Dependencies:
#   - helpers.sh (for utility functions)
#   - Internet connection
#   - Sudo privileges
#
# Environment Variables:
#   - LOG_LEVEL: Set logging level (default: INFO)
#==============================================================================

set -euo pipefail
IFS=$'\n\t'

# Load shared helpers
source "${SCRIPT_DIR}/helpers.sh"

#==============================================================================
# System Update
#==============================================================================
log_info "System Update"
log_info "Updating system packages..."
if ! sudo apt-get update -y; then
    log_failure "Failed to update system packages"
    exit 1
fi

#==============================================================================
# UFW Installation
#==============================================================================
log_info "UFW Installation"
log_info "Setting up UFW..."
require_command ufw || {
    log_failure "Failed to install UFW"
    exit 1
}

#==============================================================================
# PHP Installation
#==============================================================================
log_info "PHP Installation"
log_info "Setting up PHP repository..."

# Ensure required commands are available
require_command curl
require_command software-properties-common

# Add PHP repository
if ! sudo add-apt-repository -y ppa:ondrej/php; then
    log_failure "Failed to add PHP repository"
    exit 1
fi

if ! sudo apt-get update -y; then
    log_failure "Failed to update package lists"
    exit 1
fi

log_info "Installing PHP and extensions..."
# List of PHP packages to install
php_packages=(
    "php8.3"           # Core PHP package
    "php8.3-mysql"     # MySQL support
    "php8.3-mbstring"  # Multibyte string support
    "php8.3-xml"       # XML support
    "php8.3-curl"      # cURL support
    "php8.3-bcmath"    # BCMath support
    "php8.3-zip"       # ZIP support
    "php8.3-common"    # Common PHP files
    "php8.3-cli"       # Command line interface
    "php8.3-gd"        # GD graphics library
    "php8.3-intl"      # Internationalization
    "unzip"            # Unzip utility
)

# Install PHP packages
for package in "${php_packages[@]}"; do
    if ! require_command "$package"; then
        log_failure "Failed to install PHP package: $package"
        exit 1
    fi
done

#==============================================================================
# Composer Installation
#==============================================================================
log_info "Composer Installation"
if ! command_exists composer; then
    log_info "Installing Composer..."
    if ! curl -sS https://getcomposer.org/installer | sudo php -- --install-dir=/usr/local/bin --filename=composer; then
        log_failure "Failed to install Composer"
        exit 1
    fi
fi

#==============================================================================
# Node.js Installation
#==============================================================================
log_info "Node.js Installation"
if ! command_exists node; then
    log_info "Installing Node.js..."
    
    # Add NodeSource repository for Node.js 20.x
    if ! curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -; then
        log_failure "Failed to add NodeSource repository"
        exit 1
    fi
    
    # Install Node.js
    if ! require_command nodejs; then
        log_failure "Failed to install Node.js"
        exit 1
    fi
    
    # Verify installations
    if ! command_exists node || ! command_exists npm; then
        log_failure "Node.js or npm installation failed"
        exit 1
    fi
fi

#==============================================================================
# JQ Installation
#==============================================================================
log_info "JQ Installation"
if ! command_exists jq; then
    log_info "Installing JQ..."
    if ! require_command jq; then
        log_failure "Failed to install JQ"
        exit 1
    fi
fi

#==============================================================================
# PM2 Installation
#==============================================================================
log_info "PM2 Installation"
if ! command_exists pm2; then
    log_info "Installing PM2..."
    if ! npm install -g pm2; then
        log_failure "Failed to install PM2"
        exit 1
    fi
    
    if ! command_exists pm2; then
        log_failure "PM2 installation failed"
        exit 1
    fi

    sudo chown $CURRENT_USER:$CURRENT_USER /home/$CURRENT_USER/.pm2/rpc.sock /home/$CURRENT_USER/.pm2/pub.sock
fi

log_success "Dependencies installation completed successfully!"