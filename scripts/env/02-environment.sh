#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

#-------------------------------------------------------#
#   Environment Configuration Script                    #
#   Sets up web server, database, and caching           #
#   services for the development environment            #
#-------------------------------------------------------#

# Load shared helpers
source "${SCRIPT_DIR}/env/helpers.sh"

#-------------------------------------------------------#
#   UFW Configuration                                   #
#-------------------------------------------------------#
sudo ufw allow "Apache Full"
sudo ufw enable

#-------------------------------------------------------#
#   Apache Configuration                                #
#-------------------------------------------------------#
log_info "Setting up Apache web server..."

# Install Apache
require_command apache2

# Enable required modules
log_info "Enabling Apache modules..."
apache_modules=(
    "proxy"
    "proxy_http"
    "proxy_wstunnel"
    "rewrite"
)

for module in "${apache_modules[@]}"; do
    if ! sudo a2enmod "$module"; then
        log_warn "Could not enable module $module"
    fi
done

# Remove default configurations
log_info "Removing default Apache configurations..."
sudo a2dissite 000-default.conf || true

for conf in /etc/apache2/sites-available/000-default.conf /etc/apache2/sites-available/default-ssl.conf; do
    if [ -f "$conf" ]; then
        sudo rm -f "$conf"
    fi
done

# Remove default web root if it exists
if [ -d "/var/www/html" ]; then
    sudo rm -rf /var/www/html
fi

# Configure ports
PORTS_CONF="/etc/apache2/ports.conf"
if grep -q "^Listen 0.0.0.0:80" "$PORTS_CONF"; then
    log_info "Apache is already configured to listen on 0.0.0.0:80"
else
    cp "$PORTS_CONF" "${PORTS_CONF}.bak"
    if ! sudo sed -i 's/^Listen .*\(:80\)/Listen 0.0.0.0:80/' "$PORTS_CONF"; then
        log_error "Failed to update ports.conf"
        exit 1
    fi
    log_info "Updated ports.conf to listen on 0.0.0.0:80"
fi

# Configure virtual hosts
VHOST_DIR="${CONFIG_DIR}/vhosts"
if [ -d "$VHOST_DIR" ]; then
    log_info "Processing virtual host configurations..."
    for vhost_file in "$VHOST_DIR"/*.conf; do
        if [ -f "$vhost_file" ]; then
            dest="/etc/apache2/sites-available/$(basename "$vhost_file")"
            if [ -f "$dest" ]; then
                log_info "Skipping existing vhost: $(basename "$vhost_file")"
            else
                log_info "Configuring vhost: $(basename "$vhost_file")"
                if ! sudo cp "$vhost_file" "$dest"; then
                    log_error "Failed to copy vhost configuration: $(basename "$vhost_file")"
                    exit 1
                fi
                if ! sudo a2ensite "$(basename "$vhost_file")"; then
                    log_error "Failed to enable vhost: $(basename "$vhost_file")"
                    exit 1
                fi
            fi
        fi
    done
else
    log_warn "Virtual host directory not found: $VHOST_DIR"
fi

# Restart Apache
log_info "Restarting Apache..."
if ! sudo systemctl restart apache2; then
    log_error "Failed to restart Apache"
    exit 1
fi

#-------------------------------------------------------#
#   MariaDB Installation                                #
#-------------------------------------------------------#
log_info "Setting up MariaDB..."
require_command mariadb-server

log_info "Starting MariaDB service..."
if ! sudo systemctl enable mariadb && sudo systemctl start mariadb; then
    log_error "Failed to start MariaDB service"
    exit 1
fi

#-------------------------------------------------------#
#   Redis Installation                                  #
#-------------------------------------------------------#
log_info "Setting up Redis..."

# Add Redis repository
if [ ! -f "/usr/share/keyrings/redis-archive-keyring.gpg" ]; then
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

require_command redis

log_info "Starting Redis service..."
if ! sudo systemctl enable redis-server && sudo systemctl start redis-server; then
    log_error "Failed to start Redis service"
    exit 1
fi

#-------------------------------------------------------#
#   PM2 Configuration                                   #
#-------------------------------------------------------#
log_info "Configuring PM2..."

if ! sudo mkdir -p /etc/pm2; then
    log_error "Failed to create PM2 configuration directory"
    exit 1
fi

if ! sudo cp "$CONFIG_DIR/ecosystem.config.js" /etc/pm2/ecosystem.config.js; then
    log_error "Failed to copy PM2 ecosystem configuration"
    exit 1
fi

log_info "Environment setup completed successfully!"