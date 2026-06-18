#! /usr/bin/env bash
# Materialize changeset category-prefix scripts for CircleCI consumers (orb packs this script;
# sibling .mjs files are not on disk in the client repo). Keep heredoc bodies in sync with
# changesetCategoryPrefixes.mjs and verifyChangesetCategoryPrefixes.mjs.
set -euo pipefail
prefixes_out=${CHANGESET_CATEGORY_PREFIXES_STAGE_PATH:-/tmp/chiubaka-changesetCategoryPrefixes.mjs}
verify_out=${VERIFY_CHANGESET_CATEGORY_PREFIXES_STAGE_PATH:-/tmp/chiubaka-verifyChangesetCategoryPrefixes.mjs}
cat >"$prefixes_out" <<'CHIUBAKA_ORB_CATEGORY_PREFIXES_V1_EOF'
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
  const token = m[0]
    .replace(/:\s*$/, "")
    .trim()
    .toLowerCase()
    .replace(/\s+/g, " ");
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
CHIUBAKA_ORB_CATEGORY_PREFIXES_V1_EOF
cat >"$verify_out" <<'CHIUBAKA_ORB_VERIFY_CATEGORY_PREFIXES_V1_EOF'
#!/usr/bin/env node
/**
 * Validate that changed .changeset/*.md files use category summary prefixes (application monorepos).
 * Invoked as: node verifyChangesetCategoryPrefixes.mjs <changeset.md> [...]
 */
import fs from "node:fs";
import path from "node:path";
import { pathToFileURL } from "node:url";

async function loadPrefixesModule() {
  const override = process.env.CHANGESET_CATEGORY_PREFIXES_SCRIPT;
  if (override) {
    return import(pathToFileURL(path.resolve(override)).href);
  }
  return import("./changesetCategoryPrefixes.mjs");
}

function isChangesetReadme(basename) {
  return basename.toLowerCase() === "readme.md";
}

async function main() {
  const paths = process.argv.slice(2).filter(Boolean);
  if (paths.length === 0) {
    console.error("usage: node verifyChangesetCategoryPrefixes.mjs <changeset.md> [...]");
    process.exit(2);
  }

  const { validateChangesetSummaryCategory, formatAcceptedPrefixesList } =
    await loadPrefixesModule();
  const cwd = process.cwd();
  const errors = [];

  for (const rel of paths) {
    const basename = path.basename(rel);
    if (isChangesetReadme(basename)) continue;
    const abs = path.isAbsolute(rel) ? rel : path.join(cwd, rel);
    if (!fs.existsSync(abs)) {
      errors.push(`${rel}: file not found`);
      continue;
    }
    const raw = fs.readFileSync(abs, "utf8");
    const result = validateChangesetSummaryCategory(raw);
    if (!result.ok) {
      errors.push(`${rel}: ${result.error}`);
    }
  }

  if (errors.length > 0) {
    console.error("verifyChangesetCategoryPrefixes: invalid changeset category prefix(es):");
    for (const e of errors) {
      console.error(`  - ${e}`);
    }
    console.error(`Accepted prefixes: ${formatAcceptedPrefixesList()}`);
    process.exit(1);
  }
}

main().catch((err) => {
  console.error(err instanceof Error ? err.message : err);
  process.exit(1);
});
CHIUBAKA_ORB_VERIFY_CATEGORY_PREFIXES_V1_EOF
