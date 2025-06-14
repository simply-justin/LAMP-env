#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

# Load shared helpers
source "${SCRIPT_DIR}/env/helpers.sh"

# Ensure NPM is initialized
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
nvm use node

REPO_FILE="${CONFIG_DIR}/repos.json"

if ! command -v jq >/dev/null 2>&1; then
  log_error "jq is required but not installed. Please install jq."
  exit 1
fi

if [ ! -f "$REPO_FILE" ]; then
  log_error "Repository list file '$REPO_FILE' not found!"
  exit 1
fi

repo_count=$(jq length "$REPO_FILE")
log_info "Processing $repo_count repositories from $REPO_FILE"

mkdir -p $HOME/../dev
for i in $(seq 0 $((repo_count - 1))); do
  org=$(jq -r ".[$i].org" "$REPO_FILE")
  repo=$(jq -r ".[$i].repo" "$REPO_FILE")
  target_dir=$(jq -r ".[$i].target_dir" "$REPO_FILE")

  log_info "Starting clone/install for $org/$repo..."
  if ! clone_and_install "$org" "$repo" "$target_dir"; then
    log_error "Failed to clone and install $org/$repo"
    exit 1
  fi

  sudo ln -s $HOME/../$target_dir /var/www/$repo
done

log_info "All repositories processed successfully."