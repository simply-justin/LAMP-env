#!/usr/bin/env bash

#==============================================================================
# Dependencies Installation Script
#==============================================================================
# This script installs and configures core development dependencies including:
# - UFW firewall
# - JQ
# - PHP 8.3 and extensions
# - Composer
# - Node.js and npm
# - PM2
#==============================================================================

set -euo pipefail
IFS=$'\n\t'

# Load shared helpers
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/helpers/include.sh"

# Reconstruct PHP_VERSIONS array from string if present
IFS=' ' read -r -a PHP_VERSIONS <<< "${PHP_VERSIONS_STR:-}"

#------------------------------------------------------------------------------
# System Update
#------------------------------------------------------------------------------
log_info "Updating system packages"
sudo apt-get update -y && sudo apt-get upgrade -y

#------------------------------------------------------------------------------
# UWF (Firewall) Installation
#------------------------------------------------------------------------------
log_info "Installing UWF (Firewall)"
require_command ufw || exit 1

#------------------------------------------------------------------------------
# cURL + JQ Installation
#------------------------------------------------------------------------------
log_info "Installing cURL"
require_command curl || exit 1

log_info "Installing JQ"
require_command jq || exit 1

#------------------------------------------------------------------------------
# PHP Installation
#------------------------------------------------------------------------------
log_info "Setting up PHP repository..."

if ! dpkg -l | grep -q "software-properties-common"; then
    require_command software-properties-common || exit 1
fi

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
    # List of PHP packages to install
    php_packages=(
        "php${php_version}"           # Core PHP package
        "php${php_version}-mysql"     # MySQL support
        "php${php_version}-mbstring"  # Multibyte string support
        "php${php_version}-xml"       # XML support
        "php${php_version}-curl"      # cURL support
        "php${php_version}-bcmath"    # BCMath support
        "php${php_version}-zip"       # ZIP support
        "php${php_version}-common"    # Common PHP files
        "php${php_version}-cli"       # Command line interface
        "php${php_version}-gd"        # GD graphics library
        "php${php_version}-intl"      # Internationalization
        "unzip"                       # Unzip utility
    )

    # Install PHP packages
    log_info "Installing PHP ${php_version} and extensions"
    for package in "${php_packages[@]}"; do
        log_debug "[PHP] installing extension: $package"
        require_command "$package" || exit 1
    done
done

#------------------------------------------------------------------------------
# Composer Installation
#------------------------------------------------------------------------------
if ! command_exists composer; then
    log_info "Installing Composer"
    if ! curl -sS https://getcomposer.org/installer | sudo php -- --install-dir=/usr/local/bin --filename=composer; then
        log_error "Failed to install Composer"
        exit 1
    fi
fi

#------------------------------------------------------------------------------
# Node.js Installation
#------------------------------------------------------------------------------
if ! command_exists node; then
    # Add NodeSource repository for Node.js 20.x
    log_debug "Fetching node repository"
    if ! curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -; then
        log_error "Failed to add NodeSource repository"
        exit 1
    fi

    # Install Node.js
    log_info "Installing Node.js"
    require_command nodejs || exit 1

    # Verify installations
    if ! command_exists node || ! command_exists npm; then
        log_error "Node.js or npm installation failed"
        exit 1
    fi
fi

#------------------------------------------------------------------------------
# Node.js Installation
#------------------------------------------------------------------------------
if ! command_exists pm2; then
    log_info "Installing PM2"
    if ! sudo npm install -g pm2; then
        log_error "Failed to install PM2"
        exit 1
    fi

    if ! command_exists pm2; then
        log_error "PM2 installation failed"
        exit 1
    fi
fi
