#!/usr/bin/env bash

#==============================================================================
# Main Helper Functions for Bash Scripts
#==============================================================================
# This script provides core helper functions for bash scripts including:
# - Command installation
# - Repository management
# - Dependency handling
#
# Usage:
#   source "${SCRIPT_DIR}/helpers.sh"
#
# Dependencies:
#   - logging.sh
#   - utility.sh
#==============================================================================

set -euo pipefail
IFS=$'\n\t'

# Source required helper scripts
source "${SCRIPT_DIR}/helpers/logging.sh"
source "${SCRIPT_DIR}/helpers/utility.sh"

#==============================================================================
# Command Installation
#==============================================================================

# Ensure a command is installed on the system
# @param $1 Package name to install
# @return 0 on success, 1 on failure
require_command() {
    local package="$1"
    
    if command_exists "$package"; then
        log_info "Package already installed: $package"
        return 0
    fi
    
    log_info "Installing: $package"
    log_command "sudo apt-get update -qq && sudo apt-get install -y $package" || {
        log_failure "Failed to install package: $package"
        return 1
    }
}