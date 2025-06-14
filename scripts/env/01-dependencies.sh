#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

# Load shared helpers
source "${SCRIPT_DIR}/env/helpers.sh"

#---------------------------------------------------#
#   Main                                            #
#---------------------------------------------------#
export COMPOSER_ALLOW_SUPERUSER=1
export NVM_DIR="$HOME/.nvm"

# Update environment
#---------------------------------------------------#
sudo apt-get update -y && sudo apt-get upgrade -y

# Install the critical dependencies eg. Curl & PHP.
#---------------------------------------------------#
log_info "Installing Curl and PHP..."
require_command curl
require_command software-properties-common

sudo add-apt-repository -y ppa:ondrej/php
sudo apt-get update -y

# Install PHP dependencies
log_info "Installing PHP Dependencies..."

require_command php8.3
require_command php8.3-mysql
require_command php8.3-mbstring
require_command php8.3-xml
require_command php8.3-curl
require_command php8.3-bcmath
require_command php8.3-zip
require_command php8.3-common
require_command php8.3-cli
require_command php8.3-gd
require_command php8.3-intl
require_command unzip

# Install Composer, NVM
#---------------------------------------------------#

if ! command -v composer &>/dev/null; then
  log_info "Installing Composer..."
  curl -sS https://getcomposer.org/installer | sudo php -- --install-dir=/usr/local/bin --filename=composer
fi

if [ ! -d "$NVM_DIR" ]; then
  log_info "Installing NVM..."
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.38.0/install.sh | bash
fi

# Ensure NVM is loaded
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"

# Install Node, PM2, JQ (For parsing JSON in a later stage)
#---------------------------------------------------#
log_info "Installing JQ..."
require_command jq

log_info "Installing Node & PM2..."
nvm install node
npm install -g pm2