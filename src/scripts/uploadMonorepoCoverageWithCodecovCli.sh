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

# Install Codecov CLI if no preinstalled binary is provided.
if ! command -v "$codecov_bin" >/dev/null 2>&1; then
  if ! command -v python3 >/dev/null 2>&1; then
    echo "ERROR: codecovcli is not available and python3 is not installed." >&2
    exit 1
  fi

  python3 -m pip install --user codecov-cli >/dev/null
  export PATH="$HOME/.local/bin:$PATH"
  codecov_bin=codecovcli
fi

common_args=()
if [[ "${CODECOV_FAIL_ON_ERROR:-false}" == "true" ]] || [[ "${CODECOV_FAIL_ON_ERROR:-0}" == "1" ]]; then
  common_args+=(--fail-on-error)
fi
if [[ "${CODECOV_VERBOSE:-false}" == "true" ]] || [[ "${CODECOV_VERBOSE:-0}" == "1" ]]; then
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

  upload_args=(
    upload-coverage
    --dir "$package_coverage_dir"
    --network-root-folder "$monorepo_root"
    --name "$package_name"
    --flag "$package_name"
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
done < <($pnpm_bin ls --json -r 2>/dev/null | jq -r '.[] | "\(.name)\t\(.path)"')
