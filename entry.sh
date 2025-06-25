#!/usr/bin/env bash

#==============================================================================
# Environment Setup Script
#==============================================================================
# This script manages the setup and configuration
# of your development environment.
#
# Expected Environment:
#   - Ubuntu/Debian-based Linux
#   - Bash shell
#   - Sudo privileges required for some operations
#   - Internet access for package installation
#==============================================================================

set -euo pipefail
IFS=$'\n\t'

HOME="$(pwd)"

export HOME
export ENV_DIR="$HOME/LAMP-env"
export SCRIPT_DIR="$HOME/LAMP-env/scripts"
export CONFIG_DIR="$HOME/LAMP-env/configs"

export GITHUB_TOKEN=""

readonly HOME ENV_DIR SCRIPT_DIR CONFIG_DIR

# Source helper functions
# shellcheck source=/dev/null
source "$SCRIPT_DIR/helpers/include.sh"

#-------------------------------------------------------#
# Usage Manual
#-------------------------------------------------------#
usage() {
cat <<EOF
    Usage: $0 [--exclude a,b] [--only x,y] [--php] [--debug] [githubToken]

    This script sets up your development environment by:
    1. Bootstrapping required dependencies
    2. Running environment setup scripts
    3. Configuring development tools

    Positional:
        githubToken         Your Github token for repository access

    Options:
        --exclude LIST      Comma-separated list of script names (without .sh) to skip
        --only LIST         Comma-separated list of script names to run (mutually exclusive)
        --php LIST          Comma-separated list of PHP versions to install
        --debug             Enables debug logging

    Examples:
        $0 your_github_token
        $0 your_github_token --exclude docker,node
        $0 your_github_token --only git,php
        $0 your_github_token --php 8.1,8.2
        $0 your_github_token --debug
EOF
exit 1
}

#-------------------------------------------------------#
# Parse arguments
#-------------------------------------------------------#
# This section parses command-line arguments and sets up
# script behavior based on user input. It supports exclusion,
# inclusion, PHP version selection, and debug mode.
PHP_VERSIONS=()
exclude=()
only=()

while (( $# )); do
    case $1 in
        --exclude)
            [[ -z "${2-}" ]] && echo "Error: --exclude needs a value" >&2 && usage
            # Parse comma-separated list into array
            IFS=',' read -r -a exclude <<< "$2"
            shift 2
            ;;
        --only)
            [[ -z "${2-}" ]] && echo "Error: --only needs a value" >&2 && usage
            # Parse comma-separated list into array
            IFS=',' read -r -a only <<< "$2"
            shift 2
            ;;
        --php)
            [[ -z "${2-}" ]] && echo "Error: --php needs a value" >&2 && usage
            # Parse comma-separated list into PHP_VERSIONS array
            IFS=',' read -ra VERSIONS <<< "$2"
            for version in "${VERSIONS[@]}"; do
                PHP_VERSIONS+=("$version")
            done
            shift 2
            ;;
        --d|--debug)
            # Enable debug logging
            export LOG_LEVEL=0
            shift
            ;;
        -h|--help)
            usage
            ;;
        -*)
            echo "Unknown option: $1" >&2
            usage
            ;;
        *)
            # First positional argument is the GitHub token
            if [[ -z "$GITHUB_TOKEN" ]]; then
                GITHUB_TOKEN="$1"
                shift
            else
                echo "Unexpected argument: $1" >&2
                usage
            fi
            ;;
    esac
done

# Validate arguments
# Ensure required arguments and mutual exclusivity
if [[ -z "$GITHUB_TOKEN" ]]; then
    log_error "GitHub token is required" >&2
    usage
fi

if (( ${#exclude[@]} > 0 && ${#only[@]} > 0 )); then
    log_error "--exclude and --only cannot be used together" >&2
    exit 1
fi

# After argument parsing and before running setup scripts, set default PHP version if none provided
if [ ${#PHP_VERSIONS[@]} -eq 0 ]; then
    PHP_VERSIONS=(8.3)
fi

export PHP_VERSIONS
export GITHUB_TOKEN

#-------------------------------------------------------#
# Execute environment setup scripts
#-------------------------------------------------------#
# This loop runs all numbered setup scripts in the scripts directory.
# It respects --exclude and --only options to control which scripts run.
for script_path in "$SCRIPT_DIR"/[0-9][0-9]-*.sh; do
    script_file=$(basename "$script_path")
    name="${script_file#??-}"
    name="${name%.sh}"

    # Skip scripts not in the --only list (if provided)
    if (( ${#only[@]} > 0 )); then
        [[ " ${only[*]} " != *" $name "* ]] && continue
    # Skip scripts in the --exclude list (if provided)
    elif (( ${#exclude[@]} > 0 )); then
        [[ " ${exclude[*]} " == *" $name "* ]] && continue
    fi

    log_section "$script_file"
    if ! bash "$script_path"; then
        log_error "Script $script_file failed"
        exit 1
    fi
done
