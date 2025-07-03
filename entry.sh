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

ROOT_DIR="$(pwd)"
ENV_DIR="$ROOT_DIR/LAMP-env"
SCRIPT_DIR="$ENV_DIR/scripts"
CONFIG_DIR="$ENV_DIR/configs"
MARIADB_ROOT_PASSWORD="root"

readonly ROOT_DIR ENV_DIR SCRIPT_DIR CONFIG_DIR MARIADB_ROOT_PASSWORD
export ROOT_DIR ENV_DIR SCRIPT_DIR CONFIG_DIR MARIADB_ROOT_PASSWORD

# Initialize variables that will be set later (do not export yet)
GITHUB_TOKEN=""
PACKAGE_MANAGER=""
PHP_VERSIONS=()
exclude=()
only=()

# Source helper functions
# shellcheck source=/dev/null
source "$SCRIPT_DIR/helpers/include.sh"

#-------------------------------------------------------#
# Usage Manual
#-------------------------------------------------------#
usage() {
    cat <<EOF
Usage: $0 [--exclude a,b] [--only c,d] [--php e,f] [--package-manager g] [--debug] [githubToken]

Options:
  githubToken              Your GitHub token (required)
  --exclude LIST           Comma-separated script names to exclude (without .sh)
  --only LIST              Comma-separated script names to include (mutually exclusive with --exclude)
  --php LIST               Comma-separated list of PHP versions to install
  --package-manager NAME   The package manager to use (default: node)
  --debug                  Enable debug logging
  -h, --help               Show this help and exit

Examples:
  $0 your_token
  $0 your_token --php 8.1,8.2 --package-manager pnpm
EOF
    exit 1
}

#-------------------------------------------------------#
# Parse arguments
#-------------------------------------------------------#
while (( $# )); do
    case "$1" in
        --exclude)
            [[ -z "${2-}" ]] && echo "Error: --exclude needs a value" >&2 && usage
            IFS=',' read -r -a exclude <<< "$2"
            shift 2
            ;;
        --only)
            [[ -z "${2-}" ]] && echo "Error: --only needs a value" >&2 && usage
            IFS=',' read -r -a only <<< "$2"
            shift 2
            ;;
        --php)
            [[ -z "${2-}" ]] && echo "Error: --php needs a value" >&2 && usage
            IFS=',' read -ra VERSIONS <<< "$2"
            PHP_VERSIONS+=("${VERSIONS[@]}")
            shift 2
            ;;
        --pm|--package-manager)
            [[ -z "${2-}" ]] && echo "Error: --package-manager needs a value" >&2 && usage
            PACKAGE_MANAGER="$2"
            shift 2
            ;;
        --d|--debug)
            export LOG_LEVEL=0
            echo "[DEBUG] Debug mode enabled"
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

#------------------------------------------------------------------------------
# Validate and Defaults
#------------------------------------------------------------------------------
if [[ -z "$GITHUB_TOKEN" ]]; then
    echo "Error: GitHub token is required." >&2
    usage
fi

if (( ${#exclude[@]} > 0 && ${#only[@]} > 0 )); then
    echo "Error: --exclude and --only cannot be used together." >&2
    exit 1
fi

if [[ ${#PHP_VERSIONS[@]} -eq 0 ]]; then
    PHP_VERSIONS=(8.3)
fi

PHP_VERSIONS_STR="$(IFS=','; echo "${PHP_VERSIONS[*]}")"

export GITHUB_TOKEN PACKAGE_MANAGER PHP_VERSIONS_STR
readonly GITHUB_TOKEN PACKAGE_MANAGER

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
