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
    curl -fsS "${curl_retry[@]}" --connect-timeout 2 https://keybase.io/codecovsecops/pgp_keys.asc | gpg --no-default-keyring --import
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
global_args=()
if [[ "${CODECOV_VERBOSE:-true}" == "true" ]] || [[ "${CODECOV_VERBOSE:-1}" == "1" ]]; then
  # For codecov binary installs, verbosity is a global option (`codecov -v ...`),
  # not an `upload-coverage` subcommand option.
  global_args+=(-v)
fi
if [[ "${CODECOV_DISABLE_SEARCH:-false}" == "true" ]] || [[ "${CODECOV_DISABLE_SEARCH:-0}" == "1" ]]; then
  common_args+=(--disable-search)
fi
if [[ -n "${CODECOV_TOKEN:-}" ]]; then
  common_args+=(-t "$CODECOV_TOKEN")
fi

IFS=',' read -r -a configured_files <<< "${CODECOV_FILES:-}"
IFS=',' read -r -a configured_flags <<< "${CODECOV_FLAGS:-}"

if [[ "${CODECOV_SKIP_ZERO_HIT:-true}" == "true" ]] || [[ "${CODECOV_SKIP_ZERO_HIT:-1}" == "1" ]]; then
  skip_zero_hit=true
else
  skip_zero_hit=false
fi

# Trim leading/trailing whitespace from a string value.
trim_whitespace() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

# Collect coverage report paths under a package coverage directory.
# When CODECOV_FILES lists non-empty entries, only those basenames/relative paths
# are considered. Otherwise look for common report filenames Codecov would discover.
collect_coverage_report_files() {
  local package_coverage_dir="$1"
  local -n _out_files=$2
  local candidate trimmed has_configured_files=false

  _out_files=()

  for candidate in "${configured_files[@]+"${configured_files[@]}"}"; do
    trimmed="$(trim_whitespace "$candidate")"
    if [[ -n "$trimmed" ]]; then
      has_configured_files=true
      break
    fi
  done

  if [[ "$has_configured_files" == "true" ]]; then
    for candidate in "${configured_files[@]}"; do
      trimmed="$(trim_whitespace "$candidate")"
      [[ -z "$trimmed" ]] && continue
      if [[ -f "$package_coverage_dir/$trimmed" ]]; then
        _out_files+=("$package_coverage_dir/$trimmed")
      elif [[ -f "$trimmed" ]]; then
        _out_files+=("$trimmed")
      fi
    done
    return
  fi

  # Recurse like Codecov's --dir search so nested reports (e.g. coverage/nested/lcov.info)
  # are not skipped while Codecov would still discover them.
  local found
  while IFS= read -r -d '' found; do
    _out_files+=("$found")
  done < <(
    find "$package_coverage_dir" -type f \( \
      -name 'lcov.info' -o \
      -name 'coverage-final.json' -o \
      -name 'coverage.xml' -o \
      -name 'cobertura-coverage.xml' -o \
      -name 'clover.xml' \
    \) -print0 2>/dev/null | sort -z
  )
}

# True when an LCOV file has at least one SF: source record.
lcov_has_source_files() {
  local report_file="$1"
  grep -qE '^SF:' "$report_file"
}

# True when an LCOV file records at least one executed line or branch hit.
lcov_has_nonzero_hits() {
  local report_file="$1"
  # DA:<line>,<hits> — hits may be followed by optional checksum fields.
  if grep -qE '^DA:[0-9]+,([1-9][0-9]*)(,|$)' "$report_file"; then
    return 0
  fi
  # BRDA:<line>,<block>,<branch>,<taken> — taken is '-' or a count.
  if grep -qE '^BRDA:[0-9]+,[0-9]+,[^,]*,([1-9][0-9]*)$' "$report_file"; then
    return 0
  fi
  return 1
}

