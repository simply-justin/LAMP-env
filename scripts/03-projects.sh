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
readonly PROJECTS_DIR="${ROOT_DIR}/projects"
readonly DEVGROUP="devgroup"

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
if ! getent group "$DEVGROUP" > /dev/null; then
    log_info "Creating $DEVGROUP"
    sudo groupadd "$DEVGROUP"
fi

sudo usermod -aG "$DEVGROUP" www-data
sudo usermod -aG "$DEVGROUP" "$USER"

#-------------------------------------------------------#
# Project Setup
#-------------------------------------------------------#
# Count repositories in configuration
repo_count=$(jq '. | length' "$REPO_FILE")
[ "$repo_count" -eq 0 ] && { log_warn "No repositories configured"; exit 0; }

# Create development directory
ensure_directory "$PROJECTS_DIR" || exit 1

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
        [ -z "$org" ] || [ -z "$repo" ] || [ -z "$target_dir" ] && { log_error "Invalid configuration for repository $i"; exit 1; }

        full_repo_path="${ROOT_DIR}${target_dir}/${repo}"
        repo_url="https://${GITHUB_TOKEN}@github.com/${org}/${repo}.git"
        if ! directory_exists "$full_repo_path"; then
            log_info "Cloning: $repo"
            git clone "$repo_url" "$full_repo_path" || exit 1
        fi

        install_dependencies "${ROOT_DIR}${target_dir}" "$repo" || exit 1

        log_debug "Finished setup for $repo"
    ) &
    processIds+=($!)
    sleep 0.1  # avoid overloading system
    continue
done

# Wait for all parallel tasks to finish
for pid in "${processIds[@]}"; do
    wait "$pid" || log_error "One of the repository setups failed"
done

#-------------------------------------------------------#
# Symlink Creation and Permission Setup
#-------------------------------------------------------#
log_info "Setting symbolic links and permissions"

# Change group ownership recursively
sudo chgrp "$DEVGROUP" "$ROOT_DIR"
sudo chmod 2755 "$ROOT_DIR"
sudo chgrp -R "$DEVGROUP" "$PROJECTS_DIR"

for i in $(seq 0 $((repo_count - 1))); do
    org=$(jq -r ".[$i].org" "$REPO_FILE")
    repo=$(jq -r ".[$i].repo" "$REPO_FILE")
    target_dir=$(jq -r ".[$i].target_dir" "$REPO_FILE")

    [ -z "$org" ] || [ -z "$repo" ] || [ -z "$target_dir" ] && continue

    # Full path to the repo directory
    repo_path="${ROOT_DIR}${target_dir}/${repo}"
    symlink_path="/var/www/$repo"

    [ -d "$repo_path" ] || { log_error "Missing path: $repo_path"; continue; }

    [ -L "$symlink_path" ] && sudo unlink "$symlink_path"
    sudo ln -s "$repo_path" "$symlink_path"

    log_debug "Setting secure permissions for $repo_path"

    sudo chgrp -R "$DEVGROUP" "$repo_path"

    writable_files=$(sudo find "$repo_path" -type f -perm /200)
    writable_dirs=$(sudo find "$repo_path" -type d -perm /200)

    sudo find "$repo_path" -type d -exec chmod 2755 {} \;
    sudo find "$repo_path" -type f -exec chmod 644 {} \;
    sudo find "$repo_path" -type f -perm /111 -exec chmod 755 {} \;

    echo "$writable_files" | while read -r file; do
        sudo chmod g+w "$file" 2>/dev/null || true
    done

    echo "$writable_dirs" | while read -r dir; do
        sudo chmod g+w "$dir" 2>/dev/null || true
    done

    if command -v setfacl >/dev/null; then
        sudo setfacl -d -m u::rwX "$repo_path"
        sudo setfacl -d -m g::rX "$repo_path"
        sudo setfacl -d -m o::0 "$repo_path"
    fi

    log_info "Configured: $org/$repo"
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
