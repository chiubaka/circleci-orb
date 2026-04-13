#! /usr/bin/env bash
set -e

# See https://github.com/codecov/uploader/issues/475
unset NODE_OPTIONS

# shellcheck source=/dev/null
source "$BASH_ENV"

monorepo_root=${MONOREPO_ROOT:-$(pwd)}
cd "$monorepo_root" || {
  echo "ERROR: MONOREPO_ROOT is not a directory: $monorepo_root" >&2
  exit 1
}
monorepo_root=$(pwd)

pnpm_bin=${PNPM_BINARY:-"pnpm"}

xtra_args=()
if [ -n "${XTRA_ARGS:-}" ]; then
  # shellcheck disable=SC2206
  read -r -a xtra_args <<< "$XTRA_ARGS"
fi

while IFS=$'\t' read -r pkg_name pkg_abs_path; do
  # pnpm emits absolute paths with no trailing slash. For the workspace root
  # package, pkg_abs_path equals monorepo_root, so "${path#$root/}" does not
  # strip (there is no "/suffix") and pkg_rel_path would incorrectly stay
  # absolute — e.g. COVERAGE_DIR + / + /home/circleci/project (double slash).
  if [[ "$pkg_abs_path" == "$monorepo_root" ]]; then
    project_coverage_dir="$COVERAGE_DIR"
  else
    pkg_rel_path="${pkg_abs_path#"$monorepo_root/"}"
    if [[ "$pkg_rel_path" == "$pkg_abs_path" ]]; then
      echo "ERROR: package path is not under MONOREPO_ROOT ($monorepo_root): $pkg_abs_path" >&2
      exit 1
    fi
    project_coverage_dir="$COVERAGE_DIR/$pkg_rel_path"
  fi

  if [ ! -d "$project_coverage_dir" ]
  then
    echo "Skipping coverage upload for $pkg_name because $project_coverage_dir does not exist"
    continue
  fi

  $CODECOV_BINARY \
    -t "$CODECOV_TOKEN" \
    -n "$CIRCLE_BUILD_NUM" \
    --dir "$project_coverage_dir" \
    -F "$pkg_name" \
    "${xtra_args[@]}" \
    "$@"
done < <($pnpm_bin ls --json -r 2>/dev/null | jq -r '.[] | "\(.name)\t\(.path)"')
