#! /usr/bin/env bash
# Configures ~/.npmrc (or NPMRC_PATH) for npmjs and/or GitHub Packages per ADR 0034.
# Dual-registry: only the given scope (default @chiubaka) is mapped to GitHub Packages;
# the default registry remains registry.npmjs.org for public packages.
set -euo pipefail

registry_backend=${REGISTRY_BACKEND:-npmjs}
owner=${NPM_OWNER:-chiubaka}
npmrc_path=${NPMRC_PATH:-"$HOME/.npmrc"}

if [[ "${npmrc_path:0:1}" == '~' ]]; then
  npmrc_path="${npmrc_path/#\~/$HOME}"
fi

if [[ "${ALWAYS_AUTH:-}" == "true" ]] || [[ "${ALWAYS_AUTH:-}" == "1" ]]; then
  always_auth=true
elif [[ "${ALWAYS_AUTH:-}" == "false" ]] || [[ "${ALWAYS_AUTH:-}" == "0" ]]; then
  always_auth=false
else
  if [[ "$registry_backend" == "github-packages" ]]; then
    always_auth=true
  else
    always_auth=false
  fi
fi

case "$registry_backend" in
  npmjs)
    if [[ -n "${NPM_TOKEN:-}" ]]; then
      {
        echo "//registry.npmjs.org/:_authToken=${NPM_TOKEN}"
        if [[ "$always_auth" == "true" ]]; then
          echo "//registry.npmjs.org/:always-auth=true"
        fi
      } >>"$npmrc_path"
    else
      registry_access=${REGISTRY_ACCESS:-publish}
      access_lower=$(printf '%s' "$registry_access" | tr '[:upper:]' '[:lower:]')
      if [[ "$access_lower" == "read" ]]; then
        echo "setupNpmRegistryAuth: NPM_TOKEN unset; skipping npmjs auth lines (public registry install)." >&2
      else
        echo "setupNpmRegistryAuth: NPM_TOKEN must be set when registry-backend is npmjs (or use registry-access read for tokenless public installs)." >&2
        exit 1
      fi
    fi
    ;;
  github-packages)
    # Install (read): prefer GITHUB_PACKAGES_READ_TOKEN, then deprecated GITHUB_PACKAGES_TOKEN,
    # then legacy GITHUB_TOKEN. Publish: prefer write-capable GITHUB_PACKAGES_TOKEN / GITHUB_TOKEN
    # so a read-only GITHUB_PACKAGES_READ_TOKEN does not poison the npmrc used for publish.
    registry_access=${REGISTRY_ACCESS:-read}
    access_lower=$(printf '%s' "$registry_access" | tr '[:upper:]' '[:lower:]')
    if [[ "$access_lower" == "publish" ]]; then
      packages_token="${GITHUB_PACKAGES_TOKEN:-${GITHUB_TOKEN:-${GITHUB_PACKAGES_READ_TOKEN:-}}}"
    else
      packages_token="${GITHUB_PACKAGES_READ_TOKEN:-${GITHUB_PACKAGES_TOKEN:-${GITHUB_TOKEN:-}}}"
    fi
    if [[ -z "$packages_token" ]]; then
      echo "setupNpmRegistryAuth: GITHUB_PACKAGES_READ_TOKEN must be set when registry-backend is github-packages (GITHUB_PACKAGES_TOKEN and GITHUB_TOKEN remain legacy fallbacks)." >&2
      echo "Grant read:packages for install-only jobs; add write:packages (and repo scope as needed) for publishing." >&2
      echo "GitHub App installation tokens (ghs_…) are not a packages-read credential; mint after install or preserve the pre-mint token as GITHUB_PACKAGES_READ_TOKEN." >&2
      exit 1
    fi
    if [[ "$packages_token" == ghs_* && -z "${GITHUB_PACKAGES_READ_TOKEN:-}" && -z "${GITHUB_PACKAGES_TOKEN:-}" ]]; then
      echo "setupNpmRegistryAuth: GITHUB_TOKEN is a GitHub App installation token (ghs_…), which cannot download private packages owned by another org." >&2
      echo "Provide a packages-read token as GITHUB_PACKAGES_READ_TOKEN (e.g. github-packages-read context), or set GITHUB_PACKAGES_TOKEN / GITHUB_TOKEN as a legacy fallback. Prefer minting after install." >&2
      exit 1
    fi
    {
      echo "@${owner}:registry=https://npm.pkg.github.com"
      echo "//npm.pkg.github.com/:_authToken=${packages_token}"
      if [[ "$always_auth" == "true" ]]; then
        echo "//npm.pkg.github.com/:always-auth=true"
      fi
    } >>"$npmrc_path"
    ;;
  *)
    echo "setupNpmRegistryAuth: unknown REGISTRY_BACKEND: ${registry_backend}" >&2
    exit 1
    ;;
esac
