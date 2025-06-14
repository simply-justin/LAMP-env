#!/usr/bin/env bash

#==============================================================================
# Environment Configuration Script
#==============================================================================
# This script sets up the development environment including:
# - Apache web server configuration
# - MariaDB database setup
# - Redis cache configuration
# - PM2 process manager setup
# - UFW firewall rules
#
# Usage:
#   ./02-environment.sh
#
# Dependencies:
#   - helpers.sh (for utility functions)
#   - Apache2
#   - MariaDB
#   - Redis
#   - PM2
#
# Environment Variables:
#   - LOG_LEVEL: Set logging level (default: INFO)
#   - CONFIG_DIR: Path to configuration directory
#==============================================================================

set -euo pipefail
IFS=$'\n\t'

# Load shared helpers
source "${SCRIPT_DIR}/helpers.sh"

# Configuration paths
readonly APACHE_LOCATION="/etc/apache2"
readonly APACHE_PORTS="${APACHE_LOCATION}/ports.conf"
readonly APACHE_VHOSTS="${APACHE_LOCATION}/sites-available"

#==============================================================================
# UFW Configuration
#==============================================================================
log_info "UFW Configuration"
log_info "Configuring the firewall..."
if ! sudo ufw allow "Apache Full"; then
    log_failure "Failed to configure UFW for Apache"
    exit 1
fi

if ! sudo ufw enable; then
    log_failure "Failed to enable UFW"
    exit 1
fi

#==============================================================================
# Apache Configuration
#==============================================================================
log_info "Apache Configuration"
log_info "Setting up Apache web server..."

# Install Apache
if ! require_command apache2; then
    log_failure "Failed to install Apache"
    exit 1
fi

# Enable required modules
log_info "Enabling Apache modules..."
# List of required Apache modules
apache_modules=(
    "proxy"         # Proxy module for reverse proxy
    "proxy_http"    # HTTP proxy support
    "proxy_wstunnel" # WebSocket proxy support
    "rewrite"       # URL rewriting
)

for module in "${apache_modules[@]}"; do
    if ! sudo a2enmod "$module"; then
        log_warn "Could not enable module $module"
    fi
done

# Remove default configurations
if file_exists "${APACHE_VHOSTS}/000-default.conf"; then
    log_info "Removing default Apache configurations..."
    sudo a2dissite 000-default.conf || true

    for conf in $APACHE_VHOSTS/000-default.conf $APACHE_VHOSTS/default-ssl.conf; do
        if file_exists "$conf"; then
            sudo rm -f "$conf"
        fi
    done
fi

# Remove default web root if it exists
if directory_exists "/var/www/html"; then
    sudo rm -rf /var/www/html
fi

# Configure ports
if grep -q "^Listen 0.0.0.0:80" "$APACHE_PORTS"; then
    log_info "Apache is already configured to listen on 0.0.0.0:80"
else
    if ! backup_file "$APACHE_PORTS"; then
        log_failure "Failed to backup ports.conf"
        exit 1
    fi

    if ! sudo sed -i 's/^Listen .*\(:80\)/Listen 0.0.0.0:80/' "$APACHE_PORTS"; then
        log_failure "Failed to update ports.conf"
        exit 1
    fi
    log_info "Updated ports.conf to listen on 0.0.0.0:80"
fi

# Configure virtual hosts
VHOST_DIR="${CONFIG_DIR}/vhosts"
if directory_exists "$VHOST_DIR"; then
    log_info "Processing virtual host configurations..."
    for vhost_file in "$VHOST_DIR"/*.conf; do
        [[ -f "$vhost_file" ]] || continue
        vhost_name="$(basename "$vhost_file")"
        dest="${APACHE_VHOSTS}/${vhost_name}"

        sudo rm -f "$dest" 2>/dev/null
        if ! sudo cp "$vhost_file" "$dest"; then
            log_failure "Failed to copy: $vhost_name"
            exit 1
        fi

        if ! sudo a2ensite "$vhost_name"; then
            log_failure "Failed to enable: $vhost_name"
            exit 1
        fi

        log_info "Configured vhost: $vhost_name"
    done
else
    log_warn "Virtual host directory not found: $VHOST_DIR"
fi

# Restart Apache
log_info "Restarting Apache..."
if ! sudo systemctl restart apache2; then
    log_failure "Failed to restart Apache"
    exit 1
fi

#==============================================================================
# PM2 Configuration
#==============================================================================
log_info "PM2 Configuration"
log_info "Configuring PM2..."

if ! ensure_directory "/etc/pm2"; then
    log_failure "Failed to create PM2 configuration directory"
    exit 1
fi

if ! sudo cp "$CONFIG_DIR/processes.config.js" /etc/pm2/processes.config.js; then
    log_failure "Failed to copy PM2 ecosystem configuration"
    exit 1
fi

#==============================================================================
# MariaDB Installation
#==============================================================================
log_info "MariaDB Installation"
log_info "Setting up MariaDB..."
if ! require_command mariadb-server; then
    log_failure "Failed to install MariaDB"
    exit 1
fi

log_info "Starting MariaDB service..."
if ! sudo systemctl enable mariadb && sudo systemctl start mariadb; then
    log_failure "Failed to start MariaDB service"
    exit 1
fi

#==============================================================================
# Redis Installation
#==============================================================================
log_info "Redis Installation"
log_info "Setting up Redis..."

# Add Redis repository
if ! file_exists "/usr/share/keyrings/redis-archive-keyring.gpg"; then
    if ! curl -fsSL https://packages.redis.io/gpg | sudo gpg --yes --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg; then
        log_failure "Failed to add Redis GPG key"
        exit 1
    fi
fi

if ! echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb $(lsb_release -cs) main" | \
    sudo tee /etc/apt/sources.list.d/redis.list > /dev/null; then
    log_failure "Failed to add Redis repository"
    exit 1
fi

if ! require_command redis; then
    log_failure "Failed to install Redis"
    exit 1
fi

log_info "Starting Redis service..."
if ! sudo systemctl enable redis-server && sudo systemctl start redis-server; then
    log_failure "Failed to start Redis service"
    exit 1
fi

log_success "Environment setup completed successfully!"