#! /usr/bin/env bats
# Regression: CREATE_RELEASE_MANIFEST=false does not require DEPLOYABLE_PACKAGES.
# Staging: create-release-manifest requires staged writeReleaseCycle.mjs in CircleCI consumers.

setup() {
  load "helpers/setup"
  _setup
  FIXTURE_MONOREPO="$PROJECT_ROOT/test/fixtures/changesets-publishing/minimal-monorepo"
}

_simulate_circleci_script() {
  local dest_dir=$1
  mkdir -p "$dest_dir"
  cp "$PROJECT_ROOT/src/scripts/runChangesetsReleasePr.sh" "$dest_dir/runChangesetsReleasePr.sh"
}

_init_git_with_origin() {
  local repo_dir=$1
  local parent bare bare_abs
  parent=$(mktemp -d)
  bare="${parent}/origin.git"
  git init --bare "$bare" >/dev/null 2>&1
  cd "$repo_dir" || exit 1
  git init -b main >/dev/null 2>&1
  git config user.email test@test
  git config user.name Test
  bare_abs=$(cd "$parent" && pwd)/origin.git
  git remote add origin "https://github.com/example/test.git"
  git config url."file://${bare_abs}".insteadOf "https://github.com/example/test.git"
  git add -A
  git commit -m init >/dev/null 2>&1
  git push -u origin main >/dev/null 2>&1
}

@test "runChangesetsReleasePr script has no unconditional manifest requirement" {
  run grep -n "DEPLOYABLE_PACKAGES" "$PROJECT_ROOT/src/scripts/runChangesetsReleasePr.sh"
  assert_success
  run awk '/create_manifest_lower/{flag=1} flag && /DEPLOYABLE_PACKAGES/{print; exit}' \
    "$PROJECT_ROOT/src/scripts/runChangesetsReleasePr.sh"
  assert_success
  assert_output --partial "DEPLOYABLE_PACKAGES"
}

@test "fails when create-release-manifest is true but writer is not staged" {
  repo_dir="${BATS_TEST_TMPDIR}/repo-missing-writer"
  script_dir="${BATS_TEST_TMPDIR}/circleci-script-missing-writer"
  cp -a "$FIXTURE_MONOREPO" "$repo_dir"
  mkdir -p "$repo_dir/apps/directus"
  printf '%s\n' '{"name":"directus","version":"1.0.0"}' >"$repo_dir/apps/directus/package.json"
  _simulate_circleci_script "$script_dir"
  _init_git_with_origin "$repo_dir"

  cd "$repo_dir"
  pnpm_mock=$(mock_create)

  GITHUB_TOKEN=test \
  PRIMARY_BRANCH=main \
  CREATE_RELEASE_MANIFEST=true \
  DEPLOYABLE_PACKAGES=directus=apps/directus \
  PNPM_BINARY="$pnpm_mock" \
  APP_DIR=. \
    run bash "${script_dir}/runChangesetsReleasePr.sh"

  assert_failure
  assert_output --partial "writeReleaseCycle.mjs not found"
}

@test "runChangesetsReleasePr writes cycle tree via staged writer before skipping empty version PR" {
  repo_dir="${BATS_TEST_TMPDIR}/repo-staged-writer"
  script_dir="${BATS_TEST_TMPDIR}/circleci-script-staged-writer"
  stage_dir="${BATS_TEST_TMPDIR}/chiubaka-release-cycle-staged"
  cp -a "$FIXTURE_MONOREPO" "$repo_dir"
  mkdir -p "$repo_dir/apps/directus"
  printf '%s\n' '{"name":"directus","version":"1.0.0"}' >"$repo_dir/apps/directus/package.json"
  _simulate_circleci_script "$script_dir"
  _init_git_with_origin "$repo_dir"
  WRITE_RELEASE_CYCLE_STAGE_DIR="$stage_dir" \
    bash "$PROJECT_ROOT/src/scripts/stageReleaseCycleWriter.sh" >/dev/null

  cd "$repo_dir"
  pnpm_mock=$(mock_create)

  GITHUB_TOKEN=test \
  PRIMARY_BRANCH=main \
  CREATE_RELEASE_MANIFEST=true \
  DEPLOYABLE_PACKAGES=directus=apps/directus \
  UTC_DATE_OVERRIDE=2099.12.31 \
  UTC_TIMESTAMP_OVERRIDE=2099-12-31T12:00:00Z \
  WRITE_RELEASE_CYCLE_SCRIPT="${stage_dir}/writeReleaseCycle.mjs" \
  PNPM_BINARY="$pnpm_mock" \
  APP_DIR=. \
    run bash "${script_dir}/runChangesetsReleasePr.sh"

  assert_success
  refute_output --partial "writeReleaseCycle.mjs not found"
  assert_output --partial "changeset version produced no package.json changes"
  assert [ -f ".releases/2099.12.31.1/rc1/manifest.yml" ]
  run grep -F 'release: 2099.12.31.1' ".releases/2099.12.31.1/rc1/manifest.yml"
  assert_success
  run grep -F "directus: directus-v1.0.0" ".releases/2099.12.31.1/rc1/manifest.yml"
  assert_success
}
