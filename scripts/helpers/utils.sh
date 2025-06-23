#!/usr/bin/env bash

#==============================================================================
# Utility Functions for Bash Scripts
#==============================================================================
# This script provides common utility functions for bash scripts including:
# - Command existence checks
# - File and directory operations
# - Backup functionality
#==============================================================================

set -euo pipefail
IFS=$'\n\t'

#==============================================================================
# Command and Path
#==============================================================================

# Check if a command exists in the system PATH
# @param $1 Command name to check
# @return 0 if command exists, 1 otherwise
command_exists() {
    command -v "$1" &>/dev/null
}

# Ensure a command is installed on the system
# @param $1 Package name to install
# @return 0 on success, 1 on failure
require_command() {
    local package="$1"

    # First, check if the command is in PATH
    if command_exists "$package"; then
        log_debug "Package already installed: $package"
        return 0
    fi

    # If not, check if it's installed via dpkg (APT)
    if dpkg -l | grep -q "^ii  $package "; then
        log_debug "Package already installed: $package"
        return 0
    fi

    # If not found, install it
    sudo apt-get install -y "$package" || {
        log_error "Failed to install package: $package"
        return 1
    }
}

# Check if a directory exists and is accessible
# @param $1 Directory path to check
# @return 0 if directory exists, 1 otherwise
directory_exists() {
    [ -d "$1" ]
}

# Check if a file exists and is accessible
# @param $1 File path to check
# @return 0 if file exists, 1 otherwise
file_exists() {
    [ -f "$1" ]
}

#==============================================================================
# Directory
#==============================================================================

# Create a directory if it doesn't exist
# @param $1 Directory path to create
# @return 0 on success, 1 on failure
ensure_directory() {
    local dir="$1"
    if ! directory_exists "$dir"; then
        log_info "Creating directory: $dir"
        if ! mkdir -p "$dir" ; then
            log_debug "Not enough permissions to create dir, trying with root"
            sudo mkdir -p "$dir" || {
                log_error "Failed to create directory: $dir"
                return 1
            }
        fi
    fi
}

#==============================================================================
# File
#==============================================================================

# Create a backup of a file with timestamp
# @param $1 File path to backup
# @param $2 Backup directory (optional, defaults to ./backups)
# @return 0 on success, 1 on failure
backup_file() {
    local file="$1"
    local backup_dir="${2:-./backups}"

    log_debug "Checking if the target file exists"
    if ! file_exists "$file"; then
        log_error "File to backup does not exist: $file"
        return 1
    fi

    ensure_directory "$backup_dir" || return 1

    local timestamp
    local backup_file
    timestamp=$(date '+%Y%m%d_%H%M%S')
    backup_file="$backup_dir/$(basename "$file").$timestamp.bak"

    if cp "$file" "$backup_file"; then
        log_debug "Created backup: $backup_file"
        return 0
    else
        log_error "Failed to create backup of $file"
        return 1
    fi
}

#==============================================================================
# Github Repository
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

    if ! directory_exists "$target_dir/.git"; then
        # Construct repository URL with optional authentication
        local repo_url="https://github.com/${org}/${repo}.git"
        if [ -n "${GITHUB_TOKEN:-}" ]; then
            repo_url="https://${GITHUB_TOKEN}@github.com/${org}/${repo}.git"
            log_debug "Using authenticated GitHub URL"
        fi

        log_info "Cloning: $repo"
        git clone "$repo_url" "$target_dir" || {
            log_error "Failed to clone: $repo"
            return 1
        }
    fi

    log_debug "Changing to the target directory: $target_dir"
    cd "$target_dir" || {
        log_error "Failed to change directory to: $target_dir"
        return 1
    }

    # Install PHP dependencies if composer.json exists and composer.lock does not
    if file_exists "composer.json" && ! file_exists "composer.lock"; then
        log_info "Installing PHP dependencies for $repo"
        composer install --no-interaction || {
            log_error "Failed to install PHP dependencies for $repo"
            return 1
        }
    fi

    export CI=true
    # Install Node.js dependencies if package.json exists and package-lock.json does not
    if file_exists "package.json" && ! file_exists "package-lock.json"; then
        log_info "Installing Node.js dependencies for $repo"
        npm install --no-audit --no-fund --yes --loglevel=error || {
            log_error "Failed to install Node.js dependencies for $repo"
            return 1
        }
    fi

    return 0
}
