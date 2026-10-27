#! /usr/bin/env bash
# Fail fast before pnpm install when a GitHub App installation token would be used
# for GitHub Packages, or when app credentials are present without a packages-read token.
# Installation tokens (ghs_…) are for git/GitHub API; private package downloads need a
# separate packages-read credential (GITHUB_PACKAGES_READ_TOKEN preferred;
# GITHUB_PACKAGES_TOKEN deprecated alias; or a non-ghs GITHUB_TOKEN legacy fallback).
set -euo pipefail

packages_token="${GITHUB_PACKAGES_READ_TOKEN:-${GITHUB_PACKAGES_TOKEN:-}}"
github_token="${GITHUB_TOKEN:-}"

packages_read_message() {
  echo "assertGithubPackagesTokenForInstall: a packages-read token is required for pnpm install of private GitHub Packages." >&2
  echo "assertGithubPackagesTokenForInstall: provide GITHUB_PACKAGES_READ_TOKEN from a github-packages-read context (preferred), or legacy GITHUB_PACKAGES_TOKEN / GITHUB_TOKEN." >&2
  echo "assertGithubPackagesTokenForInstall: GitHub App credentials (GITHUB_APP_ID / GITHUB_APP_PRIVATE_KEY / GITHUB_APP_INSTALLATION_ID) mint an installation token for git push and gh — they are not a packages-read credential." >&2
  echo "assertGithubPackagesTokenForInstall: prefer minting after install (job parameter mint-github-token: true) so install keeps the packages-read token." >&2
}

if [[ -n "$packages_token" ]]; then
  exit 0
fi

if [[ "$github_token" == ghs_* ]]; then
  echo "assertGithubPackagesTokenForInstall: GITHUB_TOKEN is a GitHub App installation token (ghs_…), which cannot download private packages owned by another org." >&2
  packages_read_message
  exit 1
fi

app_credentials_set=0
[[ -n "${GITHUB_APP_ID:-}" ]] && app_credentials_set=$((app_credentials_set + 1))
[[ -n "${GITHUB_APP_PRIVATE_KEY:-}" ]] && app_credentials_set=$((app_credentials_set + 1))
[[ -n "${GITHUB_APP_INSTALLATION_ID:-}" ]] && app_credentials_set=$((app_credentials_set + 1))

if [[ "$app_credentials_set" -eq 3 && -z "$github_token" ]]; then
  echo "assertGithubPackagesTokenForInstall: GitHub App credentials are set, but no packages-read GITHUB_PACKAGES_READ_TOKEN (or legacy GITHUB_PACKAGES_TOKEN / GITHUB_TOKEN) is available." >&2
  packages_read_message
  exit 1
fi
