#! /usr/bin/env bats

setup() {
  load "helpers/setup"
  _setup
  unset GITHUB_TOKEN GH_TOKEN GITHUB_PACKAGES_TOKEN GITHUB_APP_ID GITHUB_APP_PRIVATE_KEY GITHUB_APP_INSTALLATION_ID
}

teardown() {
  unset GITHUB_TOKEN GH_TOKEN GITHUB_PACKAGES_TOKEN GITHUB_APP_ID GITHUB_APP_PRIVATE_KEY GITHUB_APP_INSTALLATION_ID
}

@test "passes when GITHUB_PACKAGES_TOKEN is set even if GITHUB_TOKEN is ghs_" {
  GITHUB_PACKAGES_TOKEN=ghp_packages GITHUB_TOKEN=ghs_minted \
    run assertGithubPackagesTokenForInstall.sh
  assert_success
}

@test "passes when GITHUB_TOKEN is a non-installation token" {
  GITHUB_TOKEN=ghp_packages_read run assertGithubPackagesTokenForInstall.sh
  assert_success
}

@test "passes when no GitHub credentials are configured" {
  run env -u GITHUB_TOKEN -u GITHUB_PACKAGES_TOKEN -u GITHUB_APP_ID \
    -u GITHUB_APP_PRIVATE_KEY -u GITHUB_APP_INSTALLATION_ID \
    assertGithubPackagesTokenForInstall.sh
  assert_success
}

@test "fails when GITHUB_TOKEN is an installation token without GITHUB_PACKAGES_TOKEN" {
  run env -u GITHUB_PACKAGES_TOKEN GITHUB_TOKEN=ghs_minted_only assertGithubPackagesTokenForInstall.sh
  assert_failure
  assert_output --partial 'installation token'
  assert_output --partial 'packages-read token is required'
  assert_output --partial 'GITHUB_APP_ID'
}

@test "fails when app credentials are set without a packages-read token" {
  run env -u GITHUB_TOKEN -u GITHUB_PACKAGES_TOKEN \
    GITHUB_APP_ID=1 GITHUB_APP_PRIVATE_KEY=key GITHUB_APP_INSTALLATION_ID=2 \
    assertGithubPackagesTokenForInstall.sh
  assert_failure
  assert_output --partial 'GitHub App credentials are set'
  assert_output --partial 'packages-read token is required'
  assert_output --partial 'not a packages-read credential'
}
