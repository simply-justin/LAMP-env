#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

#---------------------------------------------------#
#   Usage                                           #
#   Parse args (token + optional --exclude/--only)  #
#---------------------------------------------------#
usage() {
cat <<EOF
    Usage: $0 [--exclude a,b] [--only x,y] [githubToken]
    Positional:
        githubToken         Your Github token

    Options:
        --exclude LIST      Comma-seperated list of script names (without .sh) to skip
        --only LIST         Comma-seperated list of script names to run (mutally exclusive)
EOF
exit 1
}

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

[[ -z "$GITHUB_TOKEN" ]] && echo "Error: Github token is required" >&2 && usage
if (( ${#EXCLUDE[@]} > 0 && ${#ONLY[@]} > 0 )); then
    echo "Error: --exclude and --only cannot be used together" >&2
    exit 1
fi

#---------------------------------------------------#
#   Main                                            #
#---------------------------------------------------#

export GITHUB_TOKEN

HOME="$(pwd)"
ENV_DIR="$HOME/.env"
SCRIPT_DIR="$HOME/.env/scripts"
CONFIG_DIR="$HOME/.env/configs"

export HOME
export ENV_DIR
export SCRIPT_DIR
export CONFIG_DIR

# Require root privileges
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root."
  exit 1
fi

# Execute scripts
for script_path in "$SCRIPT_DIR"/env/[0-9][0-9]-*.sh; do
    script_file=$(basename "$script_path")
    name="${script_file#??-}"
    name="${name%.sh}"

    [[ "$name" == "helpers" ]] && continue

    if (( ${#ONLY[@]} )); then
        [[ ! " ${ONLY[*]} " =~ " ${name} " ]] && continue
    elif (( ${#EXCLUDE[@]} )); then
        [[ ! " ${EXCLUDE[*]} " =~ " ${name} " ]] && continue
    fi

    echo "-> Running $script_file"
    bash "$script_path" "$GITHUB_TOKEN"
done