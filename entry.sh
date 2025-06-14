#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

#-------------------------------------------------------#
#   Environment Setup Script                            #
#   This script manages the setup and configuration     #
#   of your development environment.                    #
#-------------------------------------------------------#

# Require root privileges
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root."
    exit 1
fi

HOME="$(pwd)"

export HOME
export ENV_DIR="$HOME/LAMP-env"
export SCRIPT_DIR="$HOME/LAMP-env/scripts"
export CONFIG_DIR="$HOME/LAMP-env/configs"
export CURRENT_USER="${SUDO_USER:-$(whoami)}"

export COMPOSER_ALLOW_SUPERUSER=1

readonly HOME ENV_DIR SCRIPT_DIR CONFIG_DIR CURRENT_USER

# Source helper functions
source "$SCRIPT_DIR/helpers.sh"

#-------------------------------------------------------#
#   Usage Manual                                        #
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
exclude=()
only=()
github_token=""

while (( $# )); do
    case $1 in
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
        -h|--help)
            usage
            ;;
        -*)
            echo "Unknown option: $1" >&2
            usage
            ;;
        *)
            if [[ -z "$github_token" ]]; then
                github_token="$1"
                shift
            else
                echo "Unexpected argument: $1" >&2
                usage
            fi
            ;;
    esac
done

# Validate arguments
if [[ -z "$github_token" ]]; then
    log_error "GitHub token is required" >&2
    usage
fi

if (( ${#exclude[@]} > 0 && ${#only[@]} > 0 )); then
    log_error "--exclude and --only cannot be used together" >&2
    exit 1
fi

#-------------------------------------------------------#
#   Execute environment setup scripts                   #
#-------------------------------------------------------#
export github_token

for script_path in "$SCRIPT_DIR"/[0-9][0-9]-*.sh; do
    script_file=$(basename "$script_path")
    name="${script_file#??-}"
    name="${name%.sh}"

    [[ "$name" == "helpers" ]] && continue

    if (( ${#only[@]} > 0 )); then
        [[ " ${only[*]} " != *" $name "* ]] && continue
    elif (( ${#exclude[@]} > 0 )); then
        [[ " ${exclude[*]} " == *" $name "* ]] && continue
    fi

    log_section "$script_file"
    if ! bash "$script_path"; then
        log_error "Script $script_file failed"
        exit 1
    fi
done

log_info "Environment setup completed successfully!"