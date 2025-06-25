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
#   source "${SCRIPT_DIR}/helpers/include.sh"
#
# This script sources logs.sh and utils.sh for logging and utility functions.
#==============================================================================

set -euo pipefail
IFS=$'\n\t'

# Source required helper scripts
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/helpers/logs.sh"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/helpers/utils.sh"
