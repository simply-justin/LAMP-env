#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

#-------------------------------------------------------#
#   Project Setup Script                               #
#   Clones and configures development projects          #
#   based on the repositories configuration file        #
#-------------------------------------------------------#

# Load shared helpers
source "${SCRIPT_DIR}/env/helpers.sh"

#-------------------------------------------------------#
#   Configuration Validation                            #
#-------------------------------------------------------#
REPO_FILE="${CONFIG_DIR}/repos.json"

# Check for required tools
if ! command -v jq >/dev/null 2>&1; then
    log_error "jq is required but not installed. Please install jq."
    exit 1
fi

# Validate repository configuration file
if [ ! -f "$REPO_FILE" ]; then
    log_error "Repository configuration file not found: $REPO_FILE"
    exit 1
fi

# Validate JSON structure
if ! jq empty "$REPO_FILE" 2>/dev/null; then
    log_error "Invalid JSON in repository configuration file"
    exit 1
fi

#-------------------------------------------------------#
#   Project Setup                                       #
#-------------------------------------------------------#
repo_count=$(jq '. | length' "$REPO_FILE")
if [ "$repo_count" -eq 0 ]; then
    log_warn "No repositories configured in $REPO_FILE"
    exit 0
fi

log_info "Processing $repo_count repositories from configuration"

# Create development directory
DEV_DIR="$HOME/../dev"
if ! mkdir -p "$DEV_DIR"; then
    log_error "Failed to create development directory: $DEV_DIR"
    exit 1
fi

# Process each repository
for i in $(seq 0 $((repo_count - 1))); do
    org=$(jq -r ".[$i].org" "$REPO_FILE")
    repo=$(jq -r ".[$i].repo" "$REPO_FILE")
    target_dir=$(jq -r ".[$i].target_dir" "$REPO_FILE")

    # Validate repository configuration
    if [ -z "$org" ] || [ -z "$repo" ] || [ -z "$target_dir" ]; then
        log_error "Invalid repository configuration at index $i"
        continue
    fi

    log_info "Setting up repository: $org/$repo"
    
    # Clone and install repository
    if ! clone_and_install "$org" "$repo" "$target_dir"; then
        log_error "Failed to setup repository: $org/$repo"
        continue
    fi

    # Create symbolic link
    symlink_path="/var/www/$repo"
    if [ -L "$symlink_path" ]; then
        log_info "Updating existing symbolic link: $symlink_path"
        sudo rm "$symlink_path"
    fi

    if ! sudo ln -s "$HOME/../$target_dir" "$symlink_path"; then
        log_error "Failed to create symbolic link for $repo"
        continue
    fi

    sudo chown -R www-data:www-data $symlink_path

    log_info "Successfully configured repository: $org/$repo"
done

# Start the PM2 Processes
if ! sudo pm2 start /etc/pm2/ecosystem.config.js; then
    log_error "Failed to start PM2 processes"
    exit 1
fi

if ! sudo pm2 save && sudo pm2 startup; then
    log_error "Failed to configure PM2 startup"
    exit 1
fi

log_info "Project setup completed successfully!"