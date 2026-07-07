#! /usr/bin/env bats

setup() {
  load "helpers/setup"
  _setup
}

_simulate_circleci_script() {
  local dest_dir=$1
  mkdir -p "$dest_dir"
  cp "$PROJECT_ROOT/src/scripts/runVerifyReleaseManifest.sh" "$dest_dir/runVerifyReleaseManifest.sh"
}

@test "skips when no release cycles without requiring staged validator" {
  repo_dir="${BATS_TEST_TMPDIR}/repo-no-manifests"
  script_dir="${BATS_TEST_TMPDIR}/circleci-script"
  mkdir -p "${repo_dir}"
  _simulate_circleci_script "${script_dir}"

  cd "${repo_dir}"
  git init -b master >/dev/null
  git config user.email "test@example.com"
  git config user.name "Test User"
  printf "readme\n" > README.md
  git add README.md
  git commit -m "base" >/dev/null

  run bash "${script_dir}/runVerifyReleaseManifest.sh"

  assert_success
  assert_output --partial "no .releases/<cycle-id>/ trees to validate; skipping."
}

@test "fails when cycles exist but validator is not staged" {
  repo_dir="${BATS_TEST_TMPDIR}/repo-with-manifest"
  script_dir="${BATS_TEST_TMPDIR}/circleci-script-missing-validator"
  mkdir -p "${repo_dir}/.releases"
  _simulate_circleci_script "${script_dir}"
  cp -a "$PROJECT_ROOT/test/fixtures/release-cycles/2026.05.08.1" \
    "${repo_dir}/.releases/"

  cd "${repo_dir}"
  git init -b master >/dev/null
  git config user.email "test@example.com"
  git config user.name "Test User"

  VERIFY_RELEASE_MANIFEST_MODE=all \
    run bash "${script_dir}/runVerifyReleaseManifest.sh"

  assert_failure
  assert_output --partial "set VALIDATE_RELEASE_CYCLE_SCRIPT"
}

@test "validates cycles via staged validator override in all mode" {
  repo_dir="${BATS_TEST_TMPDIR}/repo-staged-validator"
  script_dir="${BATS_TEST_TMPDIR}/circleci-script-staged"
  stage_dir="${BATS_TEST_TMPDIR}/chiubaka-release-cycle-verify"
  mkdir -p "${repo_dir}/.releases"
  _simulate_circleci_script "${script_dir}"
  WRITE_RELEASE_CYCLE_STAGE_DIR="${stage_dir}" \
    bash "$PROJECT_ROOT/src/scripts/stageReleaseCycleWriter.sh" >/dev/null
  cp -a "$PROJECT_ROOT/test/fixtures/release-cycles/2026.05.08.1" \
    "${repo_dir}/.releases/"

  cd "${repo_dir}"
  git init -b master >/dev/null
  git config user.email "test@example.com"
  git config user.name "Test User"

  VERIFY_RELEASE_MANIFEST_MODE=all \
  VALIDATE_RELEASE_CYCLE_SCRIPT="${stage_dir}/validateReleaseCycle.mjs" \
  VALIDATE_RELEASE_MANIFEST_SCRIPT="${stage_dir}/validateReleaseManifest.mjs" \
    run bash "${script_dir}/runVerifyReleaseManifest.sh"

  assert_success
  assert_output --partial "validated 1 release cycle(s)."
}

@test "validates untracked cycles in changed mode via staged validator override" {
  repo_dir="${BATS_TEST_TMPDIR}/repo-changed-mode"
  script_dir="${BATS_TEST_TMPDIR}/circleci-script-changed"
  stage_dir="${BATS_TEST_TMPDIR}/chiubaka-release-cycle-changed"
  mkdir -p "${repo_dir}/.releases"
  _simulate_circleci_script "${script_dir}"
  WRITE_RELEASE_CYCLE_STAGE_DIR="${stage_dir}" \
    bash "$PROJECT_ROOT/src/scripts/stageReleaseCycleWriter.sh" >/dev/null
  cp -a "$PROJECT_ROOT/test/fixtures/release-cycles/2026.05.08.1" \
    "${repo_dir}/.releases/"

  cd "${repo_dir}"
  git init -b master >/dev/null
  git config user.email "test@example.com"
  git config user.name "Test User"
  printf "readme\n" > README.md
  git add README.md
  git commit -m "base" >/dev/null

  VALIDATE_RELEASE_CYCLE_SCRIPT="${stage_dir}/validateReleaseCycle.mjs" \
  VALIDATE_RELEASE_MANIFEST_SCRIPT="${stage_dir}/validateReleaseManifest.mjs" \
    run bash "${script_dir}/runVerifyReleaseManifest.sh"

  assert_success
  assert_output --partial "validated 1 release cycle(s)."
}

@test "fails on invalid rc manifest via staged validator override" {
  repo_dir="${BATS_TEST_TMPDIR}/repo-invalid-manifest"
  script_dir="${BATS_TEST_TMPDIR}/circleci-script-invalid"
  stage_dir="${BATS_TEST_TMPDIR}/chiubaka-release-cycle-invalid"
  mkdir -p "${repo_dir}/.releases/2026.05.08.1/rc1"
  _simulate_circleci_script "${script_dir}"
  WRITE_RELEASE_CYCLE_STAGE_DIR="${stage_dir}" \
    bash "$PROJECT_ROOT/src/scripts/stageReleaseCycleWriter.sh" >/dev/null
  cp "$PROJECT_ROOT/test/fixtures/release-manifests/invalid-deploy-key.yml" \
    "${repo_dir}/.releases/2026.05.08.1/rc1/manifest.yml"
  printf 'release: 2026.05.08.1\nopenedAt: 2026-05-08T14:32:00Z\n' \
    >"${repo_dir}/.releases/2026.05.08.1/cycle.yml"
  printf 'notes\n' >"${repo_dir}/.releases/2026.05.08.1/rc1/notes.md"

  cd "${repo_dir}"
  git init -b master >/dev/null
  git config user.email "test@example.com"
  git config user.name "Test User"

  VERIFY_RELEASE_MANIFEST_MODE=all \
  VALIDATE_RELEASE_CYCLE_SCRIPT="${stage_dir}/validateReleaseCycle.mjs" \
  VALIDATE_RELEASE_MANIFEST_SCRIPT="${stage_dir}/validateReleaseManifest.mjs" \
    run bash "${script_dir}/runVerifyReleaseManifest.sh"

  assert_failure
  assert_output --partial "deploy"
}
