/**
 * Canonical category prefix tokens for org Changesets category prefixes (ADR 0002, org ADR 0038).
 * Maps summary headline prefixes to release-note sections across library and application monorepos.
 */

/** @typedef {'breaking' | 'security' | 'features' | 'improvements' | 'bugfixes' | 'deprecations' | 'other'} CategoryBucket */

/**
 * Accepted headline prefixes (case-insensitive). Each entry maps to a release-note section.
 * @type {readonly { bucket: CategoryBucket, section: string, prefixes: readonly string[], whenToUse: string }[]}
 */
export const CATEGORY_PREFIX_GUIDE = [
  {
    bucket: "breaking",
    section: "Breaking Changes",
    prefixes: ["Breaking:", "Breaking Change:"],
    whenToUse:
      "Semver-major or API-incompatible change consumers must react to before upgrading.",
  },
  {
    bucket: "security",
    section: "Security",
    prefixes: ["Security:"],
    whenToUse:
      "Security patch, vulnerability fix, or hardening change worth highlighting separately from ordinary bug fixes.",
  },
  {
    bucket: "features",
    section: "Features",
    prefixes: ["Feature:", "Features:"],
    whenToUse:
      "New capability, API surface, workflow, integration, or behavior that did not exist before.",
  },
  {
    bucket: "improvements",
    section: "Improvements",
    prefixes: ["Improvement:", "Improvements:"],
    whenToUse:
      "Enhancement to existing behavior—clearer API, better performance, UX polish, refactors with consumer impact—without a wholly new capability.",
  },
  {
    bucket: "bugfixes",
    section: "Bug Fixes",
    prefixes: ["Fix:", "Fixes:", "Bug Fix:", "Bug Fixes:"],
    whenToUse:
      "Correction of incorrect, broken, or regressed behavior relative to intended behavior.",
  },
  {
    bucket: "deprecations",
    section: "Deprecations",
    prefixes: ["Deprecation:", "Deprecated:"],
    whenToUse:
      "Announcement that an API, option, or behavior is deprecated and scheduled for removal.",
  },
  {
    bucket: "other",
    section: "Other Changes",
    prefixes: ["Other:", "Other Changes:"],
    whenToUse:
      "Release-note-worthy work that is not breaking, security, feature, improvement, bug fix, or deprecation (e.g. internal-only ops, deps, tooling). " +
      "Use this prefix explicitly—omitting a prefix is invalid in category mode.",
  },
];

export const CATEGORY_ORDER = [
  "breaking",
  "security",
  "features",
  "improvements",
  "bugfixes",
  "deprecations",
  "other",
];

export const CATEGORY_SECTION_TITLE = {
  breaking: "### Breaking Changes",
  security: "### Security",
  features: "### Features",
  improvements: "### Improvements",
  bugfixes: "### Bug Fixes",
  deprecations: "### Deprecations",
  other: "### Other Changes",
};

/** Headline must start with one of the accepted category tokens (longer tokens first). */
export const CATEGORY_TOKEN_RE =
  /^(?:Breaking\s+Change|Breaking|Security|Deprecation|Deprecated|Feature|Features|Improvement|Improvements|Bug\s+Fix(?:es)?|Fix(?:es)?|Other(?:\s+Changes)?)\s*:\s*/i;

/**
 * @param {string} text Summary headline (first line of changeset body or changelog bullet text).
 * @returns {CategoryBucket | null} Null when no recognized prefix is present.
 */
export function classifyCategoryToken(text) {
  const m = String(text).match(CATEGORY_TOKEN_RE);
  if (!m) return null;
  const token = m[0]
    .replace(/:\s*$/, "")
    .trim()
    .toLowerCase()
    .replace(/\s+/g, " ");
  if (token === "breaking" || token === "breaking change") return "breaking";
  if (token === "security") return "security";
  if (token === "feature" || token === "features") return "features";
  if (token === "improvement" || token === "improvements") return "improvements";
  if (token === "fix" || token === "fixes" || token.startsWith("bug fix")) return "bugfixes";
  if (token === "deprecation" || token === "deprecated") return "deprecations";
  if (token === "other" || token === "other changes") return "other";
  return null;
}

/** @param {string} text */
export function hasCategoryPrefix(text) {
  return classifyCategoryToken(text) !== null;
}

/** @param {string} text */
export function stripCategoryPrefix(text) {
  return String(text).replace(CATEGORY_TOKEN_RE, "");
}

