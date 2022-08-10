#! /usr/bin/env bash
set -e

# See https://github.com/codecov/uploader/issues/475
unset NODE_OPTIONS

# shellcheck source=/dev/null
source "$BASH_ENV"

# shellcheck disable=1090,1091
source "$PARSE_NX_PROJECTS_SCRIPT"

declare -A projects
parse_nx_projects "$WORKSPACE_JSON" projects

[ -n "$XTRA_ARGS" ] && \
  set - "${@}" "$XTRA_ARGS"

for project_name in "${!projects[@]}"
do
  project_path=${projects[$project_name]}
  project_coverage_dir="$COVERAGE_DIR/$project_path"

  if [ ! -d $project_coverage_dir ]
  then
    echo "Skipping coverage upload for $project_name because $project_coverage_dir does not exist"
    continue
  fi

  $CODECOV_BINARY \
    -t "$CODECOV_TOKEN" \
    -n "$CIRCLE_BUILD_NUM" \
    --dir "$project_coverage_dir" \
    -F "$project_name" \
    "$@"
done
