#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

#-------------------------------------------------------#
#   Dependencies Installation Script                    #
#   Installs and configures core development            #
#   dependencies including PHP, Node.js, and tools      #
#-------------------------------------------------------#

# Load shared helpers
source "${SCRIPT_DIR}/env/helpers.sh"

#-------------------------------------------------------#
#   Environment Configuration                           #
#-------------------------------------------------------#
export COMPOSER_ALLOW_SUPERUSER=1
export NVM_DIR="$HOME/.nvm"

#-------------------------------------------------------#
#   System Update                                       #
#-------------------------------------------------------#
log_info "Updating system packages..."
sudo apt-get update -y

#-------------------------------------------------------#
#   UFW Installation                                    #
#-------------------------------------------------------#
log_info "Setting up UFW..."
sudo apt-get install -y ufw

#-------------------------------------------------------#
#   PHP Installation                                    #
#-------------------------------------------------------#
log_info "Setting up PHP repository..."
require_command curl
require_command software-properties-common

# Add PHP repository
sudo add-apt-repository -y ppa:ondrej/php
sudo apt-get update -y

log_info "Installing PHP and extensions..."
php_packages=(
    "php8.3"
    "php8.3-mysql"
    "php8.3-mbstring"
    "php8.3-xml"
    "php8.3-curl"
    "php8.3-bcmath"
    "php8.3-zip"
    "php8.3-common"
    "php8.3-cli"
    "php8.3-gd"
    "php8.3-intl"
    "unzip"
)

# Install PHP packages
log_info "Installing PHP packages..."
for package in "${php_packages[@]}"; do
    require_command "$package"
done

#-------------------------------------------------------#
#   Composer Installation                               #
#-------------------------------------------------------#
if ! command -v composer &>/dev/null; then
    log_info "Installing Composer..."
    curl -sS https://getcomposer.org/installer | sudo php -- --install-dir=/usr/local/bin --filename=composer
fi

#-------------------------------------------------------#
#   Node.js and Tools Installation                      #
#-------------------------------------------------------#

# Install Node.js if not present
if ! command -v node &> /dev/null; then
    log_info "Installing Node.js..."
    
    # Add NodeSource repository
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    
    # Install Node.js
    sudo apt-get install -y nodejs
    
    # Verify installation
    if ! command -v node &> /dev/null; then
        log_error "Node.js installation failed"
        exit 1
    fi
    
    # Verify npm installation
    if ! command -v npm &> /dev/null; then
        log_error "npm installation failed"
        exit 1
    fi
fi

#-------------------------------------------------------#
#   JQ Installation                                     #
#-------------------------------------------------------#

# Install JQ if not present
if ! command -v jq &> /dev/null; then
    log_info "Installing JQ..."
    require_command jq
fi

#-------------------------------------------------------#
#   PM2 Installation                                    #
#-------------------------------------------------------#

# Install PM2 if not present
if ! command -v pm2 &> /dev/null; then
    log_info "Installing PM2..."
    if ! sudo npm install -g pm2; then
        log_error "Failed to install PM2"
        exit 1
    fi
    
    # Verify PM2 installation
    if ! command -v pm2 &> /dev/null; then
        log_error "PM2 installation failed"
        exit 1
    fi
fi

log_info "Dependencies installation completed successfully!"