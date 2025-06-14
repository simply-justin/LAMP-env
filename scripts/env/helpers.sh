#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

# Logging
#---------------------------------------------------#
log_info() { echo -e "\033[1;32m[INFO]\033[0m $1"; }
log_warn() { echo -e "\033[1;33m[WARN]\033[0m $1"; }
log_error() { echo -e "\033[1;31m[ERROR]\033[0m $1" >&2; }

# Install a command if missing
#---------------------------------------------------#
require_command() {
    if ! command -v "$1" &>/dev/null; then
        echo "Installing missing dependency: $1"
        sudo apt-get update -qq
        sudo apt-get install -y "$1"
    fi
}

clone_and_install() {
  local org="$1"
  local repo="$2"
  local target_dir="$3"

  local repo_url=""
  repo_url="https://${GITHUB_TOKEN}@github.com/${org}/${repo}.git"

  if [ -d "$target_dir/.git" ]; then
    log_warn "Repository '${repo}' already cloned at '${target_dir}'. Skipping clone."
  else
    log_info "Cloning $repo_url into $target_dir..."
    if ! git clone "$repo_url" "$target_dir"; then
      log_error "Failed to clone repository '${repo}'."
      return 1
    fi
  fi

  # Auto detect install commands
  if [ -f "$target_dir/composer.json" ]; then
    log_info "Detected composer.json, running composer install..."
    (cd "$target_dir" && composer install) || { log_error "composer install failed"; return 1; }
  else
    log_warn "No composer.json found, skipping install command."
  fi

  if [ -f "$target_dir/package.json" ]; then
    log_info "Detected package.json, running npm install..."
    (cd "$target_dir" && npm install) || { log_error "npm install failed"; return 1; }
  else
      log_warn "No package.json found, skipping install command."
  fi
  
  log_info "Done with $repo"
}