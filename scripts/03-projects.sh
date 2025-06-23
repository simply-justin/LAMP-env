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

declare -a processIds

for i in $(seq 0 $((repo_count - 1))); do
    (
        org=$(jq -r ".[$i].org" "$REPO_FILE")
        repo=$(jq -r ".[$i].repo" "$REPO_FILE")
        target_dir=$(jq -r ".[$i].target_dir" "$REPO_FILE")

        # Exit process since its configuration is invalid
        [ -z "$org" ] || [ -z "$repo" ] || [ -z "$target_dir" ] && exit 1

        clone_and_install "$org" "$repo" "${HOME}${target_dir}/${repo}" || exit 1

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
for i in $(seq 0 $((repo_count - 1))); do
    org=$(jq -r ".[$i].org" "$REPO_FILE")
    repo=$(jq -r ".[$i].repo" "$REPO_FILE")
    target_dir=$(jq -r ".[$i].target_dir" "$REPO_FILE")

    [ -z "$org" ] || [ -z "$repo" ] || [ -z "$target_dir" ] && continue

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

    log_info "Successfully configured project: $org/$repo"
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

eval "$(pm2 startup | grep sudo)"

# Save the current PM2 process list
log_info "Saving current PM2 process list"
if ! pm2 save; then
    log_error "Failed to save PM2 process list"
    exit 1
fi
