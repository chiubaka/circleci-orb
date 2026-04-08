#! /usr/bin/env bash
# Installs GitHub CLI (gh) when missing; no-op if already on PATH. For cimg/node and similar images.
set -euo pipefail

if command -v gh >/dev/null 2>&1; then
  gh --version
  exit 0
fi

echo "Installing GitHub CLI (gh)..."
if command -v sudo >/dev/null 2>&1; then
  curl -fsSL https://cli.github.com/install.sh | sudo bash
else
  curl -fsSL https://cli.github.com/install.sh | bash
fi
command -v gh >/dev/null 2>&1 || {
  echo "installGithubCli: gh not found after install; extend PATH or use an image with gh." >&2
  exit 1
}
gh --version
