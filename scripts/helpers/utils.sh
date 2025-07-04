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
    if ! package_exists "$package"; then
        # If not found, install it
        log_info "Installing $package"
        sudo apt-get install -y "$package" || {
            log_error "Failed to install package: $package"
            return 1
        }
    fi

    return 0
}

# Check if an APT repository is already configured in the system
# Searches through /etc/apt/sources.list.d/ and /etc/apt/sources.list
# @param $1 Repository identifier to search for (e.g., "ppa:ondrej/php")
# @return 0 if repository exists, 1 otherwise
apt_repo_exists() {
    local repo="$1"
    local sources_dir="/etc/apt/sources.list.d"

    if [[ -z "$repo" ]]; then
        log_error "Repository identifier cannot be empty"
        return 1
    fi


    if [[ ! -d "$sources_dir" ]]; then
        log_debug "APT sources.list.d directory does not exist"
        return 1
    fi

    # Check in both .list and .sources files
    if grep -rFq "$repo" "$sources_dir" 2>/dev/null; then
        log_debug "APT repository found in sources.list.d: $repo"
        return 0
    fi

    # Check main sources.list
    if [[ -f "/etc/apt/sources.list" ]] && grep -Fq "$repo" /etc/apt/sources.list 2>/dev/null; then
        log_debug "APT repository found in main sources.list: $repo"
        return 0
    fi

    log_debug "APT repository not found: $repo"
    return 1
}


# Add an APT repository to the system if it doesn't already exist
# Handles both PPA and regular repository formats
# @param $1 Repository (e.g., "ppa:ondrej/php" or "deb http://...")
# @param $2 Optional: Force update even if repository exists (default: false)
# @return 0 on success, 1 on failure
add_apt_repo() {
    local repo="$1"
    local force_update="${2:-false}"

    if [[ -z "$repo" ]]; then
        log_error "Repository cannot be empty"
        return 1
    fi

    if ! command -v add-apt-repository &>/dev/null; then
        log_info "Installing add-apt-repository (via software-properties-common)"
        sudo apt-get update -y && sudo apt-get install -y software-properties-common || {
            log_error "Failed to install required tools"
            return 1
        }
    fi

    if [[ "$force_update" != "true" ]] && apt_repo_exists "$repo"; then
        log_debug "APT repository already exists: $repo"
        return 0
    fi

    log_info "Adding APT repository: $repo"
    if sudo add-apt-repository -y "$repo"; then
        log_debug "Repository added successfully, updating package lists"
        if sudo apt-get update -y; then
            log_info "Repository added and package lists updated"
            return 0
        else
            log_warn "Repository added, but package list update failed"
            return 1
        fi
    else
        log_error "Failed to add APT repository: $repo"
        return 1
    fi
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
# Actions
#==============================================================================

# Enable and start a service
# @param $1 Service name
# @return 0 on success, 1 on failure
enable_service() {
    local service="$1"
    if ! sudo systemctl is-enabled "$service" &>/dev/null; then
        log_debug "Enabling $service"
        sudo systemctl enable "$service" || { log_error "Failed to enable $service"; exit 1; }
    fi
    if ! sudo systemctl is-active "$service" &>/dev/null; then
        log_debug "Starting $service"
        sudo systemctl start "$service" || { log_error "Failed to start $service"; exit 1; }
    fi
}

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

    log_debug "Ensure correct line endings in files"
    git config --local --unset core.fileMode

    # Install PHP dependencies if composer.json exists and vendor directory does not exist
    if file_exists "composer.json" && ! directory_exists "vendor"; then
        log_info "Installing PHP dependencies for $repo"
        composer install --no-interaction --ignore-platform-reqs || {
            log_error "Failed to install PHP dependencies for $repo"
            return 1
        }
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

    # Check for node_modules directory and presence of 'next' in dependencies
    if directory_exists "node_modules" && jq -e '.dependencies.next // .devDependencies.next' package.json > /dev/null; then
        log_debug "Building Next.js project for $repo"
        if ! npm run build; then
            log_error "Failed to build Next.js project for $repo"
            return 1
        fi
    fi

    # Check if .env.example exists and create .env if it doesn't
    if file_exists ".env.example" && ! file_exists ".env"; then
        log_info "Creating .env file from .env.example"
        cp ".env.example" ".env" || {
            log_error "Failed to create .env file"
            return 1
        }
    fi

    return 0
}