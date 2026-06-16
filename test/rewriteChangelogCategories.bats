setup() {
  load "helpers/setup"
  _setup
  REWRITER="$PROJECT_ROOT/src/scripts/rewriteChangelogCategories.mjs"
}

@test "rewriter converts bump headings to category headings and strips tokens" {
  cd "$BATS_TEST_TMPDIR" || exit 1
  mkdir -p pkg
  cat >pkg/CHANGELOG.md <<'EOF'
# @t/pkg
## 1.2.0
### Minor Changes
- Feature: Add carousel
- Improvement: Relabel field
### Patch Changes
- Fix: Correct typo
- Other: ops-only note
EOF

  run node "$REWRITER" pkg/CHANGELOG.md
  assert_success

  run grep -F "### Features" pkg/CHANGELOG.md
  assert_success
  run grep -F "### Improvements" pkg/CHANGELOG.md
  assert_success
  run grep -F "### Bug Fixes" pkg/CHANGELOG.md
  assert_success
  run grep -F "### Other Changes" pkg/CHANGELOG.md
  assert_success
  run grep -F "Add carousel" pkg/CHANGELOG.md
  assert_success
  run grep -F "Relabel field" pkg/CHANGELOG.md
  assert_success
  run grep -F "Correct typo" pkg/CHANGELOG.md
  assert_success
  run grep -F "ops-only note" pkg/CHANGELOG.md
  assert_success
  run grep -F "Feature:" pkg/CHANGELOG.md
  assert_failure
  run grep -F "### Minor Changes" pkg/CHANGELOG.md
  assert_failure
}

@test "rewriter fails when a bullet lacks a category prefix" {
  cd "$BATS_TEST_TMPDIR" || exit 1
  mkdir -p pkg
  cat >pkg/CHANGELOG.md <<'EOF'
# @t/pkg
## 1.2.0
### Patch Changes
- missing prefix line
EOF

  run node "$REWRITER" pkg/CHANGELOG.md
  assert_failure
  run grep -F "missing a category prefix" <<<"$output"
  assert_success
}

@test "embedded rewriter in stage script matches rewriteChangelogCategories.mjs" {
  local embedded expected
  embedded="$(python3 -c "
from pathlib import Path
import sys
t = Path(sys.argv[1]).read_text()
start_m = \"<<'CHIUBAKA_ORB_REWRITER_V1_EOF'\\n\"
i = t.index(start_m) + len(start_m)
end = t.index('\\nCHIUBAKA_ORB_REWRITER_V1_EOF', i)
sys.stdout.write(t[i : end + 1])
" "$PROJECT_ROOT/src/scripts/stageFormatChangesetsBatchReleaseNotes.sh")"
  expected="$(cat "$PROJECT_ROOT/src/scripts/rewriteChangelogCategories.mjs")"
  assert_equal "$expected" "$embedded"
}
