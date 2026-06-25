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

@test "skips when no manifests without requiring staged validator" {
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
  assert_output --partial "no .releases/*.yml to validate; skipping."
}

@test "fails when manifests exist but validator is not staged" {
  repo_dir="${BATS_TEST_TMPDIR}/repo-with-manifest"
  script_dir="${BATS_TEST_TMPDIR}/circleci-script-missing-validator"
  mkdir -p "${repo_dir}/.releases"
  _simulate_circleci_script "${script_dir}"
  cp "$PROJECT_ROOT/test/fixtures/release-manifests/2026.05.08.1.yml" \
    "${repo_dir}/.releases/2026.05.08.1.yml"

  cd "${repo_dir}"
  git init -b master >/dev/null
  git config user.email "test@example.com"
  git config user.name "Test User"

  VERIFY_RELEASE_MANIFEST_MODE=all \
    run bash "${script_dir}/runVerifyReleaseManifest.sh"

  assert_failure
  assert_output --partial "set VALIDATE_RELEASE_MANIFEST_SCRIPT"
}

@test "validates manifests via staged validator override in all mode" {
  repo_dir="${BATS_TEST_TMPDIR}/repo-staged-validator"
  script_dir="${BATS_TEST_TMPDIR}/circleci-script-staged"
  staged_validator="${BATS_TEST_TMPDIR}/chiubaka-validateReleaseManifest.mjs"
  mkdir -p "${repo_dir}/.releases"
  _simulate_circleci_script "${script_dir}"
  VALIDATE_RELEASE_MANIFEST_STAGE_PATH="${staged_validator}" \
    bash "$PROJECT_ROOT/src/scripts/stageReleaseManifestValidator.sh"
  cp "$PROJECT_ROOT/test/fixtures/release-manifests/2026.05.08.1.yml" \
    "${repo_dir}/.releases/2026.05.08.1.yml"

  cd "${repo_dir}"
  git init -b master >/dev/null
  git config user.email "test@example.com"
  git config user.name "Test User"

  VERIFY_RELEASE_MANIFEST_MODE=all \
  VALIDATE_RELEASE_MANIFEST_SCRIPT="${staged_validator}" \
    run bash "${script_dir}/runVerifyReleaseManifest.sh"

  assert_success
  assert_output --partial "validated 1 manifest(s)."
}

@test "validates untracked manifests in changed mode via staged validator override" {
  repo_dir="${BATS_TEST_TMPDIR}/repo-changed-mode"
  script_dir="${BATS_TEST_TMPDIR}/circleci-script-changed"
  staged_validator="${BATS_TEST_TMPDIR}/chiubaka-validateReleaseManifest-changed.mjs"
  mkdir -p "${repo_dir}/.releases"
  _simulate_circleci_script "${script_dir}"
  VALIDATE_RELEASE_MANIFEST_STAGE_PATH="${staged_validator}" \
    bash "$PROJECT_ROOT/src/scripts/stageReleaseManifestValidator.sh"
  cp "$PROJECT_ROOT/test/fixtures/release-manifests/2026.05.08.1.yml" \
    "${repo_dir}/.releases/2026.05.08.1.yml"

  cd "${repo_dir}"
  git init -b master >/dev/null
  git config user.email "test@example.com"
  git config user.name "Test User"
  printf "readme\n" > README.md
  git add README.md
  git commit -m "base" >/dev/null

  VALIDATE_RELEASE_MANIFEST_SCRIPT="${staged_validator}" \
    run bash "${script_dir}/runVerifyReleaseManifest.sh"

  assert_success
  assert_output --partial "validated 1 manifest(s)."
}

@test "fails on invalid manifest via staged validator override" {
  repo_dir="${BATS_TEST_TMPDIR}/repo-invalid-manifest"
  script_dir="${BATS_TEST_TMPDIR}/circleci-script-invalid"
  staged_validator="${BATS_TEST_TMPDIR}/chiubaka-validateReleaseManifest-invalid.mjs"
  mkdir -p "${repo_dir}/.releases"
  _simulate_circleci_script "${script_dir}"
  VALIDATE_RELEASE_MANIFEST_STAGE_PATH="${staged_validator}" \
    bash "$PROJECT_ROOT/src/scripts/stageReleaseManifestValidator.sh"
  cp "$PROJECT_ROOT/test/fixtures/release-manifests/invalid-deploy-key.yml" \
    "${repo_dir}/.releases/invalid-deploy-key.yml"

  cd "${repo_dir}"
  git init -b master >/dev/null
  git config user.email "test@example.com"
  git config user.name "Test User"

  VERIFY_RELEASE_MANIFEST_MODE=all \
  VALIDATE_RELEASE_MANIFEST_SCRIPT="${staged_validator}" \
    run bash "${script_dir}/runVerifyReleaseManifest.sh"

  assert_failure
  assert_output --partial "deploy"
}

@test "embedded release manifest validator matches source module" {
  local embedded expected
  embedded="$(python3 -c "
from pathlib import Path
import sys
t = Path(sys.argv[1]).read_text()
start_m = \"<<'CHIUBAKA_ORB_VALIDATE_RELEASE_MANIFEST_V1_EOF'\\n\"
i = t.index(start_m) + len(start_m)
end = t.index('\\nCHIUBAKA_ORB_VALIDATE_RELEASE_MANIFEST_V1_EOF', i)
sys.stdout.write(t[i : end + 1])
" "$PROJECT_ROOT/src/scripts/stageReleaseManifestValidator.sh")"
  expected="$(cat "$PROJECT_ROOT/src/scripts/validateReleaseManifest.mjs")"
  assert_equal "$expected" "$embedded"
}
