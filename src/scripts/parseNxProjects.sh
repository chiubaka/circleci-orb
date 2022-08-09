#! /usr/bin/env bash
parse_nx_projects() {
  JSON_FILE=$1
  local -n _projects=$2

  local project_names
  IFS=" " read -r -a project_names <<< "$(parse_nx_project_names "$JSON_FILE")"

  local project_paths
  IFS=" " read -r -a project_paths <<< "$(parse_nx_project_paths "$JSON_FILE")"

  for (( i=0; i<${#project_names[@]}; i++ )); do
    # shellcheck disable=SC2034
    _projects[${project_names[$i]}]=${project_paths[$i]}
  done
}

parse_nx_project_names() {
  JSON_FILE=$1

  local project_names_strings
  project_names_strings=$(jq '.projects | to_entries[] | "\(.key)"' "$JSON_FILE")

  format_json_output "$project_names_strings"
}

parse_nx_project_paths() {
  JSON_FILE=$1

  local project_paths_strings
  project_paths_strings=$(jq '.projects | to_entries[] | "\(.value)"' "$JSON_FILE")

  format_json_output "$project_paths_strings"
}

format_json_output() {
  string=$1
  replace_newlines_with_spaces "$(remove_quotes "$string")"
}

remove_quotes() {
  string=$1

  string="${string//\"/""}"

  # shellcheck disable=SC2086
  echo $string
}

replace_newlines_with_spaces() {
  string=$1

  string="${string//\\n/" "}"

  # shellcheck disable=SC2086
  echo $string
}
