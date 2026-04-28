#! /usr/bin/env bash
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
codecov_bin=${CODECOV_BINARY:-codecovcli}

install_codecov_cli() {
  local bootstrap_dir bootstrap_script

  if python3 -m pip --version >/dev/null 2>&1; then
    if python3 -m pip install --user codecov-cli >/dev/null; then
      return
    fi
  fi

  if python3 -m ensurepip --upgrade --user >/dev/null 2>&1 && python3 -m pip --version >/dev/null 2>&1; then
    if python3 -m pip install --user codecov-cli >/dev/null; then
      return
    fi
  fi

  if command -v pip3 >/dev/null 2>&1; then
    if pip3 install --user codecov-cli >/dev/null; then
      return
    fi
  fi

  if command -v curl >/dev/null 2>&1; then
    bootstrap_dir="$(mktemp -d)"
    bootstrap_script="$bootstrap_dir/get-pip.py"
    if curl -fsSL https://bootstrap.pypa.io/get-pip.py -o "$bootstrap_script" >/dev/null 2>&1 && python3 "$bootstrap_script" --user >/dev/null 2>&1; then
      if python3 -m pip install --user codecov-cli >/dev/null; then
        rm -rf "$bootstrap_dir"
        return
      fi
    fi
    rm -rf "$bootstrap_dir"
  fi

  echo "ERROR: codecovcli is not available and no Python pip installer could be bootstrapped. Install pip for python3 or provide a preinstalled Codecov binary via CODECOV_BINARY." >&2
  exit 1
}

# Install Codecov CLI if no preinstalled binary is provided.
if ! command -v "$codecov_bin" >/dev/null 2>&1; then
  if ! command -v python3 >/dev/null 2>&1; then
    echo "ERROR: codecovcli is not available and python3 is not installed." >&2
    exit 1
  fi

  install_codecov_cli
  export PATH="$HOME/.local/bin:$PATH"
  codecov_bin=codecovcli
fi

common_args=()
if [[ "${CODECOV_FAIL_ON_ERROR:-true}" == "true" ]] || [[ "${CODECOV_FAIL_ON_ERROR:-1}" == "1" ]]; then
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

  "$codecov_bin" "${upload_args[@]}"
  upload_count=$((upload_count + 1))
done < <($pnpm_bin ls --json -r 2>/dev/null | jq -r '.[] | "\(.name)\t\(.path)"')

if [[ "$require_uploads" == "true" ]] && (( upload_count == 0 )); then
  echo "ERROR: no coverage reports were uploaded. Ensure per-package coverage directories exist under $coverage_root or set CODECOV_REQUIRE_UPLOADS=false to allow empty uploads." >&2
  exit 1
fi
