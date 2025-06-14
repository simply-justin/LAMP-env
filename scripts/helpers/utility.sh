#!/usr/bin/env bash

#==============================================================================
# Utility Functions for Bash Scripts
#==============================================================================
# This script provides common utility functions for bash scripts including:
# - Command existence checks
# - File and directory operations
# - Backup functionality
#
# Usage:
#   source "${SCRIPT_DIR}/helpers/utility.sh"
#
# Dependencies:
#   - logging.sh (for log_* functions)
#==============================================================================

set -euo pipefail
IFS=$'\n\t'

#==============================================================================
# Command and Path Checks
#==============================================================================

# Check if a command exists in the system PATH
# @param $1 Command name to check
# @return 0 if command exists, 1 otherwise
command_exists() {
    command -v "$1" &>/dev/null
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
# Directory Operations
#==============================================================================

# Create a directory if it doesn't exist
# @param $1 Directory path to create
# @return 0 on success, 1 on failure
ensure_directory() {
    local dir="$1"
    if ! directory_exists "$dir"; then
        log_debug "Creating directory: $dir"
        mkdir -p "$dir" || {
            log_error "Failed to create directory: $dir"
            return 1
        }
    fi
}

#==============================================================================
# File Operations
#==============================================================================

# Create a backup of a file with timestamp
# @param $1 File path to backup
# @param $2 Backup directory (optional, defaults to ./backups)
# @return 0 on success, 1 on failure
backup_file() {
    local file="$1"
    local backup_dir="${2:-./backups}"
    
    if ! file_exists "$file"; then
        log_error "File to backup does not exist: $file"
        return 1
    fi
    
    ensure_directory "$backup_dir" || return 1
    
    local timestamp
    timestamp=$(date '+%Y%m%d_%H%M%S')
    local backup_file="$backup_dir/$(basename "$file").$timestamp.bak"
    
    if cp "$file" "$backup_file"; then
        log_success "Created backup: $backup_file"
        return 0
    else
        log_failure "Failed to create backup of $file"
        return 1
    fi
}