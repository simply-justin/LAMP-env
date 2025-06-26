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
log_info "Validating Project Configuration"

# Single check for jq, config file, and valid JSON
if ! package_exists jq || ! file_exists "$REPO_FILE" || ! jq empty "$REPO_FILE" 2>/dev/null; then
    log_error "JQ is required, or the repository configuration file is missing/invalid. Please check your setup."
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
ensure_directory "${HOME}/projects" || exit 1

# Process each repository in parallel for faster setup
log_debug "Processing $repo_count repositories from configuration"

# Use background sub-shells for parallel processing
declare -a processIds

for i in $(seq 0 $((repo_count - 1))); do
    (
        set -e  # Exit on any error in subshell

        org=$(jq -r ".[$i].org" "$REPO_FILE")
        repo=$(jq -r ".[$i].repo" "$REPO_FILE")
        target_dir=$(jq -r ".[$i].target_dir" "$REPO_FILE")

        # Exit process since its configuration is invalid
        if [ -z "$org" ] || [ -z "$repo" ] || [ -z "$target_dir" ]; then
            log_error "Invalid configuration for repository $i"
            exit 1
        fi

        if ! directory_exists "${HOME}${target_dir}/${repo}"; then
            repo_url="https://${GITHUB_TOKEN}@github.com/${org}/${repo}.git"

            log_info "Cloning: $repo"
            git clone "$repo_url" "${HOME}${target_dir}/${repo}" || exit 1
        fi

        install_dependencies "${HOME}${target_dir}" "$repo" || exit 1

        log_debug "Finished setup for $repo"
    ) &
    processIds+=($!)
done

# Wait for all parallel tasks to finish
for i in "${!processIds[@]}"; do
    pid="${processIds[$i]}"

    if ! wait "$pid"; then
        log_error "Repository setup process $i failed"
    fi
done

log_debug "All project installation processes are complete"

# Now handle symlinks serially (as they often require sudo and global paths)
# This ensures permissions and links are set up correctly
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
    sudo chgrp -R devgroup "$repo_path"

    # Set secure, consistent permissions
    # Directories: 2755 (rwxr-xr-x with SGID)
    # Files: 644 (rw-r--r--)
    log_debug "Setting secure permissions for $repo_path"

    if ! sudo find "$repo_path" -type d -exec chmod 2755 {} \; 2>/dev/null; then
        log_warn "Failed to set directory permissions for $repo"
    fi

    if ! sudo find "$repo_path" -type f -exec chmod 644 {} \; 2>/dev/null; then
        log_warn "Failed to set file permissions for $repo"
    fi


    # Set default ACLs for future files/dirs (only if ACL is supported)
    if command -v setfacl >/dev/null 2>&1; then
        log_debug "Setting default ACLs for $repo_path"
        if ! sudo setfacl -d -m u::rwX "$repo_path" 2>/dev/null; then
            log_warn "Failed to set user ACL for $repo"
        fi
        if ! sudo setfacl -d -m g::rX "$repo_path" 2>/dev/null; then
            log_warn "Failed to set group ACL for $repo"
        fi
        if ! sudo setfacl -d -m o::0 "$repo_path" 2>/dev/null; then
            log_warn "Failed to set other ACL for $repo"
        fi
    else
        log_debug "ACL not available, skipping ACL configuration"
    fi

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
