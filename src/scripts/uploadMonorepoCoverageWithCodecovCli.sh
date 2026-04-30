#! /usr/bin/env bash
# Install and run the Codecov CLI the same way as codecov/codecov: binary from cli.codecov.io
# (see https://github.com/codecov/wrapper scripts/download.sh and validate.sh), not via pip.
set -euo pipefail

# Keep parity with Codecov orb behavior for Node-based environments.
unset NODE_OPTIONS

monorepo_root=${MONOREPO_ROOT:-$(pwd)}
cd "$monorepo_root" || {
  echo "ERROR: MONOREPO_ROOT is not a directory: $monorepo_root" >&2
  exit 1
}
monorepo_root=$(pwd)

coverage_root=${COVERAGE_DIR:?COVERAGE_DIR is required}
pnpm_bin=${PNPM_BINARY:-pnpm}
curl_retry=(--retry 5 --retry-delay 2)

codecov_detect_os() {
  if [[ -n "${CODECOV_OS:-}" ]]; then
    printf '%s' "$CODECOV_OS"
    return
  fi
  # Same OS labels as https://github.com/codecov/wrapper/blob/main/scripts/download.sh
  local family os_id arch
  family=$(uname -s | tr '[:upper:]' '[:lower:]')
  arch=$(arch 2>/dev/null || uname -m)
  if [[ $family == "darwin" ]]; then
    printf '%s' "macos"
    return
  fi
  if [[ $family != "linux" ]]; then
    printf '%s' "linux"
    return
  fi
  if [[ -r /etc/os-release ]]; then
    os_id=$(grep -E '^ID=' /etc/os-release | cut -c4-)
    if [[ $os_id == "alpine" ]]; then
      if [[ $arch == "aarch64" ]]; then
        printf '%s' "alpine-arm64"
      else
        printf '%s' "alpine"
      fi
      return
    fi
  fi
  if [[ $arch == "aarch64" ]]; then
    printf '%s' "linux-arm64"
  else
    printf '%s' "linux"
  fi
}

codecov_validate_cli() {
  # Mirrors https://github.com/codecov/wrapper/blob/main/scripts/validate.sh
  local install_dir="$1"
  local filename="$2"

  if [[ "${CODECOV_SKIP_VALIDATION:-false}" == "true" ]] || [[ "${CODECOV_SKIP_VALIDATION:-0}" == "1" ]]; then
    echo "(Codecov) Skipping CLI integrity validation" >&2
    chmod +x "$install_dir/$filename"
    return
  fi

  if ! command -v gpg >/dev/null 2>&1; then
    echo "ERROR: gpg is not installed. Install gnupg (e.g. apt install gnupg) or set CODECOV_SKIP_VALIDATION=true" >&2
    return 1
  fi

  if ! (
    cd "$install_dir" || exit 1
    curl -s https://keybase.io/codecovsecurity/pgp_keys.asc | gpg --no-default-keyring --import
    local base sha_url
    base="${CODECOV_CLI_URL:-https://cli.codecov.io}"
    base="${base}/${CODECOV_VERSION:-latest}/${CODECOV_OS?}"
    sha_url="${base}/${filename}.SHA256SUM"
    curl -fsS "${curl_retry[@]}" --connect-timeout 2 -O "$sha_url"
    curl -fsS "${curl_retry[@]}" --connect-timeout 2 -O "${sha_url}.sig"
    if ! gpg --verify "${filename}.SHA256SUM.sig" "${filename}.SHA256SUM"; then
      echo "ERROR: could not verify GPG signature of Codecov CLI checksum" >&2
      exit 1
    fi
    if ! (shasum -a 256 -c "${filename}.SHA256SUM" >/dev/null 2>&1 || sha256sum -c "${filename}.SHA256SUM" >/dev/null 2>&1); then
      echo "ERROR: could not verify SHA256 of Codecov CLI" >&2
      exit 1
    fi
    chmod +x "$filename"
  ); then
    return 1
  fi
  echo "Codecov CLI integrity verified" >&2
}

