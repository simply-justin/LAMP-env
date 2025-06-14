#!/usr/bin/env bash

#==============================================================================
# Logging Functions for Bash Scripts
#==============================================================================
# This script provides logging functionality for bash scripts including:
# - Multiple log levels (DEBUG, INFO, WARN, ERROR)
# - Colored output
# - Timestamp and script name in log messages
# - Command execution logging
# - Progress tracking
# - Section headers with progress bars
#==============================================================================

set -euo pipefail
IFS=$'\n\t'

# Log levels (higher number = more important)
readonly LOG_LEVEL_DEBUG=0
readonly LOG_LEVEL_INFO=1
readonly LOG_LEVEL_WARN=2
readonly LOG_LEVEL_ERROR=3

# Default log level if not set
LOG_LEVEL=${LOG_LEVEL:-$LOG_LEVEL_INFO}

# ANSI color codes for different log levels
readonly COLOR_RESET="\033[0m"
readonly COLOR_DEBUG="\033[1;37m"       # Light Gray
readonly COLOR_INFO="\033[1;36m"        # Cyan
readonly COLOR_WARN="\033[1;33m"        # Yellow
readonly COLOR_ERROR="\033[1;31m"       # Red
readonly COLOR_SECTION="\033[1;90m"     # Gray

#==============================================================================
# Logging Core Functions
#==============================================================================

# Log message if level is sufficient
# @param $1 Log level name
# @param $2 Color code
# @param $3 Message to log
# @param $4 Numeric log level
log() {
    local level="$1"
    local color="$2"
    local message="$3"
    local level_value="$4"

    if [ "$LOG_LEVEL" -le "$level_value" ]; then
        echo -e "${color}[${level}] ${COLOR_RESET}[$(get_timestamp)] ${message}${COLOR_RESET}"
    fi
}

# Create a section header with full-width line
# @param $1 Section title
log_section() {
    local title="$1"
    local width
    width=$(get_terminal_width)
    local title_length=${#title}
    local padding=$(( (width - title_length - 2) / 2 ))
    local line=""

    # Create the line of = characters
    for ((i=0; i<width; i++)); do
        line+="="
    done

    # Print the section header
    echo
    echo -e "${COLOR_SECTION}${line}${COLOR_RESET}"
    printf "%${padding}s${COLOR_SECTION}%s${COLOR_RESET}%${padding}s\n" "" "$title" ""
    echo -e "${COLOR_SECTION}${line}${COLOR_RESET}"
    echo
}

#------------------------------------------------------------------------------
# Log Level Functions
#------------------------------------------------------------------------------

# Log a debug message (most verbose)
# @param $1 Message to log
log_debug() {
    log "DEBUG" "$COLOR_DEBUG" "$1" "$LOG_LEVEL_DEBUG"
}

# Log an informational message
# @param $1 Message to log
log_info() {
    log "INFO" "$COLOR_INFO" "$1" "$LOG_LEVEL_INFO"
}

# Log a warning message
# @param $1 Message to log
log_warn() {
    log "WARN" "$COLOR_WARN" "$1" "$LOG_LEVEL_WARN"
}

# Log an error message
# @param $1 Message to log
log_error() {
    log "ERROR" "$COLOR_ERROR" "$1" "$LOG_LEVEL_ERROR" >&2
}

#------------------------------------------------------------------------------
# Log Helpers
#------------------------------------------------------------------------------

# Get current timestamp in a consistent format
# @return Timestamp string in format YYYY-MM-DD HH:MM:SS
get_timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

# Get terminal width
# @return Terminal width or default if not available
get_terminal_width() {
    local width
    width=$(tput cols 2>/dev/null) || width=80
    echo "$width"
}
