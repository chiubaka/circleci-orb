#! /usr/bin/env bats
# shellcheck disable=SC2030,SC2031

setup() {
  load "helpers/setup"
  _setup
}

_promote_prod_init_clone() {
  local parent bare clone bare_abs
  parent=$(mktemp -d)
  bare="${parent}/origin.git"
  clone="${parent}/work"
  git init --bare "$bare" >/dev/null 2>&1
  mkdir -p "$clone"
  git -C "$clone" init >/dev/null 2>&1
  git -C "$clone" config user.email test@test
  git -C "$clone" config user.name Test
  bare_abs=$(cd "$(dirname "$bare")" && pwd)/$(basename "$bare")
  git -C "$clone" remote add origin "https://github.com/example/test.git"
  git -C "$clone" config url."file://${bare_abs}".insteadOf "https://github.com/example/test.git"
  mkdir -p "${clone}/.releases"
  cp -a "$PROJECT_ROOT/test/fixtures/release-cycles/2026.05.08.1" "${clone}/.releases/"
  echo base >"${clone}/README.md"
  git -C "$clone" add .
  git -C "$clone" commit -m "rc1 release cycle" >/dev/null 2>&1
  git -C "$clone" branch -M master >/dev/null 2>&1
  git -C "$clone" push -u origin master >/dev/null 2>&1
  printf '%s' "$clone"
}

_write_gh_stub() {
  local bindir gh_stub
  bindir=$(mktemp -d)
  gh_stub="${bindir}/gh"
  cat >"$gh_stub" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "release" && "$2" == "view" ]]; then
  exit 1
fi
printf '%s\0' "$*" >>"${GH_CALL_LOG:?GH_CALL_LOG must be set}"
exit 0
EOF
  chmod +x "$gh_stub"
  printf '%s' "$bindir"
}

_run_promote_prod_release() {
  local bindir=$1 gh_call_log=$2
  shift 2
  run env GITHUB_TOKEN=fake \
    GITHUB_REPO_SLUG=example/test \
    PRIMARY_BRANCH=master \
    UTC_TIMESTAMP_OVERRIDE=2026-05-08T16:00:00Z \
    FINALIZE_RELEASE_CYCLE_SCRIPT="$PROJECT_ROOT/src/scripts/finalizeReleaseCycle.mjs" \
    RESOLVE_RELEASE_CYCLE_SCRIPT="$PROJECT_ROOT/src/scripts/resolveReleaseCycleOnCommit.mjs" \
    ROLLUP_RELEASE_NOTES_SCRIPT="$PROJECT_ROOT/src/scripts/rollupReleaseNotes.mjs" \
    GH_CALL_LOG="$gh_call_log" \
    PATH="${bindir}:$PATH" \
    "$@" \
    bash "$PROJECT_ROOT/src/scripts/runPromoteProdRelease.sh"
}

@test "default finalize mode tags prod release at finalize commit" {
  local clone bindir gh_call_log validated_sha finalize_sha tag_sha args
  clone=$(_promote_prod_init_clone)
  bindir=$(_write_gh_stub)
  gh_call_log=$(mktemp)
  validated_sha=$(git -C "$clone" rev-parse HEAD)
  cd "$clone" || exit 1

  _run_promote_prod_release "$bindir" "$gh_call_log"

  assert_success
  finalize_sha=$(git rev-parse HEAD)
  [[ "$finalize_sha" != "$validated_sha" ]]

  tag_sha=$(git rev-parse "prod-2026.05.08.1^{commit}")
  assert_equal "$finalize_sha" "$tag_sha"
  [[ "$validated_sha" != "$tag_sha" ]]

  args=$(tr '\0' ' ' <"$gh_call_log")
  [[ "$args" == *"release create"* ]] || false
  [[ "$args" == *"--target ${finalize_sha}"* ]]
  [[ "$args" != *"--target ${validated_sha}"* ]]
}

@test "validated mode tags prod release at pre-finalize commit" {
  local clone bindir gh_call_log validated_sha finalize_sha tag_sha args
  clone=$(_promote_prod_init_clone)
  bindir=$(_write_gh_stub)
  gh_call_log=$(mktemp)
  validated_sha=$(git -C "$clone" rev-parse HEAD)
  cd "$clone" || exit 1

  _run_promote_prod_release "$bindir" "$gh_call_log" TAG_TARGET=validated

  assert_success
  finalize_sha=$(git rev-parse HEAD)
  [[ "$finalize_sha" != "$validated_sha" ]]

  tag_sha=$(git rev-parse "prod-2026.05.08.1^{commit}")
  assert_equal "$validated_sha" "$tag_sha"
  [[ "$finalize_sha" != "$tag_sha" ]]

  args=$(tr '\0' ' ' <"$gh_call_log")
  [[ "$args" == *"release create"* ]] || false
  [[ "$args" == *"--target ${validated_sha}"* ]]
  [[ "$args" != *"--target ${finalize_sha}"* ]]

  run git show "${finalize_sha}:.releases/2026.05.08.1/cycle.yml"
  assert_success
  assert_output --partial "promotedAt:"
}

