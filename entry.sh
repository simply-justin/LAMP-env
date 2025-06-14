#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

#-------------------------------------------------------#
#   Environment Setup Script                            #
#   This script manages the setup and configuration     #
#   of your development environment.                    #
#-------------------------------------------------------#

#-------------------------------------------------------#
#   Usage                                               #
#   Parse args (token + optional --exclude/--only)      #
#-------------------------------------------------------#
usage() {
cat <<EOF
    Usage: $0 [--exclude a,b] [--only x,y] [githubToken]
    
    This script sets up your development environment by:
    1. Bootstrapping required dependencies
    2. Running environment setup scripts
    3. Configuring development tools
    
    Positional:
        githubToken         Your Github token for repository access

    Options:
        --exclude LIST      Comma-separated list of script names (without .sh) to skip
        --only LIST         Comma-separated list of script names to run (mutually exclusive)
        
    Examples:
        $0 your_github_token
        $0 your_github_token --exclude docker,node
        $0 your_github_token --only git,php
EOF
exit 1
}

# Parse command line arguments
EXCLUDE=()
ONLY=()
GITHUB_TOKEN=""

while (( $# )); do
    case $1 in
        --exclude)
        [[ -z "${2-}" ]] && echo "Error: --exclude needs a value" >&2 && usage
        IFS=, read -r -a EXCLUDE <<< "$2"
        shift 2
        ;;
        --only)
        [[ -z "${2-}" ]] && echo "Error: --only needs a value" >&2 && usage
        IFS=, read -r -a ONLY <<< "$2"
        shift 2
        ;;
        -help|-h)
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

# Validate arguments
[[ -z "$GITHUB_TOKEN" ]] && echo "Error: Github token is required" >&2 && usage
if (( ${#EXCLUDE[@]} > 0 && ${#ONLY[@]} > 0 )); then
    echo "Error: --exclude and --only cannot be used together" >&2
    exit 1
fi

#-------------------------------------------------------#
#   Environment Setup                                   #
#-------------------------------------------------------#

# Set up environment variables
HOME="$(pwd)"
ENV_DIR="$HOME/.env"
SCRIPT_DIR="$HOME/.env/scripts"
CONFIG_DIR="$HOME/.env/configs"

export HOME
export ENV_DIR
export SCRIPT_DIR
export CONFIG_DIR

export GITHUB_TOKEN

# Require root privileges
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root."
    exit 1
fi

# Source helper functions
source "$SCRIPT_DIR/env/helpers.sh"

# Execute environment setup scripts
for script_path in "$SCRIPT_DIR"/env/[0-9][0-9]-*.sh; do
    script_file=$(basename "$script_path")
    name="${script_file#??-}"
    name="${name%.sh}"

    [[ "$name" == "helpers" ]] && continue

    if (( ${#ONLY[@]} )); then
        [[ ! " ${ONLY[*]} " =~ " ${name} " ]] && continue
    elif (( ${#EXCLUDE[@]} )); then
        [[ " ${EXCLUDE[*]} " =~ " ${name} " ]] && continue
    fi

    log_info "Running $script_file"
    if ! bash "$script_path"; then
        log_error "Script $script_file failed"
        exit 1
    fi
done

log_info "Environment setup completed successfully!"