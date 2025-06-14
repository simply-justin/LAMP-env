#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

#-------------------------------------------------------#
#   Logging Functions                                   #
#   Provides colored output for different log levels    #
#-------------------------------------------------------#
log_info() { echo -e "\033[1;32m[INFO]\033[0m $1"; }
log_warn() { echo -e "\033[1;33m[WARN]\033[0m $1"; }
log_error() { echo -e "\033[1;31m[ERROR]\033[0m $1" >&2; }

#-------------------------------------------------------#
#   Command Installation                                #
#   Ensures required commands are available             #
#-------------------------------------------------------#
require_command() {
    local package="$1"
    
    # Check if package is already installed
    if dpkg -l "$package" &>/dev/null; then
        log_info "Package already installed: $package"
        return 0
    fi
    
    # Package not installed, try to install it
    log_info "Installing missing dependency: $package"
    sudo apt-get update -qq
    if sudo apt-get install -y "$package"; then
        return 0
    else
        log_error "Failed to install $package"
        return 1
    fi
}

#-------------------------------------------------------#
#   Repository Management                               #
#   Clones and sets up repositories with dependencies   #   
#-------------------------------------------------------#
clone_and_install() {
    local org="$1"
    local repo="$2"
    local target_dir="$3"

    # Construct repo URL based on whether GITHUB_TOKEN is set
    local repo_url
    if [ -n "${GITHUB_TOKEN:-}" ]; then
        repo_url="https://${GITHUB_TOKEN}@github.com/${org}/${repo}.git"
    else
        repo_url="https://github.com/${org}/${repo}.git"
        log_warn "GITHUB_TOKEN not set. Using public repository access."
    fi

    if [ -d "$target_dir/.git" ]; then
        log_warn "Repository '${repo}' already cloned at '${target_dir}'. Skipping clone."
    else
        log_info "Cloning $repo_url into $target_dir..."
        if ! git clone "$repo_url" "$target_dir"; then
            log_error "Failed to clone repository '${repo}'."
            return 1
        fi
    fi

    # Auto detect and run install commands
    if [ -f "$target_dir/composer.json" ]; then
        log_info "Detected composer.json, running composer install..."
        (cd "$target_dir" && composer install) || { log_error "composer install failed"; return 1; }
    fi

    if [ -f "$target_dir/package.json" ]; then
        log_info "Detected package.json, running npm install..."
        (cd "$target_dir" && npm install) || { log_error "npm install failed"; return 1; }
    fi
    
    log_info "Repository setup completed: $repo"
}