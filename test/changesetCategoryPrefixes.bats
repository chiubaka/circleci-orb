setup() {
  load "helpers/setup"
  _setup
  PREFIXES="$PROJECT_ROOT/src/scripts/changesetCategoryPrefixes.mjs"
}

@test "classifyCategoryToken maps accepted prefix variants" {
  run node -e "
    import {
      classifyCategoryToken,
    } from '$PREFIXES';
    const cases = [
      ['Feature: x', 'features'],
      ['Features: x', 'features'],
      ['Improvement: x', 'improvements'],
      ['Improvements: x', 'improvements'],
      ['Fix: x', 'bugfixes'],
      ['Fixes: x', 'bugfixes'],
      ['Bug Fix: x', 'bugfixes'],
      ['Bug Fixes: x', 'bugfixes'],
      ['Other: x', 'other'],
      ['Other Changes: x', 'other'],
      ['plain summary', null],
    ];
    for (const [text, want] of cases) {
      const got = classifyCategoryToken(text);
      if (got !== want) {
        console.error('for', text, 'want', want, 'got', got);
        process.exit(1);
      }
    }
  "
  assert_success
}

@test "validateChangesetSummaryCategory rejects missing prefix" {
  run node -e "
    import { validateChangesetSummaryCategory } from '$PREFIXES';
    const content = '---\\n\"@t/pkg\": patch\\n---\\n\\nAdd export button\\n';
    const r = validateChangesetSummaryCategory(content);
    if (r.ok) process.exit(1);
    if (!r.error.includes('category prefix')) process.exit(2);
  "
  assert_success
}

@test "validateChangesetSummaryCategory accepts Other prefix" {
  run node -e "
    import { validateChangesetSummaryCategory } from '$PREFIXES';
    const content = '---\\n\"@t/pkg\": patch\\n---\\n\\nOther: Bump base image\\n';
    const r = validateChangesetSummaryCategory(content);
    if (!r.ok || r.bucket !== 'other') process.exit(1);
  "
  assert_success
}
