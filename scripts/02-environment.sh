#!/usr/bin/env bash

#==============================================================================
# Environment Configuration Script
#==============================================================================
# This script sets up the development environment including:
# - Apache web server configuration
# - PM2 process manager setup
# - MariaDB database setup
# - RabbitMQ message broker setup
# - Redis cache configuration
#==============================================================================

set -euo pipefail
IFS=$'\n\t'

# Load shared helpers
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/helpers/include.sh"

# Reconstruct PHP_VERSIONS array from string if present
IFS=' ' read -r -a PHP_VERSIONS <<< "${PHP_VERSIONS_STR:-}"

readonly APACHE_LOCATION="/etc/apache2"
readonly APACHE_PORTS="${APACHE_LOCATION}/ports.conf"
readonly APACHE_VHOSTS="${APACHE_LOCATION}/sites-available"

export COMPOSER_ALLOW_SUPERUSER=1

#------------------------------------------------------------------------------
# UFW (Firewall) Configuration
#------------------------------------------------------------------------------
log_info "Configuring UFW (Firewall)"

if ! sudo ufw status | grep -q "Apache Full"; then
    log_debug "Allowing Apache Full (80, 443)"
    if ! sudo ufw allow "Apache Full"; then
        log_error "Failed to allow Apache"
        exit 1
    fi
fi

if ! sudo ufw status | grep -q "Status: active"; then
    log_debug "enabling UFW"
    if ! sudo ufw enable; then
        log_error "Failed to enable UFW"
        exit 1
    fi
fi

#------------------------------------------------------------------------------
# Apache2 + PHP-FPM Configuration
#------------------------------------------------------------------------------
# Remove default Apache vhost and web root to avoid conflicts
if file_exists "${APACHE_VHOSTS}/000-default.conf"; then
    log_info "Removing default Apache configurations..."

    log_debug "Disabling site: 000-default"
    sudo a2dissite 000-default.conf || true

    for conf in $APACHE_VHOSTS/000-default.conf $APACHE_VHOSTS/default-ssl.conf; do
        if file_exists "$conf"; then
            log_debug "Removing default configuration: $conf"
            sudo rm -f "$conf"
        fi
    done
fi

# Remove default web root if it exists
if directory_exists "/var/www/html"; then
    log_debug "Removing default web root /var/www/html"
    sudo rm -rf /var/www/html
fi

# Configure ports
# Ensure Apache listens on all interfaces (0.0.0.0:80)
if ! grep -q "^Listen 0.0.0.0:80" "$APACHE_PORTS"; then
    log_debug "Backing up the current ports.conf"
    backup_file "$APACHE_PORTS" || exit 1

    log_info "Updating ports.conf to listen on 0.0.0.0:80"
    if ! sudo sed -i -E 's/^Listen( +| +0\.0\.0\.0)?(:)?80$/Listen 0.0.0.0:80/' "$APACHE_PORTS"; then
        log_error "Failed to update ports.conf"
        exit 1
    fi
fi

# List of required Apache modules
apache_modules=(
    "proxy"             # Proxy module for reverse proxy
    "proxy_http"        # HTTP proxy support
    "proxy_fcgi"        # FastCGI support
    "proxy_wstunnel"    # WebSocket proxy support
    "rewrite"           # URL rewriting
    "headers"           # Headers module
    "setenvif"          # Set environment variables based on request
)

log_info "Enabling Apache2 modules"
for module in "${apache_modules[@]}"; do
    if ! apache2ctl -M | grep -q "$module"; then
        log_debug "Enabling $module"
        if ! sudo a2enmod "$module"; then
            log_warn "Could not enable module $module"
        fi
    else
        log_debug "Module $module is already enabled"
    fi
done