download_codecov_cli() {
  if ! command -v curl >/dev/null 2>&1; then
    echo "ERROR: curl is not installed. The Codecov CLI is downloaded with curl; install curl or set CODECOV_BINARY to a preinstalled codecov binary path." >&2
    return 1
  fi

  local install_dir base_url download_url
  local codecov_filename=codecov

  export CODECOV_VERSION="${CODECOV_VERSION:-latest}"
  CODECOV_OS=$(codecov_detect_os)
  export CODECOV_OS
  install_dir=$(mktemp -d)
  base_url="${CODECOV_CLI_URL:-https://cli.codecov.io}"
  base_url="${base_url}/${CODECOV_VERSION}/${CODECOV_OS}"
  download_url="${base_url}/${codecov_filename}"

  echo "Downloading Codecov CLI from $download_url" >&2
  if ! curl -fsSL "${curl_retry[@]}" "$download_url" -o "$install_dir/${codecov_filename}"; then
    echo "ERROR: failed to download Codecov CLI from $download_url" >&2
    rm -rf "$install_dir"
    return 1
  fi

  if ! codecov_validate_cli "$install_dir" "$codecov_filename"; then
    rm -rf "$install_dir"
    return 1
  fi

  printf '%s' "$install_dir/${codecov_filename}"
}

resolve_codecov_command() {
  # Preinstalled path: CODECOV_BINARY (same as codecov/codecov)
  if [[ -n "${CODECOV_BINARY:-}" ]] && [[ -f "$CODECOV_BINARY" ]]; then
    if [[ -x "$CODECOV_BINARY" ]]; then
      printf '%s' "$CODECOV_BINARY"
      return
    fi
    echo "ERROR: CODECOV_BINARY is not an executable file: $CODECOV_BINARY" >&2
    return 1
  fi
  # PATH: official download installs as "codecov"; PyPI has "codecovcli"
  local n=${CODECOV_BINARY:-}
  if [[ -z "$n" ]]; then
    if command -v codecov >/dev/null 2>&1; then
      command -v codecov
      return
    fi
    if command -v codecovcli >/dev/null 2>&1; then
      command -v codecovcli
      return
    fi
  elif command -v "$n" >/dev/null 2>&1; then
    command -v "$n"
    return
  fi
  download_codecov_cli
}

if ! codecov_cmd=$(resolve_codecov_command); then
  exit 1
fi

if [[ "${CODECOV_FAIL_ON_ERROR:-true}" == "true" ]] || [[ "${CODECOV_FAIL_ON_ERROR:-1}" == "1" ]]; then
  fail_on_error=true
else
  fail_on_error=false
fi

common_args=()
if [[ "$fail_on_error" == "true" ]]; then
  common_args+=(--fail-on-error)
fi
if [[ "${CODECOV_VERBOSE:-true}" == "true" ]] || [[ "${CODECOV_VERBOSE:-1}" == "1" ]]; then
  common_args+=(--verbose)
fi
if [[ "${CODECOV_DISABLE_SEARCH:-false}" == "true" ]] || [[ "${CODECOV_DISABLE_SEARCH:-0}" == "1" ]]; then
  common_args+=(--disable-search)
fi
if [[ -n "${CODECOV_TOKEN:-}" ]]; then
  common_args+=(-t "$CODECOV_TOKEN")
fi

IFS=',' read -r -a configured_files <<< "${CODECOV_FILES:-}"
IFS=',' read -r -a configured_flags <<< "${CODECOV_FLAGS:-}"

sanitize_package_flag() {
  local raw_name="$1"
  local sanitized

  sanitized="$raw_name"
  sanitized="${sanitized//\//-}"
  sanitized="$(printf '%s' "$sanitized" | sed -E 's/[^[:alnum:]_.-]+/-/g; s/-+/-/g; s/^[._-]+//; s/[._-]+$//')"
  sanitized="${sanitized:0:45}"
  sanitized="$(printf '%s' "$sanitized" | sed -E 's/[._-]+$//')"

  if [[ -z "$sanitized" ]]; then
    sanitized="pkg"
  fi

  printf '%s' "$sanitized"
}

