#! /usr/bin/env bash
parse_nx_projects() {
  JSON_FILE=$1;
  local -n _projects=$2;

  local project_names=(`parse_nx_project_names $JSON_FILE`);
  local project_paths=(`parse_nx_project_paths $JSON_FILE project_paths`);

  for (( i=0; i<${#project_names[@]}; i++ )); do
    _projects[${project_names[$i]}]=${project_paths[$i]};
  done
}

parse_nx_project_names() {
  JSON_FILE=$1;

  local project_names_strings=`jq '.projects | to_entries[] | "\(.key)"' $JSON_FILE`;
  echo `remove_quotes "$project_names_strings"`;
}

parse_nx_project_paths() {
  JSON_FILE=$1;

  local project_paths_strings=`jq '.projects | to_entries[] | "\(.value)"' $JSON_FILE`;
  echo `remove_quotes "$project_paths_strings"`;
}

remove_quotes() {
  STRING=$1;

  echo ${STRING//\"/""};
}
