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
#
# Usage:
#   ./03-setup-projects.sh
#
# Dependencies:
#   - helpers.sh (for utility functions)
#   - jq (for JSON processing)
#   - Git
#   - Composer (for PHP projects)
#   - npm (for Node.js projects)
#
# Environment Variables:
#   - LOG_LEVEL: Set logging level (default: INFO)
#   - CONFIG_DIR: Path to configuration directory
#   - github_token: Optional GitHub token for authenticated access
#==============================================================================

set -euo pipefail
IFS=$'\n\t'

# Load shared helpers
source "${SCRIPT_DIR}/helpers.sh"

#==============================================================================
# Repository Management
#==============================================================================

# Clone a repository and install its dependencies
# @param $1 Organization name
# @param $2 Repository name
# @param $3 Target directory
# @return 0 on success, 1 on failure
clone_and_install() {
    local org="$1"
    local repo="$2"
    local target_dir="$3"

    if directory_exists "$target_dir/.git"; then
        log_warn "Repository already exists: $repo"
        return 0
    fi

    # Construct repository URL with optional authentication
    local repo_url="https://github.com/${org}/${repo}.git"
    if [ -n "${github_token:-}" ]; then
        repo_url="https://${github_token}@github.com/${org}/${repo}.git"
        log_debug "Using authenticated GitHub URL"
    fi

    log_info "Cloning: $repo"
    log_command "git clone $repo_url $target_dir" || {
        log_failure "Failed to clone: $repo"
        return 1
    }

    cd "$target_dir" || {
        log_error "Failed to change directory to: $target_dir"
        return 1
    }
    
    # Install PHP dependencies if composer.json exists
    if file_exists "composer.json"; then
        log_info "Installing PHP dependencies for $repo"
        log_command "composer install --no-interaction" || {
            log_failure "Failed to install PHP dependencies"
            return 1
        }
    fi

    # Install Node.js dependencies if package.json exists
    if file_exists "package.json"; then
        log_info "Installing Node.js dependencies for $repo"
        log_command "npm install --no-audit --no-fund" || {
            log_failure "Failed to install Node.js dependencies"
            return 1
        }
    fi
    
    log_success "Repository setup complete: $repo"
    return 0
}

#==============================================================================
# Configuration Validation
#==============================================================================
log_info "Configuration Validation"

readonly REPO_FILE="${CONFIG_DIR}/projects.json"

# Check for required tools
if ! command_exists jq; then
    log_failure "jq is required but not installed. Please install jq."
    exit 1
fi

# Validate repository configuration file
if ! file_exists "$REPO_FILE"; then
    log_failure "Repository configuration file not found: $REPO_FILE"
    exit 1
fi

# Validate JSON structure
if ! jq empty "$REPO_FILE" 2>/dev/null; then
    log_failure "Invalid JSON in repository configuration file"
    exit 1
fi

#==============================================================================
# Project Setup
#==============================================================================
log_info "Project Setup"

# Count repositories in configuration
repo_count=$(jq '. | length' "$REPO_FILE")
if [ "$repo_count" -eq 0 ]; then
    log_warn "No repositories configured in $REPO_FILE"
    exit 0
fi

log_info "Processing $repo_count repositories from configuration"

# Create development directory
DEV_DIR="${HOME}/dev"
if ! ensure_directory "$DEV_DIR"; then
    log_failure "Failed to create development directory: $DEV_DIR"
    exit 1
fi

# Process each repository
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

    log_info "Setting up repository: $org/$repo"
    
    # Clone and install repository
    if ! clone_and_install "$org" "$repo" "${HOME}${target_dir}/${repo}"; then
        log_error "Failed to setup repository: $org/$repo"
        continue
    fi

    # Create symbolic link
    symlink_path="/var/www/$repo"
    if [ -L "$symlink_path" ]; then
        log_info "Updating existing symbolic link: $symlink_path"
        sudo rm "$symlink_path"
    fi

    if ! sudo ln -s "${HOME}${target_dir}/${repo}" "$symlink_path"; then
        log_error "Failed to create symbolic link for $repo"
        continue
    fi

    if ! sudo chown -R www-data:www-data "$symlink_path"; then
        log_error "Failed to set permissions for $repo"
        continue
    fi

    log_info "Successfully configured repository: $org/$repo"
done

sudo chown -R 1000:1000 "/home/${CURRENT_USER}/.npm"

#==============================================================================
# PM2 Process Management
#==============================================================================
log_info "PM2 Process Management"

# Start the PM2 Processes
if ! pm2 start /etc/pm2/processes.config.js; then
    log_failure "Failed to start PM2 processes"
    exit 1
fi

# Configure PM2 to start on system boot
if ! pm2 save && pm2 startup; then
    log_failure "Failed to configure PM2 startup"
    exit 1
fi

log_success "Project setup completed successfully!"