setup() {
  load "helpers/setup"
  _setup
  FORMATTER="$PROJECT_ROOT/src/scripts/formatChangesetsBatchReleaseNotes.mjs"
}

_make_pkg_changelog() {
  local dir=$1 version=$2 body=$3
  mkdir -p "$dir"
  printf '%s\n' "{\"name\":\"@t/$(basename "$dir")\",\"version\":\"$version\"}" >"$dir/package.json"
  cat >"$dir/CHANGELOG.md" <<EOF
# @t/$(basename "$dir")
## $version
$body
EOF
}

@test "default bump-type grouping matches Major Minor Patch layout" {
  local out
  cd "$BATS_TEST_TMPDIR" || exit 1
  _make_pkg_changelog pkg-a 2.0.0 "### Minor Changes
- minor line
### Patch Changes
- patch line"
  _make_pkg_changelog pkg-b 1.5.0 "### Patch Changes
- patch only"

  out=$(mktemp)
  run env RELEASE_NOTES_GROUPING=bump-type node "$FORMATTER" "$out" pkg-a/CHANGELOG.md pkg-b/CHANGELOG.md
  assert_success

  run grep -F "### Minor Changes" "$out"
  assert_success
  run grep -F "### Patch Changes" "$out"
  assert_success
  run grep -F "**@t/pkg-a**" "$out"
  assert_success
  run grep -F "**@t/pkg-b**" "$out"
  assert_success
  run grep -F "## Published versions" "$out"
  assert_success
  run grep -F '`@t/pkg-a@2.0.0`' "$out"
  assert_success
  run grep -F "minor line" "$out"
  assert_success
  run grep -F "patch only" "$out"
  assert_success
  rm -f "$out"
}

@test "default bump-type sends uncategorized bullets to Patch Changes" {
  local out
  cd "$BATS_TEST_TMPDIR" || exit 1
  _make_pkg_changelog pkg 1.2.0 "- uncategorized bullet"

  out=$(mktemp)
  node "$FORMATTER" "$out" pkg/CHANGELOG.md
  run grep -F "### Patch Changes" "$out"
  assert_success
  run grep -F "uncategorized bullet" "$out"
  assert_success
  rm -f "$out"
}

@test "category mode groups by category headings and strips prefix tokens" {
  local out
  cd "$BATS_TEST_TMPDIR" || exit 1
  _make_pkg_changelog directus 2026.06.13.1 "### Features
- Feature: Add a location-input interface
### Improvements
- Improvement: Relabel the Status field
### Bug Fixes
- Fix: Correct deadline parsing"

  out=$(mktemp)
  run env RELEASE_NOTES_GROUPING=category node "$FORMATTER" "$out" directus/CHANGELOG.md
  assert_success

  run grep -F "### Features" "$out"
  assert_success
  run grep -F "### Improvements" "$out"
  assert_success
  run grep -F "### Bug Fixes" "$out"
  assert_success
  run grep -F "Add a location-input interface" "$out"
  assert_success
  run grep -F "Feature:" "$out"
  assert_failure
  run grep -F "Relabel the Status field" "$out"
  assert_success
  run grep -F "Correct deadline parsing" "$out"
  assert_success
  run grep -F "**@t/directus**" "$out"
  assert_success
  rm -f "$out"
}

@test "category mode classifies inline tokens under bump headings into category buckets" {
  local out
  cd "$BATS_TEST_TMPDIR" || exit 1
  _make_pkg_changelog app 1.0.0 "### Minor Changes
- Feature: ship new dashboard
- Fix: handle empty state"

  out=$(mktemp)
  run env RELEASE_NOTES_GROUPING=category node "$FORMATTER" "$out" app/CHANGELOG.md
  assert_success

  run grep -F "### Features" "$out"
  assert_success
  run grep -F "### Bug Fixes" "$out"
  assert_success
  run grep -F "ship new dashboard" "$out"
  assert_success
  run grep -F "handle empty state" "$out"
  assert_success
  run grep -F "### Minor Changes" "$out"
  assert_failure
  rm -f "$out"
}

@test "category mode rejects bullets without a category prefix" {
  local out
  cd "$BATS_TEST_TMPDIR" || exit 1
  _make_pkg_changelog app 1.0.0 "- untagged maintenance note"

  out=$(mktemp)
  run env RELEASE_NOTES_GROUPING=category node "$FORMATTER" "$out" app/CHANGELOG.md
  assert_failure
  run grep -F "missing a category prefix" <<<"$output"
  assert_success
  rm -f "$out"
}

@test "category mode accepts bullets under category headings after rewriteChangelogCategories" {
  local out
  cd "$BATS_TEST_TMPDIR" || exit 1
  _make_pkg_changelog app 1.0.0 "### Features
- Add optional include-pr-metadata for PR continuation parameters.
### Bug Fixes
- Recognize category prefixes on changelog bullets that include Changesets commit annotations.
- Stage validateReleaseManifest.mjs for verify-release-manifest in CircleCI consumers."

  out=$(mktemp)
  run env RELEASE_NOTES_GROUPING=category node "$FORMATTER" "$out" app/CHANGELOG.md
  assert_success

  run grep -F "### Features" "$out"
  assert_success
  run grep -F "### Bug Fixes" "$out"
  assert_success
  run grep -F "include-pr-metadata" "$out"
  assert_success
  run grep -F "validateReleaseManifest.mjs" "$out"
  assert_success
  rm -f "$out"
}