# Handle php versions
for php_version in "${PHP_VERSIONS[@]}"; do
    php_version="php${php_version}"

    # Disable default apache php module
    if apache2ctl -M | grep -q "$php_version"; then
        log_debug "Disabling $php_version"
        if ! sudo a2dismod "$php_version"; then
            log_warn "Could not disable module $php_version"
        fi
    else
        log_debug "Module $php_version is already disabled"
    fi

    # Enable the PHP-FPM config
    if [ ! -e "/etc/apache2/conf-enabled/${php_version}-fpm.conf" ]; then
        log_debug "Enabling PHP-FPM config for $php_version"
        if ! sudo a2enconf "$php_version-fpm"; then
            log_warn "Could not enable PHP-FPM config for $php_version"
        fi
    else
        log_debug "PHP-FPM config for $php_version is already enabled"
    fi

    # Enable and start the PHP-FPM service
    enable_service "$php_version-fpm"
done

# Configure virtual hosts
# Copy and enable all vhost files from $CONFIG_DIR/vhosts
VHOST_DIR="${CONFIG_DIR}/vhosts"
if directory_exists "$VHOST_DIR"; then
    log_info "Processing vHost configurations"
    for vhost_file in "$VHOST_DIR"/*.conf; do
        [[ -f "$vhost_file" ]] || continue
        vhost_name="$(basename "$vhost_file")"
        dest="${APACHE_VHOSTS}/${vhost_name}"

        # Overwrite existing vhost config if present
        if file_exists "$dest"; then
            log_info "Updating $vhost_name because it already exists"
        fi

        log_debug "Removing existing configuration ($dest)"
        sudo rm -f "$dest" 2>/dev/null

        log_debug "Copying $vhost_file to $dest"
        if ! sudo cp "$vhost_file" "$dest"; then
            log_error "Failed to copy: $vhost_name"
            exit 1
        fi

        if ! apache2ctl -S | grep -q "$vhost_name"; then
            log_debug "Enabling site: $vhost_name"
            if ! sudo a2ensite "$vhost_name"; then
                log_error "Failed to enable: $vhost_name"
                exit 1
            fi
        else
            log_debug "Virtual host $vhost_name is already enabled"
        fi

        log_info "Configured vhost: $vhost_name"
    done
else
    log_warn "Virtual host directory not found: $VHOST_DIR"
fi

# Restart Apache
log_info "Restarting Apache2"
if ! sudo systemctl restart apache2; then
    log_error "Failed to restart Apache"
    exit 1
fi

#------------------------------------------------------------------------------
# PM2 Configuration
#------------------------------------------------------------------------------
log_info "Configuring PM2"
ensure_directory "/etc/pm2" || exit 1

log_debug "Copying pm2.config.js to /etc/pm2"
if ! sudo cp "$CONFIG_DIR/pm2.config.js" /etc/pm2/pm2.config.js; then
    log_error "Failed to copy PM2 configuration"
    exit 1
fi

#------------------------------------------------------------------------------
# MariaDB Configuration
#------------------------------------------------------------------------------
log_info "Starting MariaDB service"
enable_service "mariadb"

# Run equivalent of mysql_secure_installation
# Set root password and remove anonymous users
log_debug "Configuring MariaDB"

log_debug "Checking MariaDB root access"
if sudo mariadb -u root -e "SELECT 1;" >/dev/null 2>&1; then
    log_info "Root login requires no password — performing initial secure setup."

    sudo mariadb -u root <<EOF
-- Set root password
$( [ -n "$MARIADB_ROOT_PASSWORD" ] && echo "ALTER USER 'root'@'localhost' IDENTIFIED VIA mysql_native_password USING PASSWORD('${MARIADB_ROOT_PASSWORD}');" )
-- Remove anonymous users
DELETE FROM mysql.user WHERE User='';
-- Disallow remote root login
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
-- Remove test database
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
-- Reload privilege tables
FLUSH PRIVILEGES;
EOF

else
    log_debug "MariaDB already secured. Skipping secure setup."
fi

#------------------------------------------------------------------------------
# Redis Configuration
#------------------------------------------------------------------------------

log_info "Starting Redis service"
enable_service "redis-server"
