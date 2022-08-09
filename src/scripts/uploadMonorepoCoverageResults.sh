#! /usr/bin/env bash

# See https://github.com/codecov/uploader/issues/475
unset NODE_OPTIONS

# shellcheck source=/dev/null
source "$BASH_ENV"

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# shellcheck disable=1090,1091
source "$SCRIPT_DIR"/parseNxProjects.sh

declare -A projects
parse_nx_projects "$WORKSPACE_JSON" projects

[ -n "$XTRA_ARGS" ] && \
  set - "${@}" "$XTRA_ARGS"

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