resolve_unique_flag() {
  local package_name="$1"
  local package_without_scope="$2"
  local package_with_scope="$3"
  local unscoped_flag scoped_flag existing_package

  unscoped_flag="$(sanitize_package_flag "$package_without_scope")"
  existing_package="${flag_to_package[$unscoped_flag]-}"
  if [[ -z "$existing_package" ]] || [[ "$existing_package" == "$package_name" ]]; then
    printf '%s' "$unscoped_flag"
    return
  fi

  scoped_flag="$(sanitize_package_flag "$package_with_scope")"
  if [[ "$scoped_flag" == "$unscoped_flag" ]]; then
    echo "ERROR: unable to derive unique Codecov flag for package $package_name. Unscoped candidate '$unscoped_flag' collides with ${flag_to_package[$unscoped_flag]}, and no distinct scoped fallback is available." >&2
    exit 1
  fi

  existing_package="${flag_to_package[$scoped_flag]-}"
  if [[ -z "$existing_package" ]] || [[ "$existing_package" == "$package_name" ]]; then
    printf '%s' "$scoped_flag"
    return
  fi

  echo "ERROR: unable to derive unique Codecov flag for package $package_name. Unscoped candidate '$unscoped_flag' collides with ${flag_to_package[$unscoped_flag]}, and scoped candidate '$scoped_flag' collides with ${flag_to_package[$scoped_flag]}." >&2
  exit 1
}

declare -A package_to_flag=()
declare -A flag_to_package=()
upload_count=0
if [[ "${CODECOV_REQUIRE_UPLOADS:-true}" == "true" ]] || [[ "${CODECOV_REQUIRE_UPLOADS:-1}" == "1" ]]; then
  require_uploads=true
else
  require_uploads=false
fi

while IFS=$'\t' read -r package_name package_abs_path; do
  if [[ "$package_abs_path" == "$monorepo_root" ]]; then
    # pnpm includes the workspace root; do not upload reports/coverage as one tree under the root
    # package name (it duplicates leaf uploads and can collide with path-scoped Codecov flags).
    echo "Skipping coverage upload for workspace root package $package_name; per-package subdirectories only"
    continue
  fi

  package_rel_path="${package_abs_path#"$monorepo_root/"}"
  if [[ "$package_rel_path" == "$package_abs_path" ]]; then
    echo "ERROR: package path is not under MONOREPO_ROOT ($monorepo_root): $package_abs_path" >&2
    exit 1
  fi
  package_coverage_dir="$coverage_root/$package_rel_path"

  if [[ ! -d "$package_coverage_dir" ]]; then
    echo "Skipping coverage upload for $package_name because $package_coverage_dir does not exist"
    continue
  fi

  package_flag="${package_to_flag[$package_name]-}"
  if [[ -z "$package_flag" ]]; then
    package_without_scope="$package_name"
    package_with_scope="$package_name"
    if [[ "$package_name" =~ ^@([^/]+)/(.+)$ ]]; then
      package_without_scope="${BASH_REMATCH[2]}"
      package_with_scope="${BASH_REMATCH[1]}-${BASH_REMATCH[2]}"
    fi

    package_flag="$(resolve_unique_flag "$package_name" "$package_without_scope" "$package_with_scope")"
    package_to_flag["$package_name"]="$package_flag"
    flag_to_package["$package_flag"]="$package_name"
  fi

  echo "Uploading coverage for package $package_name using Codecov flag $package_flag"

  upload_args=(
    upload-coverage
    --dir "$package_coverage_dir"
    --network-root-folder "$monorepo_root"
    --name "$package_name"
    --flag "$package_flag"
  )
  upload_args+=("${common_args[@]}")

  for coverage_file in "${configured_files[@]}"; do
    trimmed_file="${coverage_file#"${coverage_file%%[![:space:]]*}"}"
    trimmed_file="${trimmed_file%"${trimmed_file##*[![:space:]]}"}"
    if [[ -n "$trimmed_file" ]]; then
      upload_args+=(--file "$trimmed_file")
    fi
  done

  for coverage_flag in "${configured_flags[@]}"; do
    trimmed_flag="${coverage_flag#"${coverage_flag%%[![:space:]]*}"}"
    trimmed_flag="${trimmed_flag%"${trimmed_flag##*[![:space:]]}"}"
    if [[ -n "$trimmed_flag" ]]; then
      upload_args+=(--flag "$trimmed_flag")
    fi
  done

  "$codecov_cmd" "${upload_args[@]}"
  upload_count=$((upload_count + 1))
done < <($pnpm_bin ls --json -r 2>/dev/null | jq -r '.[] | "\(.name)\t\(.path)"')

if [[ "$require_uploads" == "true" ]] && (( upload_count == 0 )); then
  echo "ERROR: no coverage reports were uploaded. Ensure per-package coverage directories exist under $coverage_root or set CODECOV_REQUIRE_UPLOADS=false to allow empty uploads." >&2
  exit 1
fi
