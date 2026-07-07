setup() {
  load "helpers/setup"
  _setup
  VERIFY="$PROJECT_ROOT/src/scripts/verifyChangesetCategoryPrefixes.mjs"
}

@test "verifyChangesetCategoryPrefixes passes Breaking and Security prefixes" {
  cd "$BATS_TEST_TMPDIR" || exit 1
  mkdir -p .changeset
  cat >.changeset/breaking.md <<'EOF'
---
"@t/pkg": major
---
Breaking: Remove legacy export
EOF
  cat >.changeset/security.md <<'EOF'
---
"@t/pkg": patch
---
Security: Patch auth bypass
EOF

  run node "$VERIFY" .changeset/breaking.md .changeset/security.md
  assert_success
}

@test "verifyChangesetCategoryPrefixes passes valid changeset files" {
  cd "$BATS_TEST_TMPDIR" || exit 1
  mkdir -p .changeset
  cat >.changeset/valid.md <<'EOF'
---
"@t/pkg": patch
---
Feature: Add export
EOF

  run node "$VERIFY" .changeset/valid.md
  assert_success
}

@test "verifyChangesetCategoryPrefixes passes empty changeset from changeset add --empty" {
  cd "$BATS_TEST_TMPDIR" || exit 1
  mkdir -p .changeset
  cat >.changeset/empty.md <<'EOF'
---
---
EOF

  run node "$VERIFY" .changeset/empty.md
  assert_success
}

@test "verifyChangesetCategoryPrefixes fails on missing prefix" {
  cd "$BATS_TEST_TMPDIR" || exit 1
  mkdir -p .changeset
  cat >.changeset/bad.md <<'EOF'
---
"@t/pkg": patch
---
Add export without prefix
EOF

  run node "$VERIFY" .changeset/bad.md
  assert_failure
  run grep -F "invalid changeset category prefix" <<<"$output"
  assert_success
}

@test "embedded category prefix scripts match source modules" {
  local embedded_prefixes embedded_verify expected_prefixes expected_verify
  embedded_prefixes="$(python3 -c "
from pathlib import Path
import sys
t = Path(sys.argv[1]).read_text()
start_m = \"<<'CHIUBAKA_ORB_CATEGORY_PREFIXES_V1_EOF'\\n\"
i = t.index(start_m) + len(start_m)
end = t.index('\\nCHIUBAKA_ORB_CATEGORY_PREFIXES_V1_EOF', i)
sys.stdout.write(t[i : end + 1])
" "$PROJECT_ROOT/src/scripts/stageChangesetCategoryPrefixScripts.sh")"
  embedded_verify="$(python3 -c "
from pathlib import Path
import sys
t = Path(sys.argv[1]).read_text()
start_m = \"<<'CHIUBAKA_ORB_VERIFY_CATEGORY_PREFIXES_V1_EOF'\\n\"
i = t.index(start_m) + len(start_m)
end = t.index('\\nCHIUBAKA_ORB_VERIFY_CATEGORY_PREFIXES_V1_EOF', i)
sys.stdout.write(t[i : end + 1])
" "$PROJECT_ROOT/src/scripts/stageChangesetCategoryPrefixScripts.sh")"
  expected_prefixes="$(cat "$PROJECT_ROOT/src/scripts/changesetCategoryPrefixes.mjs")"
  expected_verify="$(cat "$PROJECT_ROOT/src/scripts/verifyChangesetCategoryPrefixes.mjs")"
  assert_equal "$expected_prefixes" "$embedded_prefixes"
  assert_equal "$expected_verify" "$embedded_verify"
}
