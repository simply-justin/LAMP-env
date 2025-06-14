#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

# Load shared helpers
source "${SCRIPT_DIR}/env/helpers.sh"

# Ensure NPM is initialized
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
nvm use node

#---------------------------------------------------#
#   Main                                            #
#---------------------------------------------------#

# Install Apache2
#---------------------------------------------------#
log_info "Installing Apache..."
require_command apache2

log_info "Enabling Apache modules..."
for module in proxy proxy_http proxy_wstunnel rewrite; do
  sudo a2enmod "$module" || log_warn "Could not enable module $module"
done

sudo a2dissite 000-default.conf || true

log_info "Removing default Apache config files if they exist..."
for conf in /etc/apache2/sites-available/000-default.conf /etc/apache2/sites-available/default-ssl.conf; do
  [[ -f $conf ]] && rm -f "$conf"
done


# Configure ports.conf
PORTS_CONF="/etc/apache2/ports.conf"
if grep -q "^Listen 0.0.0.0:80" "$PORTS_CONF"; then
  log_info "Apache is already configured to listen on 0.0.0.0:80"
else
  cp "$PORTS_CONF" "${PORTS_CONF}.bak"
  sudo sed -i 's/^Listen .*\(:80\)/Listen 0.0.0.0:80/' "$PORTS_CONF"
  log_info "Updated ports.conf to listen on 0.0.0.0:80"
fi

# Copy and enable custom vhosts
VHOST_DIR="${CONFIG_DIR}/vhosts"
if [ -d "$VHOST_DIR" ]; then
  log_info "Processing vhost files in $VHOST_DIR..."
  for vhost_file in "$VHOST_DIR"/*.conf; do
    dest="/etc/apache2/sites-available/$(basename "$vhost_file")"
    if [ -f "$dest" ]; then
      log_info "Skipping existing vhost: $(basename "$vhost_file")"
    else
      log_info "Copying and enabling vhost: $(basename "$vhost_file")"
      sudo cp "$vhost_file" "$dest"
      sudo a2ensite "$(basename "$vhost_file")"
    fi
  done
else
  log_warn "Vhost directory does not exist: $VHOST_DIR"
fi

log_info "Restarting Apache..."
sudo systemctl restart apache2 || log_error "Apache failed to restart"

# Install MariaDB
#---------------------------------------------------#
log_info "Installing MariaDB..."
require_command mariadb-server

log_info "Starting and enabling MariaDB..."
sudo systemctl enable mariadb
sudo systemctl start mariadb

# Install Redis
#---------------------------------------------------#
log_info "Installing Redis..."

if [ ! -f "/usr/share/keyrings/redis-archive-keyring.gpg" ]; then
  curl -fsSL https://packages.redis.io/gpg | sudo gpg --yes --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg
fi

echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb $(lsb_release -cs) main" | \
  sudo tee /etc/apt/sources.list.d/redis.list > /dev/null

require_command redis

log_info "Starting Redis..."
sudo systemctl enable redis-server
sudo systemctl start redis-server

log_info "Environment setup complete."

# Setup PM2
#---------------------------------------------------#
log_info "Setup PM2..."

sudo mkdir -p /etc/pm2
sudo cp $CONFIG_DIR/ecosystem.config.js /etc/pm2/ecosystem.config.js

sudo pm2 start /etc/pm2/ecosystem.config.js
sudo pm2 save
sudo pm2 startup