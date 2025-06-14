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
for i in $(seq 0 $((repo_count - 1))); do
    # Extract repository information
    org=$(jq -r ".[$i].org" "$REPO_FILE")
    repo=$(jq -r ".[$i].repo" "$REPO_FILE")
    target_dir=$(jq -r ".[$i].target_dir" "$REPO_FILE")

    # Validate repository configuration
    if [ -z "$org" ] || [ -z "$repo" ] || [ -z "$target_dir" ]; then
        log_error "Invalid repository configuration at index $i"
        continue
    fi

    log_debug "Setting up repository: $org/$repo"

    # Clone and install repository
    if ! clone_and_install "$org" "$repo" "${HOME}${target_dir}/${repo}"; then
        log_error "Failed to setup repository: $org/$repo"
        continue
    fi

    # Create symbolic link
    symlink_path="/var/www/$repo"
    if [ -L "$symlink_path" ]; then
        log_debug "Remove existing symbolic link: $symlink_path"
        sudo rm "$symlink_path"
    fi

    log_debug "Making a new symbolic link"
    if ! sudo ln -s "${HOME}${target_dir}/${repo}" "$symlink_path"; then
        log_error "Failed to create symbolic link for $repo"
        continue
    fi

    log_debug "Making the www-data user & group owner of the symlink"
    if ! sudo chown -R www-data:www-data "$symlink_path"; then
        log_error "Failed to set permissions for $repo"
        continue
    fi

    log_info "Successfully configured repository: $org/$repo"
done

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
if ! pm2 save && pm2 startup; then
    log_error "Failed to configure PM2 startup"
    exit 1
fi
