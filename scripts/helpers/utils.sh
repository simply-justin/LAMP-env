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

# Check if a package exists in the system PATH
# @param $1 package name to check
# @return 0 if package exists, 1 otherwise
package_exists() {
    if command -v "$1" &>/dev/null || dpkg -l | grep -q "^ii  $1 "; then
        log_debug "Package already installed: $1"
        return 0
    fi

    return 1
}

# Ensure a package is installed on the system
# @param $1 Package name to install
# @return 0 on success, 1 on failure
require_package() {
    local package="$1"

    # Check if the package already exists
    package_exists "$package" || return 0

    # If not found, install it
    log_info "Installing $package"
    sudo apt-get install -y "$package" || {
        log_error "Failed to install package: $package"
        return 1
    }
}

#==============================================================================
# Directory
#==============================================================================

# Check if a directory exists and is accessible
# @param $1 Directory path to check
# @return 0 if directory exists, 1 otherwise
directory_exists() {
    [ -d "$1" ]
}

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

# Check if a file exists and is accessible
# @param $1 File path to check
# @return 0 if file exists, 1 otherwise
file_exists() {
    [ -f "$1" ]
}

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

# Install dependencies for a repository
# @param $1 Target directory
# @param $2 Repository name
# @return 0 on success, 1 on failure
install_dependencies() {
    local target_dir="$1"
    local repo="$2"

    log_debug "Changing to the target directory: $target_dir/$repo"
    cd "$target_dir/$repo" || {
        log_error "Failed to change directory to: $target_dir/$repo"
        return 1
    }

    # Install PHP dependencies if composer.json exists and vendor directory does not exist
    if file_exists "composer.json" && ! directory_exists "vendor"; then
        log_info "Installing PHP dependencies for $repo"
        composer install --no-interaction --ignore-platform-reqs || {
            log_error "Failed to install PHP dependencies for $repo"
            return 1
        }
    fi

    # Check if Node.js dependencies are already installed
    if directory_exists "node_modules"; then
        log_info "Dependencies already installed for $repo"
        return 0
    fi

    # Detect and install Node.js dependencies using the appropriate package manager
    # Priority: pnpm > yarn > npm
    if file_exists "pnpm-lock.yaml"; then
        # Use pnpm if lockfile exists
        log_info "Installing Node.js dependencies for $repo using pnpm"
        pnpm install --frozen-lockfile || {
            log_error "Failed to install Node.js dependencies for $repo with pnpm"
            return 1
        }
    elif file_exists "yarn.lock"; then
        # Use yarn if lockfile exists
        log_info "Installing Node.js dependencies for $repo using yarn"
        yarn install --frozen-lockfile || {
            log_error "Failed to install Node.js dependencies for $repo with yarn"
            return 1
        }
    elif file_exists "package.json"; then
        # Default to npm if no pnpm or yarn lockfile is found
        log_info "Installing Node.js dependencies for $repo using npm"
        npm install --no-audit --no-fund || {
            log_error "Failed to install Node.js dependencies for $repo with npm"
            return 1
        }
    fi

    return 0
}