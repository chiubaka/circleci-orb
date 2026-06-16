/**
 * Canonical category prefix tokens for application-monorepo Changesets (ADR 0002, org ADR 0038).
 * Maps summary headline prefixes to release-note sections: Features / Improvements / Bug Fixes / Other Changes.
 */

/** @typedef {'features' | 'improvements' | 'bugfixes' | 'other'} CategoryBucket */

/**
 * Accepted headline prefixes (case-insensitive). Each entry maps to a release-note section.
 * @type {readonly { bucket: CategoryBucket, section: string, prefixes: readonly string[], whenToUse: string }[]}
 */
export const CATEGORY_PREFIX_GUIDE = [
  {
    bucket: "features",
    section: "Features",
    prefixes: ["Feature:", "Features:"],
    whenToUse:
      "New user-visible capability, screen, workflow, integration, or behavior that did not exist before.",
  },
  {
    bucket: "improvements",
    section: "Improvements",
    prefixes: ["Improvement:", "Improvements:"],
    whenToUse:
      "Enhancement to existing behavior—clearer copy, better performance, UX polish, refactors with user impact—without a wholly new capability.",
  },
  {
    bucket: "bugfixes",
    section: "Bug Fixes",
    prefixes: ["Fix:", "Fixes:", "Bug Fix:", "Bug Fixes:"],
    whenToUse:
      "Correction of incorrect, broken, or regressed behavior relative to intended product behavior.",
  },
  {
    bucket: "other",
    section: "Other Changes",
    prefixes: ["Other:", "Other Changes:"],
    whenToUse:
      "Release-note-worthy work that is not a feature, improvement, or bug fix (e.g. internal-only ops, deps, tooling). " +
      "Use this prefix explicitly—omitting a prefix is invalid in category mode.",
  },
];

export const CATEGORY_ORDER = ["features", "improvements", "bugfixes", "other"];

export const CATEGORY_SECTION_TITLE = {
  features: "### Features",
  improvements: "### Improvements",
  bugfixes: "### Bug Fixes",
  other: "### Other Changes",
};

/** Headline must start with one of the accepted category tokens. */
export const CATEGORY_TOKEN_RE =
  /^(?:Feature|Features|Improvement|Improvements|Fix|Fixes|Bug\s+Fix(?:es)?|Other(?:\s+Changes)?)\s*:\s*/i;

/**
 * @param {string} text Summary headline (first line of changeset body or changelog bullet text).
 * @returns {CategoryBucket | null} Null when no recognized prefix is present.
 */
export function classifyCategoryToken(text) {
  const m = String(text).match(CATEGORY_TOKEN_RE);
  if (!m) return null;
  const token = m[0].replace(/:\s*$/, "").trim().toLowerCase();
  if (token === "feature" || token === "features") return "features";
  if (token === "improvement" || token === "improvements") return "improvements";
  if (token === "fix" || token === "fixes" || token.startsWith("bug fix")) return "bugfixes";
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
 * @param {string} content Full changeset markdown file contents.
 * @returns {{ ok: true, headline: string, bucket: CategoryBucket } | { ok: false, error: string }}
 */
export function validateChangesetSummaryCategory(content) {
  const headline = extractChangesetSummaryHeadline(content);
  if (headline === null) {
    return { ok: false, error: "changeset has no summary headline after frontmatter" };
  }
  const bucket = classifyCategoryToken(headline);
  if (bucket === null) {
    return {
      ok: false,
      error:
        `summary headline must start with a category prefix (Feature:, Improvement:, Fix:, Other:, etc.); ` +
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
