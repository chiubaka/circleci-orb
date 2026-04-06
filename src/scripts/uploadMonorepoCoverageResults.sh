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
  pkg_rel_path="${pkg_abs_path#"$monorepo_root/"}"
  project_coverage_dir="$COVERAGE_DIR/$pkg_rel_path"

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
