#! /usr/bin/env bats

setup() {
  load "helpers/setup"
  _setup
}

_write_pnpm_stub() {
  pnpm_stub="${BATS_TEST_TMPDIR}/pnpm-stub.sh"
  printf '#!/usr/bin/env bash\necho "STUB_DEPLOY_RAN $*"\n' >"$pnpm_stub"
  chmod +x "$pnpm_stub"
}

# Repo with an invalid rc manifest at the staging promotion tag's expected path.
_setup_repo_with_invalid_manifest() {
  repo_dir="${BATS_TEST_TMPDIR}/repo-coordinated-deploy"
  mkdir -p "${repo_dir}/.releases/2026.05.08.1/rc1"
  printf 'not: a valid manifest\n' >"${repo_dir}/.releases/2026.05.08.1/rc1/manifest.yml"
  _write_pnpm_stub
  cd "${repo_dir}" || exit 1
}

# Repo with no rc manifest at the staging promotion tag's expected path.
_setup_repo_without_manifest() {
  repo_dir="${BATS_TEST_TMPDIR}/repo-coordinated-deploy-missing"
  mkdir -p "${repo_dir}/.releases/2026.05.08.1"
  _write_pnpm_stub
  cd "${repo_dir}" || exit 1
}

@test "skip mode does not abort when a present manifest fails validation" {
  _setup_repo_with_invalid_manifest

  CIRCLE_TAG=staging-2026.05.08.1-rc1 \
  SKIP_MANIFEST_VALIDATION=true \
  DEPLOY_SCRIPT=deploy:coordinated \
  PNPM_BINARY="$pnpm_stub" \
  VALIDATE_RELEASE_MANIFEST_SCRIPT="$PROJECT_ROOT/src/scripts/validateReleaseManifest.mjs" \
    run bash "$PROJECT_ROOT/src/scripts/runCoordinatedDeploy.sh"

  assert_success
  assert_output --partial "manifest validation skipped"
  assert_output --partial "STUB_DEPLOY_RAN run deploy:coordinated"
}

@test "skip mode continues when the manifest file is absent" {
  _setup_repo_without_manifest

  CIRCLE_TAG=staging-2026.05.08.1-rc1 \
  SKIP_MANIFEST_VALIDATION=true \
  DEPLOY_SCRIPT=deploy:coordinated \
  PNPM_BINARY="$pnpm_stub" \
  VALIDATE_RELEASE_MANIFEST_SCRIPT="$PROJECT_ROOT/src/scripts/validateReleaseManifest.mjs" \
    run bash "$PROJECT_ROOT/src/scripts/runCoordinatedDeploy.sh"

  assert_success
  assert_output --partial "STUB_DEPLOY_RAN run deploy:coordinated"
}

@test "default mode aborts when a present manifest fails validation" {
  _setup_repo_with_invalid_manifest

  CIRCLE_TAG=staging-2026.05.08.1-rc1 \
  DEPLOY_SCRIPT=deploy:coordinated \
  PNPM_BINARY="$pnpm_stub" \
  VALIDATE_RELEASE_MANIFEST_SCRIPT="$PROJECT_ROOT/src/scripts/validateReleaseManifest.mjs" \
    run bash "$PROJECT_ROOT/src/scripts/runCoordinatedDeploy.sh"

  assert_failure
  assert_output --partial "manifest validation failed"
  refute_output --partial "STUB_DEPLOY_RAN"
}
