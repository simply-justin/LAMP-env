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
sudo apt-get install -y php8.3 php8.3-{mysql,mbstring,xml,curl,bcmath,zip,tokenizer,common,cli,gd,intl}

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