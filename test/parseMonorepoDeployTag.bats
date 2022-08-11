setup() {
  load "helpers/setup"
  _setup

  # shellcheck disable=SC1091
  source parseMonorepoDeployTag.sh
}

@test "parse_package_name: parses the monorepo project name from a deploy tag" {
  run parse_package_name "nx-plugin-v0.0.1"
  assert_output "nx-plugin"
}

@test "parse_package_name: parses the monorepo project name from a deploy tag containing numbers" {
  run parse_package_name "midana12-2-v0.0.1"
  assert_output "midana12-2"
}

@test "parse_package_name: parses the monorepo project name from a deploy tag starting with numbers" {
  run parse_package_name "12chiubaka-v0.0.1"
  assert_output "12chiubaka"
}

@test "parse_package_name: parses the monorepo project name from a deploy tag with additional semver metadata" {
  run parse_package_name "tsconfig-v0.0.4-alpha+circleci-publish-3"
  assert_output "tsconfig"
}

@test "parse_semver: parses the semver from a deploy tag" {
  run parse_semver "nx-plugin-v0.0.1"
  assert_output "0.0.1"
}

@test "parse_semver: parses the semver from a deploy tag containing numbers" {
  run parse_semver "midana12-2-v0.0.1"
  assert_output "0.0.1"
}

@test "parse_semver: parses the semver from a deploy tag starting with numbers" {
  run parse_semver "12chiubaka-v0.0.1"
  assert_output "0.0.1"
}

@test "parse_semver: parses the semver from a deploy tag with additional semver metadata" {
  run parse_semver "tsconfig-v0.0.4-alpha+circleci-publish-3"
  assert_output "0.0.4-alpha+circleci-publish-3"
}
