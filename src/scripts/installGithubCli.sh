#! /usr/bin/env bash
# Installs GitHub CLI (gh) when missing; no-op if already on PATH. For cimg/node and similar images.
# https://cli.github.com/install.sh was removed (404); use official packages per cli/cli docs.
set -euo pipefail

if command -v gh >/dev/null 2>&1; then
  gh --version
  exit 0
fi

maybe_sudo() {
  if command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    "$@"
  fi
}

echo "Installing GitHub CLI (gh)..."

if command -v apt-get >/dev/null 2>&1 && command -v dpkg >/dev/null 2>&1; then
  maybe_sudo mkdir -p -m 755 /etc/apt/keyrings
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg |
    maybe_sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null
  maybe_sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
  maybe_sudo mkdir -p -m 755 /etc/apt/sources.list.d
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" |
    maybe_sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
  maybe_sudo apt-get update -qq
  maybe_sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq gh
elif command -v apk >/dev/null 2>&1; then
  maybe_sudo apk add --no-cache github-cli
else
  echo "installGithubCli: no supported package manager (need Debian/Ubuntu apt or Alpine apk)." >&2
  echo "installGithubCli: see https://github.com/cli/cli/blob/trunk/docs/install_linux.md" >&2
  exit 1
fi

command -v gh >/dev/null 2>&1 || {
  echo "installGithubCli: gh not found after install; extend PATH or use an image with gh." >&2
  exit 1
}
gh --version
