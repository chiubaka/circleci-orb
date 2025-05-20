#! /usr/bin/env bash
set -e

existing_node_version=$(node --version)

if [[ $existing_node_version == v$NODE_VERSION* ]]; then
  echo "Node $existing_node_version already installed. Skipping install of Node via Homebrew."
else
  echo "Installing Node via Homebrew."
  HOMEBREW_NO_AUTO_UPDATE=1 brew install node@"$NODE_VERSION"

  new_node_version=$(node --version)

  echo "Installed $new_node_version via Homebrew."
fi