# True when a coverage-final.json (Istanbul) report includes any non-zero hit counts.
istanbul_json_has_nonzero_hits() {
  local report_file="$1"
  if ! command -v jq >/dev/null 2>&1; then
    # Without jq, treat non-empty JSON as meaningful rather than risk false skips.
    [[ -s "$report_file" ]]
    return
  fi
  jq -e '
    type == "object" and (
      to_entries
      | map(.value)
      | map(
          ((.s // {}) | to_entries | map(.value) | add // 0)
          + ((.f // {}) | to_entries | map(.value) | add // 0)
          + ((.b // {}) | to_entries | map(.value | if type == "array" then (add // 0) else . end) | add // 0)
        )
      | add // 0
    ) > 0
  ' "$report_file" >/dev/null 2>&1
}

# True when a Cobertura/Clover-style XML report looks non-empty (has class/file nodes or positive rates).
coverage_xml_looks_meaningful() {
  local report_file="$1"
  if ! [[ -s "$report_file" ]]; then
    return 1
  fi
  if grep -qE '<(class|file)[ >]' "$report_file"; then
    return 0
  fi
  if grep -qE '(line-rate|branch-rate|lines-covered)="(0\.[1-9]|[1-9])' "$report_file"; then
    return 0
  fi
  return 1
}

# True when Cobertura (hits=) or Clover (count=) XML records at least one positive hit.
coverage_xml_has_nonzero_hits() {
  local report_file="$1"
  if grep -qE 'hits="([1-9][0-9]*)"' "$report_file"; then
    return 0
  fi
  if grep -qE '<line[^>]*[[:space:]]count="([1-9][0-9]*)"' "$report_file"; then
    return 0
  fi
  return 1
}

# Decide whether a single report file represents meaningful new coverage.
coverage_report_file_is_meaningful() {
  local report_file="$1"
  local base
  base="$(basename "$report_file")"

  if ! [[ -f "$report_file" ]] || ! [[ -s "$report_file" ]]; then
    return 1
  fi

  case "$base" in
    *.info)
      if ! lcov_has_source_files "$report_file"; then
        return 1
      fi
      if [[ "$skip_zero_hit" == "true" ]] && ! lcov_has_nonzero_hits "$report_file"; then
        return 1
      fi
      return 0
      ;;
    coverage-final.json)
      if [[ "$skip_zero_hit" == "true" ]]; then
        istanbul_json_has_nonzero_hits "$report_file"
        return
      fi
      return 0
      ;;
    *.xml)
      if ! coverage_xml_looks_meaningful "$report_file"; then
        return 1
      fi
      if [[ "$skip_zero_hit" == "true" ]] && ! coverage_xml_has_nonzero_hits "$report_file"; then
        return 1
      fi
      return 0
      ;;
    *)
      # Unknown formats: require non-empty content only.
      return 0
      ;;
  esac
}

# Collect report paths under a package coverage directory that pass meaningfulness checks.
collect_meaningful_coverage_report_files() {
  local package_coverage_dir="$1"
  local -n _out_meaningful=$2
  local report_files=()
  local report_file

  _out_meaningful=()
  collect_coverage_report_files "$package_coverage_dir" report_files
  for report_file in "${report_files[@]+"${report_files[@]}"}"; do
    if coverage_report_file_is_meaningful "$report_file"; then
      _out_meaningful+=("$report_file")
    fi
  done
}

# Path suitable for Codecov --file: relative to the package coverage dir when possible.
coverage_report_upload_path() {
  local report_file="$1"
  local package_coverage_dir="$2"
  if [[ "$report_file" == "$package_coverage_dir/"* ]]; then
    printf '%s' "${report_file#"$package_coverage_dir/"}"
  else
    printf '%s' "$report_file"
  fi
}

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

  meaningful_files=()
  collect_meaningful_coverage_report_files "$package_coverage_dir" meaningful_files
  if ((${#meaningful_files[@]} == 0)); then
    echo "Skipping coverage upload for $package_name because $package_coverage_dir has no meaningful coverage report (empty, stub, or zero-hit)"
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

  # Upload only validated paths; disable search so rejected sibling reports are not discovered.
  has_disable_search=false
  for common_arg in "${common_args[@]+"${common_args[@]}"}"; do
    if [[ "$common_arg" == "--disable-search" ]]; then
      has_disable_search=true
      break
    fi
  done
  if [[ "$has_disable_search" == "false" ]]; then
    upload_args+=(--disable-search)
  fi

  for report_file in "${meaningful_files[@]}"; do
    upload_args+=(--file "$(coverage_report_upload_path "$report_file" "$package_coverage_dir")")
  done

  for coverage_flag in "${configured_flags[@]}"; do
    trimmed_flag="${coverage_flag#"${coverage_flag%%[![:space:]]*}"}"
    trimmed_flag="${trimmed_flag%"${trimmed_flag##*[![:space:]]}"}"
    if [[ -n "$trimmed_flag" ]]; then
      upload_args+=(--flag "$trimmed_flag")
    fi
  done

  "$codecov_cmd" "${global_args[@]}" "${upload_args[@]}"
  upload_count=$((upload_count + 1))
done < <($pnpm_bin ls --json -r 2>/dev/null | jq -r '.[] | "\(.name)\t\(.path)"')

if [[ "$require_uploads" == "true" ]] && (( upload_count == 0 )); then
  echo "ERROR: no coverage reports were uploaded. Ensure per-package coverage directories exist under $coverage_root or set CODECOV_REQUIRE_UPLOADS=false to allow empty uploads." >&2
  exit 1
fi
