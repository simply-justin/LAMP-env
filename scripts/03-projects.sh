#!/usr/bin/env bash

#==============================================================================
# Project Setup Script
#==============================================================================
# This script clones and configures development projects based on the
# repositories configuration file. It handles:
# - Repository cloning
# - Dependency installation (PHP/Node.js)
# - Symbolic link creation
# - PM2 process management
#==============================================================================

set -euo pipefail
IFS=$'\n\t'

# Load shared helpers
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/helpers/include.sh"

readonly REPO_FILE="${CONFIG_DIR}/projects.json"

#-------------------------------------------------------#
# Configuration Validation
#-------------------------------------------------------#
log_info "Configuration Validation"

# Check for required tools
if ! command_exists jq; then
    log_error "JQ is required but not installed. Please install jq."
    exit 1
fi

# Validate repository configuration file
if ! file_exists "$REPO_FILE"; then
    log_error "Repository configuration file not found: $REPO_FILE"
    exit 1
fi

# Validate JSON structure
if ! jq empty "$REPO_FILE" 2>/dev/null; then
    log_error "Invalid JSON in repository configuration file"
    exit 1
fi

#-------------------------------------------------------#
# Shared group Setup
#-------------------------------------------------------#
if ! getent group "devgroup" > /dev/null; then
    log_info "Creating devgroup"
    sudo groupadd devgroup
fi

# Ensure Apache (www-data) is part of devgroup
sudo usermod -aG devgroup www-data
sudo usermod -aG devgroup $USER

#-------------------------------------------------------#
# Project Setup
#-------------------------------------------------------#
# Count repositories in configuration
repo_count=$(jq '. | length' "$REPO_FILE")
if [ "$repo_count" -eq 0 ]; then
    log_warn "No repositories configured in $REPO_FILE"
    exit 0
fi

# Create development directory
ensure_directory "${HOME}/dev" || exit 1

# Process each repository
log_debug "Processing $repo_count repositories from configuration"

declare -a processIds

for i in $(seq 0 $((repo_count - 1))); do
    (
        org=$(jq -r ".[$i].org" "$REPO_FILE")
        repo=$(jq -r ".[$i].repo" "$REPO_FILE")
        target_dir=$(jq -r ".[$i].target_dir" "$REPO_FILE")

        # Exit process since its configuration is invalid
        [ -z "$org" ] || [ -z "$repo" ] || [ -z "$target_dir" ] && exit 1

        clone_repository "$target_dir" "$org" "$repo" || exit 1
        install_dependencies "$target_dir" "$repo" || exit 1

        log_debug "Finished setup for $repo"
    ) &
    processIds+=($!)
done

# Wait for all parallel tasks to finish
for pid in "${processIds[@]}"; do
    wait "$pid" || log_error "One of the setup processes have failed"
done

log_debug "All project installation processes are complete"

# Now handle symlinks serially (as they often require sudo and global paths)
log_info "Creating symbolic links and setting permissions"
for i in $(seq 0 $((repo_count - 1))); do
    org=$(jq -r ".[$i].org" "$REPO_FILE")
    repo=$(jq -r ".[$i].repo" "$REPO_FILE")
    target_dir=$(jq -r ".[$i].target_dir" "$REPO_FILE")

    [ -z "$org" ] || [ -z "$repo" ] || [ -z "$target_dir" ] && continue

    # Full path to the repo directory
    repo_path="${HOME}${target_dir}/${repo}"
    symlink_path="/var/www/$repo"

    # Ensure the symlink target exists
    if ! [ -d "$repo_path" ]; then
        log_error "Symlink target does not exist: $repo_path"
        continue
    fi

    # Remove existing symlink if present
    if [ -L "$symlink_path" ]; then
        log_debug "Remove existing symbolic link: $symlink_path"
        sudo unlink "$symlink_path"
    fi

    log_debug "Making a new symbolic link"
    if ! sudo ln -s "$repo_path" "$symlink_path"; then
        log_error "Failed to create symbolic link for $repo"
        continue
    fi

    # Change group ownership recursively
    sudo chgrp -R devgroup $repo_path

    # Set safe, consistent permissions
    sudo find "$repo_path" -type d -exec chmod 2770 {} \;
    sudo find "$repo_path" -type f -exec chmod 660 {} \;

    # Set default ACLs for all future files/dirs
    sudo setfacl -d -m u::rwX "$repo_path"
    sudo setfacl -d -m g::rwX "$repo_path"
    sudo setfacl -d -m o::0 "$repo_path"

    log_info "Successfully configured project: $org/$repo"
done

# Restart Apache to apply changes
sudo systemctl restart apache2

#-------------------------------------------------------#
# PM2 Process Management
#-------------------------------------------------------#
log_info "Starting the PM2 processes"
if ! pm2 start /etc/pm2/pm2.config.js; then
    log_error "Failed to start PM2 processes"
    exit 1
fi

# Configure PM2 to start on system boot
log_debug "saving the PM2 processes to startup"

eval "$(pm2 startup | grep sudo)"

# Save the current PM2 process list
log_info "Saving current PM2 process list"
if ! pm2 save; then
    log_error "Failed to save PM2 process list"
    exit 1
fi