@test "category mode accepts changelog-git shortSha prefixed bullets" {
  local out
  cd "$BATS_TEST_TMPDIR" || exit 1
  _make_pkg_changelog directus 2026.06.24.1 "### Minor Changes
- 977f100: Feature: Show application deadlines
- 51fd230: Improvement: Editors can control display order
### Patch Changes
- abcdef0: Fix: Correct deadline parsing"

  out=$(mktemp)
  run env RELEASE_NOTES_GROUPING=category node "$FORMATTER" "$out" directus/CHANGELOG.md
  assert_success

  run grep -F "### Features" "$out"
  assert_success
  run grep -F "Show application deadlines" "$out"
  assert_success
  run grep -F "977f100:" "$out"
  assert_failure
  rm -f "$out"
}

@test "category mode places Other-prefixed bullets under Other Changes" {
  local out
  cd "$BATS_TEST_TMPDIR" || exit 1
  _make_pkg_changelog app 1.0.0 "- Other: internal dependency maintenance"

  out=$(mktemp)
  run env RELEASE_NOTES_GROUPING=category node "$FORMATTER" "$out" app/CHANGELOG.md
  assert_success

  run grep -F "### Other Changes" "$out"
  assert_success
  run grep -F "internal dependency maintenance" "$out"
  assert_success
  run grep -F "Other:" "$out"
  assert_failure
  rm -f "$out"
}

@test "category mode orders all seven sections in CATEGORY_ORDER" {
  local out
  cd "$BATS_TEST_TMPDIR" || exit 1
  _make_pkg_changelog app 1.0.0 "### Other Changes
- Other: tagged other entry
### Deprecations
- Deprecation: old API
### Bug Fixes
- Fix: bug
### Improvements
- Improvement: imp
### Features
- Feature: feat
### Security
- Security: patch CVE
### Breaking Changes
- Breaking: remove endpoint"

  out=$(mktemp)
  run env RELEASE_NOTES_GROUPING=category node "$FORMATTER" "$out" app/CHANGELOG.md
  assert_success
  [[ $(grep -n "### Breaking Changes" "$out" | cut -d: -f1) -lt $(grep -n "### Security" "$out" | cut -d: -f1) ]]
  [[ $(grep -n "### Security" "$out" | cut -d: -f1) -lt $(grep -n "### Features" "$out" | cut -d: -f1) ]]
  [[ $(grep -n "### Features" "$out" | cut -d: -f1) -lt $(grep -n "### Improvements" "$out" | cut -d: -f1) ]]
  [[ $(grep -n "### Improvements" "$out" | cut -d: -f1) -lt $(grep -n "### Bug Fixes" "$out" | cut -d: -f1) ]]
  [[ $(grep -n "### Bug Fixes" "$out" | cut -d: -f1) -lt $(grep -n "### Deprecations" "$out" | cut -d: -f1) ]]
  [[ $(grep -n "### Deprecations" "$out" | cut -d: -f1) -lt $(grep -n "### Other Changes" "$out" | cut -d: -f1) ]]
  rm -f "$out"
}

@test "category mode places Breaking Security and Deprecation bullets under correct headings" {
  local out
  cd "$BATS_TEST_TMPDIR" || exit 1
  _make_pkg_changelog lib 2.0.0 "- Breaking: drop legacy export
- Security: rotate signing keys
- Deprecation: prefer new client"

  out=$(mktemp)
  run env RELEASE_NOTES_GROUPING=category node "$FORMATTER" "$out" lib/CHANGELOG.md
  assert_success

  run grep -F "### Breaking Changes" "$out"
  assert_success
  run grep -F "### Security" "$out"
  assert_success
  run grep -F "### Deprecations" "$out"
  assert_success
  run grep -F "drop legacy export" "$out"
  assert_success
  run grep -F "rotate signing keys" "$out"
  assert_success
  run grep -F "prefer new client" "$out"
  assert_success
  rm -f "$out"
}

@test "category mode orders sections Features Improvements Bug Fixes Other" {
  local out
  cd "$BATS_TEST_TMPDIR" || exit 1
  _make_pkg_changelog app 1.0.0 "### Other Changes
- Other: tagged other entry
### Bug Fixes
- Fix: bug
### Features
- Feature: feat
### Improvements
- Improvement: imp"

  out=$(mktemp)
  run env RELEASE_NOTES_GROUPING=category node "$FORMATTER" "$out" app/CHANGELOG.md
  assert_success
  [[ $(grep -n "### Features" "$out" | cut -d: -f1) -lt $(grep -n "### Improvements" "$out" | cut -d: -f1) ]]
  [[ $(grep -n "### Improvements" "$out" | cut -d: -f1) -lt $(grep -n "### Bug Fixes" "$out" | cut -d: -f1) ]]
  [[ $(grep -n "### Bug Fixes" "$out" | cut -d: -f1) -lt $(grep -n "### Other Changes" "$out" | cut -d: -f1) ]]
  rm -f "$out"
}

@test "default mode output is unchanged when RELEASE_NOTES_GROUPING is unset" {
  local out expected
  cd "$BATS_TEST_TMPDIR" || exit 1
  _make_pkg_changelog pkg 1.2.0 "### Minor
- new entry"

  out=$(mktemp)
  node "$FORMATTER" "$out" pkg/CHANGELOG.md
  expected=$(cat "$out")

  out2=$(mktemp)
  env RELEASE_NOTES_GROUPING=bump-type node "$FORMATTER" "$out2" pkg/CHANGELOG.md
  assert_equal "$(cat "$out2")" "$expected"
  rm -f "$out" "$out2"
}
