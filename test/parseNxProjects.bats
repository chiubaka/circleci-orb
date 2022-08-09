setup() {
  load "helpers/setup"
  _setup

  source parseNxProjects.sh
}

@test "parse_nx_projects: correctly parses projects from workspace.json" {
  local -A projects
  parse_nx_projects $TEST_DIR/examples/workspace.json projects
  assert_equal ${#projects[@]} 2
  assert_equal ${projects["nx-plugin"]} "packages/nx-plugin"
  assert_equal ${projects["nx-plugin-e2e"]} "e2e/nx-plugin-e2e"
}

@test "parse_nx_project_names: correctly parses project names from workspace.json" {
  run parse_nx_project_names $TEST_DIR/examples/workspace.json
  assert_output "nx-plugin nx-plugin-e2e"
}

@test "parse_nx_project_paths: correctly parses project paths from workspace.json" {
  run parse_nx_project_paths $TEST_DIR/examples/workspace.json
  assert_output "packages/nx-plugin e2e/nx-plugin-e2e"
}

@test "remove_quotes: correctly removes quotes from simple strings" {
  run remove_quotes "this is a test string"
  assert_output "this is a test string"
}

@test "remove_quotes: correctly removes quotes from list strings" {
  run remove_quotes '"nx-plugin:packages/nx-plugin" "nx-plugin-e2e:e2e/nx-plugin-e2e"'
  assert_output "nx-plugin:packages/nx-plugin nx-plugin-e2e:e2e/nx-plugin-e2e"
}
