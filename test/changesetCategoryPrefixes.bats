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
      ['Breaking: x', 'breaking'],
      ['Breaking Change: x', 'breaking'],
      ['Security: x', 'security'],
      ['Deprecation: x', 'deprecations'],
      ['Deprecated: x', 'deprecations'],
      ['Bug   Fix: x', 'bugfixes'],
      ['Other   Changes: x', 'other'],
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

@test "stripCategoryPrefix removes accepted prefix tokens" {
  run node -e "
    import { stripCategoryPrefix } from '$PREFIXES';
    const cases = [
      ['Breaking: Remove old API', 'Remove old API'],
      ['Security: Patch CVE', 'Patch CVE'],
      ['Feature: Add export', 'Add export'],
      ['Deprecation: Old helper', 'Old helper'],
    ];
    for (const [text, want] of cases) {
      const got = stripCategoryPrefix(text);
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

@test "classifyChangelogBullet strips changelog-git shortSha prefix" {
  run node -e "
    import {
      classifyChangelogBullet,
      stripChangelogBulletCategoryPrefix,
    } from '$PREFIXES';
    const text = '977f100: Feature: Show application deadlines';
    if (classifyChangelogBullet(text) !== 'features') process.exit(1);
    if (stripChangelogBulletCategoryPrefix(text) !== 'Show application deadlines') process.exit(2);
  "
  assert_success
}

@test "classifyChangelogBullet handles changelog-github metadata prefix" {
  run node -e "
    import {
      classifyChangelogBullet,
      stripChangelogBulletCategoryPrefix,
    } from '$PREFIXES';
    const text = '[#42](https://github.com/org/repo/pull/42) [\`977f100\`](https://github.com/org/repo/commit/977f100) Thanks [@alice](https://github.com/alice)! - Fix: Correct deadline parsing';
    if (classifyChangelogBullet(text) !== 'bugfixes') process.exit(1);
    if (stripChangelogBulletCategoryPrefix(text) !== 'Correct deadline parsing') process.exit(2);
  "
  assert_success
}

@test "classifyChangelogBullet still rejects genuinely prefix-less bullets" {
  run node -e "
    import { classifyChangelogBullet } from '$PREFIXES';
    if (classifyChangelogBullet('977f100: missing prefix line') !== null) process.exit(1);
    if (classifyChangelogBullet('plain summary') !== null) process.exit(2);
  "
  assert_success
}