@test "validated mode still pushes finalize artifacts to primary branch" {
  local clone bindir gh_call_log validated_sha
  clone=$(_promote_prod_init_clone)
  bindir=$(_write_gh_stub)
  gh_call_log=$(mktemp)
  validated_sha=$(git -C "$clone" rev-parse HEAD)
  cd "$clone" || exit 1

  _run_promote_prod_release "$bindir" "$gh_call_log" TAG_TARGET=validated

  assert_success

  git fetch origin master >/dev/null 2>&1

  run git show "origin/master:.releases/2026.05.08.1/cycle.yml"
  assert_success
  assert_output --partial "promotedAt:"

  run git rev-parse "origin/master^{commit}"
  assert_success
  [[ "$validated_sha" != "$output" ]]
}

@test "rejects unknown tag-target value" {
  local clone bindir gh_call_log
  clone=$(_promote_prod_init_clone)
  bindir=$(_write_gh_stub)
  gh_call_log=$(mktemp)
  cd "$clone" || exit 1

  _run_promote_prod_release "$bindir" "$gh_call_log" RELEASE_ID=2026.05.08.1 TAG_TARGET=unknown

  assert_failure
  assert_output --partial "TAG_TARGET must be finalize or validated"
}

@test "pre-exit fails fast when DEPLOYABLE_PACKAGES is unset" {
  local clone bindir gh_call_log
  clone=$(_promote_prod_init_clone)
  bindir=$(_write_gh_stub)
  gh_call_log=$(mktemp)
  cd "$clone" || exit 1
  mkdir -p .changeset
  printf '%s\n' '{"mode":"pre","tag":"rc","changesets":[]}' >.changeset/pre.json
  git add .changeset/pre.json
  git commit -m "enter pre" >/dev/null 2>&1

  _run_promote_prod_release "$bindir" "$gh_call_log" \
    REFRESH_HIGHEST_RC_MANIFEST_PINS_SCRIPT="$PROJECT_ROOT/src/scripts/refreshHighestRcManifestPins.mjs"

  assert_failure
  assert_output --partial "DEPLOYABLE_PACKAGES is required"
  # Must fail before mutating Changesets pre state.
  run cat .changeset/pre.json
  assert_success
  assert_output --partial '"mode":"pre"'
}

@test "stable cut tolerates dependency-bump-only changelogs under category grouping" {
  local clone bindir gh_call_log pnpm_bindir
  clone=$(_promote_prod_init_clone)
  bindir=$(_write_gh_stub)
  gh_call_log=$(mktemp)
  cd "$clone" || exit 1

  mkdir -p .changeset apps/server apps/web
  printf '%s\n' '{"mode":"pre","tag":"rc","changesets":[]}' >.changeset/pre.json
  printf '%s\n' '{"name":"@t/server","version":"5.1.0-rc.1"}' >apps/server/package.json
  printf '%s\n' '{"name":"@t/web","version":"2.3.0-rc.1"}' >apps/web/package.json
  git add .changeset/pre.json apps/server/package.json apps/web/package.json
  git commit -m "enter pre with deployable packages" >/dev/null 2>&1

  pnpm_bindir=$(mktemp -d)
  cat >"${pnpm_bindir}/pnpm" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
# Stub: pnpm exec changeset pre exit | version
if [[ "${1:-}" == "exec" && "${2:-}" == "changeset" && "${3:-}" == "pre" && "${4:-}" == "exit" ]]; then
  printf '%s\n' '{"mode":"exit","tag":"rc","changesets":[]}' >.changeset/pre.json
  exit 0
fi
if [[ "${1:-}" == "exec" && "${2:-}" == "changeset" && "${3:-}" == "version" ]]; then
  mkdir -p apps/server apps/web
  printf '%s\n' '{"name":"@t/server","version":"5.1.0"}' >apps/server/package.json
  printf '%s\n' '{"name":"@t/web","version":"2.3.0"}' >apps/web/package.json
  cat >apps/server/CHANGELOG.md <<'CHANGELOG'
# @t/server
## 5.1.0
### Patch Changes
- @snowday/domain@0.1.1
- @snowday/directus-contract@0.1.1
- Updated dependencies [abc1234]:
  - @snowday/data-platform@0.1.1
CHANGELOG
  exit 0
fi
echo "unexpected pnpm invocation: $*" >&2
exit 1
EOF
  chmod +x "${pnpm_bindir}/pnpm"

  _run_promote_prod_release "$bindir" "$gh_call_log" \
    PATH="${pnpm_bindir}:${bindir}:$PATH" \
    PNPM_BINARY=pnpm \
    DEPLOYABLE_PACKAGES="server=apps/server,web=apps/web" \
    REFRESH_HIGHEST_RC_MANIFEST_PINS_SCRIPT="$PROJECT_ROOT/src/scripts/refreshHighestRcManifestPins.mjs" \
    REWRITE_CHANGELOG_CATEGORIES_SCRIPT="$PROJECT_ROOT/src/scripts/rewriteChangelogCategories.mjs" \
    CHANGESET_CATEGORY_PREFIXES_SCRIPT="$PROJECT_ROOT/src/scripts/changesetCategoryPrefixes.mjs" \
    RELEASE_NOTES_GROUPING=category

  assert_success
  assert_output --partial "no changelog files were rewritten"
  run git rev-parse "prod-2026.05.08.1^{commit}"
  assert_success
}
