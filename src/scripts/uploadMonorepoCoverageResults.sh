#! /usr/bin/env bash

# See https://github.com/codecov/uploader/issues/475
unset NODE_OPTIONS

# shellcheck source=/dev/null
source "$BASH_ENV"

WORKSPACE_JSON=$1
COVERAGE_DIR=$2

shift 2

# shellcheck disable=SC1091
source parseNxProjects.sh
declare -A projects
parse_nx_projects "$WORKSPACE_JSON" projects

for project_name in "${!projects[@]}"
do
  project_path=${projects[$project_name]}
  project_coverage_dir="$COVERAGE_DIR/$project_path"

  $CODECOV_BINARY \
    -t "$CODECOV_TOKEN" \
    -n "$CIRCLE_BUILD_NUM" \
    -f "$project_coverage_dir" \
    -F "$project_name" \
    "$@"
done