/**
 * Strip Changesets changelog bullet metadata before category matching.
 * `@changesets/cli/changelog` re-exports `@changesets/changelog-git`, which prefixes bullets with
 * `<shortSha>: ` when a changeset commit is known. `@changesets/changelog-github` may prefix with
 * PR/commit links and a `Thanks …! - ` segment before the summary headline.
 *
 * @param {string} text Changelog bullet text after the list marker (`- `).
 * @returns {string} Headline suitable for {@link classifyCategoryToken}.
 */
export function stripChangelogBulletAnnotations(text) {
  let t = String(text).trim();
  if (classifyCategoryToken(t) !== null) return t;

  const github = t.match(/^[\s\S]+?\s+-\s+([\s\S]+)$/);
  if (github) {
    const candidate = github[1].trim();
    if (classifyCategoryToken(candidate) !== null) return candidate;
  }

  const git = t.match(/^[0-9a-f]{7,40}\s*:\s*([\s\S]+)$/i);
  if (git) {
    const candidate = git[1].trim();
    if (classifyCategoryToken(candidate) !== null) return candidate;
  }

  const linkedCommit = t.match(
    /^\[(?:`)?[0-9a-f]{7,40}(?:`)?\]\([^)]+\)\s*:?\s*([\s\S]+)$/i,
  );
  if (linkedCommit) {
    const candidate = linkedCommit[1].trim();
    if (classifyCategoryToken(candidate) !== null) return candidate;
  }

  let prev;
  do {
    prev = t;
    t = t.replace(/^\[[^\]]+\]\([^)]+\)\s+/i, "").trim();
    if (classifyCategoryToken(t) !== null) return t;
  } while (t !== prev);

  return String(text).trim();
}

/**
 * @param {string} text Changelog bullet text after the list marker (`- `).
 * @returns {CategoryBucket | null}
 */
export function classifyChangelogBullet(text) {
  return classifyCategoryToken(stripChangelogBulletAnnotations(text));
}

/**
 * @param {string} text Changelog bullet text after the list marker (`- `).
 * @returns {string}
 */
export function stripChangelogBulletCategoryPrefix(text) {
  return stripCategoryPrefix(stripChangelogBulletAnnotations(text));
}

/**
 * YAML between the opening `---` delimiters of a Changesets file (package bump declarations).
 * @param {string} content
 * @returns {string | null} Null when frontmatter delimiters are missing.
 */
export function extractChangesetFrontmatterYaml(content) {
  const normalized = String(content).replace(/\r\n/g, "\n");
  if (!normalized.startsWith("---")) return null;
  const close = normalized.indexOf("\n---", 3);
  if (close === -1) return null;
  return normalized.slice(3, close).trim();
}

/**
 * True when a changeset deliberately releases no packages (`changeset add --empty`).
 * @param {string} content
 * @returns {boolean}
 */
export function isEmptyChangeset(content) {
  const yaml = extractChangesetFrontmatterYaml(content);
  return yaml !== null && yaml === "";
}

/**
 * @param {string} content Full changeset markdown file contents.
 * @returns {{ ok: true, empty: true } | { ok: true, headline: string, bucket: CategoryBucket } | { ok: false, error: string }}
 */
export function validateChangesetSummaryCategory(content) {
  if (isEmptyChangeset(content)) {
    return { ok: true, empty: true };
  }
  const headline = extractChangesetSummaryHeadline(content);
  if (headline === null) {
    return { ok: false, error: "changeset has no summary headline after frontmatter" };
  }
  const bucket = classifyCategoryToken(headline);
  if (bucket === null) {
    return {
      ok: false,
      error:
        `summary headline must start with a category prefix (Breaking:, Security:, Feature:, Fix:, Deprecation:, Other:, etc.); ` +
        `got: ${JSON.stringify(headline)}`,
    };
  }
  return { ok: true, headline, bucket };
}

/**
 * First non-empty line after YAML frontmatter (Changesets summary headline).
 * @param {string} content
 * @returns {string | null}
 */
export function extractChangesetSummaryHeadline(content) {
  const normalized = String(content).replace(/\r\n/g, "\n");
  const parts = normalized.split("\n---\n");
  if (parts.length < 2) return null;
  const body = parts.slice(1).join("\n---\n").replace(/^\s*---\s*\n?/, "");
  for (const line of body.split("\n")) {
    const trimmed = line.trim();
    if (trimmed) return trimmed;
  }
  return null;
}

/** Human-readable list of accepted prefixes for error messages and agent docs. */
export function formatAcceptedPrefixesList() {
  return CATEGORY_PREFIX_GUIDE.map(
    (g) => `${g.section}: ${g.prefixes.join(", ")}`,
  ).join("; ");
}
