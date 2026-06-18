#! /usr/bin/env bash
# Materialize release-notes scripts for CircleCI consumers (orb packs this script;
# sibling .mjs files are not on disk in the client repo). Keep heredoc bodies in sync with
# formatChangesetsBatchReleaseNotes.mjs, rewriteChangelogCategories.mjs, and changesetCategoryPrefixes.mjs.
set -euo pipefail
prefixes_out=${CHANGESET_CATEGORY_PREFIXES_STAGE_PATH:-/tmp/chiubaka-changesetCategoryPrefixes.mjs}
cat >"$prefixes_out" <<'CHIUBAKA_ORB_CATEGORY_PREFIXES_V1_EOF'
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
CHIUBAKA_ORB_CATEGORY_PREFIXES_V1_EOF
out=${FORMAT_CHANGESETS_BATCH_STAGE_PATH:-/tmp/chiubaka-formatChangesetsBatchReleaseNotes.mjs}
cat >"$out" <<'CHIUBAKA_ORB_FORMATTER_V1_EOF'
#!/usr/bin/env node
/**
 * Build grouped release notes from Changesets-style CHANGELOG.md files.
 *
 * Default (bump-type): group under ### Major|Minor|Patch Changes; uncategorized bullets -> Patch.
 * Category mode (RELEASE_NOTES_GROUPING=category): group under ### Breaking Changes / Security /
 * Features / Improvements / Bug Fixes / Deprecations / Other Changes; bullets without a recognized
 * prefix fail formatting.
 *
 * Invoked as: node formatChangesetsBatchReleaseNotes.mjs <outfile> <changelog.md> [...]
 *
 * CircleCI note: keep this file aligned with the embedded copy in
 * stageFormatChangesetsBatchReleaseNotes.sh (orb packs that script for consumer repos).
 */
import fs from "node:fs";
import path from "node:path";
import { pathToFileURL } from "node:url";

const GROUPING = (process.env.RELEASE_NOTES_GROUPING || "bump-type").toLowerCase();

async function loadCategoryPrefixes() {
  const override = process.env.CHANGESET_CATEGORY_PREFIXES_SCRIPT;
  if (override) {
    return import(pathToFileURL(path.resolve(override)).href);
  }
  return import("./changesetCategoryPrefixes.mjs");
}

const BUMP_TYPE_CONFIG = {
  order: ["major", "minor", "patch"],
  titles: {
    major: "### Major Changes",
    minor: "### Minor Changes",
    patch: "### Patch Changes",
  },
  fallbackBucket: "patch",
  classifyHeading(line) {
    const m = String(line).match(/^###\s*(Major|Minor|Patch)(?:\s+Changes)?\s*$/i);
    return m ? m[1].toLowerCase() : null;
  },
  classifyBulletBlock() {
    return null;
  },
};

function buildCategoryConfig(prefixes) {
  const { classifyCategoryToken, CATEGORY_ORDER, CATEGORY_SECTION_TITLE, CATEGORY_TOKEN_RE } =
    prefixes;
  return {
    order: CATEGORY_ORDER,
    titles: CATEGORY_SECTION_TITLE,
    fallbackBucket: null,
    classifyHeading(line) {
      const t = String(line).trim();
      if (/^###\s*Breaking(?:\s+Changes)?\s*$/i.test(t)) return "breaking";
      if (/^###\s*Security\s*$/i.test(t)) return "security";
      if (/^###\s*Features?\s*$/i.test(t)) return "features";
      if (/^###\s*Improvements?\s*$/i.test(t)) return "improvements";
      if (/^###\s*(?:Bug\s+)?Fix(?:es)?\s*$/i.test(t)) return "bugfixes";
      if (/^###\s*Deprecations?\s*$/i.test(t)) return "deprecations";
      if (/^###\s*Other(?:\s+Changes)?\s*$/i.test(t)) return "other";
      return null;
    },
    classifyBulletBlock(block) {
      const first = block[0];
      const m = String(first).match(/^[-*]\s?(.*)$/);
      const text = m ? m[1] : String(first).replace(/^[-*]\s?/, "");
      return classifyCategoryToken(text);
    },
  };
}

function readPackageMeta(changelogPath) {
  const dir = path.dirname(changelogPath);
  const pkgJson = path.join(dir, "package.json");
  try {
    const j = JSON.parse(fs.readFileSync(pkgJson, "utf8"));
    const name = typeof j.name === "string" && j.name ? j.name : changelogPath;
    const published =
      j.name && typeof j.version === "string" && j.version ? `${j.name}@${j.version}` : "";
    return { name, published };
  } catch {
    return { name: changelogPath, published: "" };
  }
}

/** First ## line whose title starts with a digit; body until next such ##. */
function extractTopVersionBody(content) {
  const lines = content.replace(/\r\n/g, "\n").split("\n");
  const startRe = /^##\s+[0-9]/;
  let i = 0;
  while (i < lines.length && !startRe.test(lines[i])) i += 1;
  if (i >= lines.length) return [];
  i += 1;
  const body = [];
  while (i < lines.length && !startRe.test(lines[i])) {
    body.push(lines[i]);
    i += 1;
  }
  return body;
}

function isTopLevelBullet(line) {
  const t = String(line).replace(/\r$/, "");
  return /^[-*]\s/.test(t) && !/^\s/.test(t);
}

/** Split lines into blocks of list items (top-level - only); keeps continuations and blank lines inside blocks. */
function splitBulletBlocks(lines) {
  const blocks = [];
  let i = 0;
  while (i < lines.length) {
    while (i < lines.length && String(lines[i]).trim() === "") i += 1;
    if (i >= lines.length) break;
    if (!isTopLevelBullet(lines[i])) {
      i += 1;
      continue;
    }
    const block = [];
    while (i < lines.length) {
      const line = lines[i];
      if (line === undefined) break;
      if (isTopLevelBullet(line) && block.length > 0) break;
      if (block.length === 0 && !isTopLevelBullet(line)) break;
      block.push(line);
      i += 1;
    }
    if (block.length > 0) blocks.push(block);
  }
  return blocks;
}

function collectUntilNextHeading(lines, start, config) {
  let i = start;
  while (i < lines.length) {
    const line = lines[i];
    if (config.classifyHeading(line)) break;
    if (/^##\s+[0-9]/.test(line)) break;
    i += 1;
  }
  const segment = lines.slice(start, i);
  return { blocks: splitBulletBlocks(segment), nextIdx: i };
}

/** @param {string[]} bodyLines @param {typeof BUMP_TYPE_CONFIG} config */
function parseVersionBody(bodyLines, config) {
  /** @type {Record<string, string[][][]>} */
  const buckets = Object.fromEntries(config.order.map((key) => [key, []]));
  const unclassified = [];
  let i = 0;
  while (i < bodyLines.length) {
    const line = bodyLines[i];
    const cat = config.classifyHeading(line);
    if (cat) {
      i += 1;
      const { blocks, nextIdx } = collectUntilNextHeading(bodyLines, i, config);
      i = nextIdx;
      for (const b of blocks) {
        if (config.fallbackBucket) {
          buckets[cat].push(b);
        } else {
          const bucket = config.classifyBulletBlock(b);
          if (bucket === null) {
            unclassified.push(b);
          } else {
            buckets[bucket].push(b);
          }
        }
      }
    } else {
      const start = i;
      while (i < bodyLines.length && !config.classifyHeading(bodyLines[i])) i += 1;
      const chunk = bodyLines.slice(start, i);
      for (const b of splitBulletBlocks(chunk)) {
        const bucket = config.classifyBulletBlock(b);
        if (bucket === null) {
          if (config.fallbackBucket) {
            buckets[config.fallbackBucket].push(b);
          } else {
            unclassified.push(b);
          }
        } else {
          buckets[bucket].push(b);
        }
      }
    }
  }
  if (unclassified.length > 0) {
    const samples = unclassified
      .slice(0, 3)
      .map((b) => {
        const m = String(b[0]).match(/^[-*]\s?(.*)$/);
        return m ? m[1] : b[0];
      })
      .join("; ");
    throw new Error(
      `formatChangesetsBatchReleaseNotes: ${unclassified.length} changelog bullet(s) missing a category prefix ` +
        `(Breaking:, Security:, Feature:, Fix:, Deprecation:, Other:, etc.). Examples: ${samples}`,
    );
  }
  return buckets;
}

function emitNestedUnderPackage(blocks, prefixes) {
  const out = [];
  const stripFn = prefixes?.stripCategoryPrefix ?? ((t) => t);
  for (const block of blocks) {
    if (!block || block.length === 0) continue;
    const first = block[0];
    const m = String(first).match(/^[-*]\s?(.*)$/);
    let rest0 = m ? m[1] : String(first).replace(/^[-*]\s?/, "");
    if (GROUPING === "category") {
      rest0 = stripFn(rest0);
    }
    out.push(`  - ${rest0}`);
    for (let k = 1; k < block.length; k += 1) {
      const ln = block[k];
      if (ln === "") {
        out.push("");
        continue;
      }
      out.push(`    ${ln}`);
    }
  }
  return out;
}

async function main() {
  const outFile = process.argv[2];
  const changelogPaths = process.argv.slice(3).filter(Boolean);
  if (!outFile || changelogPaths.length === 0) {
    console.error(
      "usage: node formatChangesetsBatchReleaseNotes.mjs <outfile> <changelog.md> [...]",
    );
    process.exit(2);
  }

  const prefixes = await loadCategoryPrefixes();
  const config =
    GROUPING === "category" ? buildCategoryConfig(prefixes) : BUMP_TYPE_CONFIG;
  const cwd = process.cwd();
  /** @type {{ name: string, buckets: ReturnType<typeof parseVersionBody> }[]} */
  const packages = [];
  const published = new Set();

  for (const rel of changelogPaths) {
    const abs = path.isAbsolute(rel) ? rel : path.join(cwd, rel);
    if (!fs.existsSync(abs)) continue;
    const raw = fs.readFileSync(abs, "utf8");
    const bodyLines = extractTopVersionBody(raw);
    const meta = readPackageMeta(abs);
    const buckets = parseVersionBody(bodyLines, config);
    packages.push({ name: meta.name, buckets });
    if (meta.published) published.add(meta.published);
  }

  const lines = [];
  const byName = (a, b) => a.name.localeCompare(b.name, "en");

  for (const cat of config.order) {
    const withBlocks = packages
      .map((p) => ({ name: p.name, blocks: p.buckets[cat] }))
      .filter((p) => p.blocks.length > 0)
      .sort(byName);
    if (withBlocks.length === 0) continue;
    lines.push(config.titles[cat], "");
    for (const { name, blocks } of withBlocks) {
      lines.push(`- **${name}**`);
      lines.push(...emitNestedUnderPackage(blocks, prefixes));
      lines.push("");
    }
  }

  const pubSorted = [...published].sort((a, b) => a.localeCompare(b, "en"));
  if (pubSorted.length > 0) {
    lines.push("## Published versions", "");
    for (const p of pubSorted) {
      lines.push(`- \`${p}\``);
    }
    lines.push("");
  }

  const text = lines.join("\n").replace(/\n{3,}/g, "\n\n").trimEnd() + "\n";
  fs.writeFileSync(outFile, text, "utf8");
}

main().catch((err) => {
  console.error(err instanceof Error ? err.message : err);
  process.exit(1);
});
CHIUBAKA_ORB_FORMATTER_V1_EOF
rewrite_out=${REWRITE_CHANGELOG_CATEGORIES_STAGE_PATH:-/tmp/chiubaka-rewriteChangelogCategories.mjs}
cat >"$rewrite_out" <<'CHIUBAKA_ORB_REWRITER_V1_EOF'
#!/usr/bin/env node
/**
 * Rewrite the top version block in Changesets CHANGELOG.md files from bump-type headings
 * (Major / Minor / Patch) to category headings (Breaking Changes / Security / Features /
 * Improvements / Bug Fixes / Deprecations / Other Changes) using the summary prefix token
 * convention (Breaking:, Security:, Feature:, Fix:, Deprecation:, Other:, etc.).
 *
 * Invoked as: node rewriteChangelogCategories.mjs <changelog.md> [...]
 *
 * CircleCI note: keep this file aligned with the embedded copy in
 * stageFormatChangesetsBatchReleaseNotes.sh.
 */
import fs from "node:fs";
import path from "node:path";
import { pathToFileURL } from "node:url";

async function loadCategoryPrefixes() {
  const override = process.env.CHANGESET_CATEGORY_PREFIXES_SCRIPT;
  if (override) {
    return import(pathToFileURL(path.resolve(override)).href);
  }
  return import("./changesetCategoryPrefixes.mjs");
}

function isTopLevelBullet(line) {
  const t = String(line).replace(/\r$/, "");
  return /^[-*]\s/.test(t) && !/^\s/.test(t);
}

function splitBulletBlocks(lines) {
  const blocks = [];
  let i = 0;
  while (i < lines.length) {
    while (i < lines.length && String(lines[i]).trim() === "") i += 1;
    if (i >= lines.length) break;
    if (!isTopLevelBullet(lines[i])) {
      i += 1;
      continue;
    }
    const block = [];
    while (i < lines.length) {
      const line = lines[i];
      if (line === undefined) break;
      if (isTopLevelBullet(line) && block.length > 0) break;
      if (block.length === 0 && !isTopLevelBullet(line)) break;
      block.push(line);
      i += 1;
    }
    if (block.length > 0) blocks.push(block);
  }
  return blocks;
}

function bulletSummaryText(block) {
  const first = block[0];
  const m = String(first).match(/^[-*]\s?(.*)$/);
  return m ? m[1] : String(first).replace(/^[-*]\s?/, "");
}

function stripCategoryTokenFromBlock(block, stripCategoryPrefix) {
  const first = block[0];
  const m = String(first).match(/^([-*]\s?)(.*)$/);
  if (!m) return block;
  const stripped = stripCategoryPrefix(m[2]);
  const out = [`${m[1]}${stripped}`, ...block.slice(1)];
  return out;
}

function classifyBumpHeading(line) {
  const m = String(line).match(/^###\s*(Major|Minor|Patch)(?:\s+Changes)?\s*$/i);
  return m ? m[1].toLowerCase() : null;
}

function classifyCategoryHeading(line) {
  const t = String(line).trim();
  if (/^###\s*Breaking(?:\s+Changes)?\s*$/i.test(t)) return "breaking";
  if (/^###\s*Security\s*$/i.test(t)) return "security";
  if (/^###\s*Features?\s*$/i.test(t)) return "features";
  if (/^###\s*Improvements?\s*$/i.test(t)) return "improvements";
  if (/^###\s*(?:Bug\s+)?Fix(?:es)?\s*$/i.test(t)) return "bugfixes";
  if (/^###\s*Deprecations?\s*$/i.test(t)) return "deprecations";
  if (/^###\s*Other(?:\s+Changes)?\s*$/i.test(t)) return "other";
  return null;
}

function extractTopVersionSection(content) {
  const lines = content.replace(/\r\n/g, "\n").split("\n");
  const startRe = /^##\s+[0-9]/;
  let headerIdx = -1;
  for (let i = 0; i < lines.length; i += 1) {
    if (startRe.test(lines[i])) {
      headerIdx = i;
      break;
    }
  }
  if (headerIdx < 0) return null;
  let endIdx = lines.length;
  for (let i = headerIdx + 1; i < lines.length; i += 1) {
    if (startRe.test(lines[i])) {
      endIdx = i;
      break;
    }
  }
  return {
    lines,
    headerIdx,
    endIdx,
    bodyStart: headerIdx + 1,
    bodyEnd: endIdx,
  };
}

function isSectionHeading(line) {
  return classifyBumpHeading(line) || classifyCategoryHeading(line);
}

function collectUntilNextHeading(lines, start) {
  let i = start;
  while (i < lines.length) {
    const line = lines[i];
    if (isSectionHeading(line)) break;
    if (/^##\s+[0-9]/.test(line)) break;
    i += 1;
  }
  return { blocks: splitBulletBlocks(lines.slice(start, i)), nextIdx: i };
}

function collectBlocksFromBody(bodyLines, prefixes) {
  const { classifyCategoryToken, CATEGORY_ORDER, stripCategoryPrefix } = prefixes;
  /** @type {Record<string, string[][][]>} */
  const buckets = Object.fromEntries(CATEGORY_ORDER.map((key) => [key, []]));
  const unclassified = [];

  function addBlocks(blocks) {
    for (const block of blocks) {
      const bucket = classifyCategoryToken(bulletSummaryText(block));
      if (bucket === null) {
        unclassified.push(block);
      } else {
        buckets[bucket].push(stripCategoryTokenFromBlock(block, stripCategoryPrefix));
      }
    }
  }

  let i = 0;
  while (i < bodyLines.length) {
    const line = bodyLines[i];
    if (isSectionHeading(line)) {
      i += 1;
      const { blocks, nextIdx } = collectUntilNextHeading(bodyLines, i);
      i = nextIdx;
      addBlocks(blocks);
    } else {
      const start = i;
      while (i < bodyLines.length && !isSectionHeading(bodyLines[i])) i += 1;
      addBlocks(splitBulletBlocks(bodyLines.slice(start, i)));
    }
  }

  if (unclassified.length > 0) {
    const samples = unclassified
      .slice(0, 3)
      .map((b) => bulletSummaryText(b))
      .join("; ");
    throw new Error(
      `rewriteChangelogCategories: ${unclassified.length} bullet(s) missing a category prefix ` +
        `(Breaking:, Security:, Feature:, Fix:, Deprecation:, Other:, etc.). Examples: ${samples}`,
    );
  }
  return buckets;
}

function renderCategoryBody(buckets, prefixes) {
  const { CATEGORY_ORDER, CATEGORY_SECTION_TITLE } = prefixes;
  const out = [];
  for (const key of CATEGORY_ORDER) {
    const blocks = buckets[key];
    if (!blocks || blocks.length === 0) continue;
    out.push(CATEGORY_SECTION_TITLE[key], "");
    for (const block of blocks) {
      out.push(...block);
    }
    out.push("");
  }
  return out.join("\n").replace(/\n{3,}/g, "\n\n").trimEnd();
}

function rewriteChangelogFile(absPath, prefixes) {
  const raw = fs.readFileSync(absPath, "utf8");
  const section = extractTopVersionSection(raw);
  if (!section) return false;
  const bodyLines = section.lines.slice(section.bodyStart, section.bodyEnd);
  const buckets = collectBlocksFromBody(bodyLines, prefixes);
  const hasAny = prefixes.CATEGORY_ORDER.some((key) => buckets[key].length > 0);
  if (!hasAny) return false;
  const newBody = renderCategoryBody(buckets, prefixes);
  const before = section.lines.slice(0, section.bodyStart).join("\n");
  const after = section.lines.slice(section.bodyEnd).join("\n");
  const parts = [before];
  if (newBody) parts.push(newBody);
  if (after) parts.push(after);
  const text = parts.filter((p, idx) => p !== "" || idx === 0).join("\n");
  fs.writeFileSync(absPath, text.endsWith("\n") ? text : `${text}\n`, "utf8");
  return true;
}

async function main() {
  const prefixes = await loadCategoryPrefixes();
  const changelogPaths = process.argv.slice(2).filter(Boolean);
  if (changelogPaths.length === 0) {
    console.error("usage: node rewriteChangelogCategories.mjs <changelog.md> [...]");
    process.exit(2);
  }
  const cwd = process.cwd();
  let changed = 0;
  for (const rel of changelogPaths) {
    const abs = path.isAbsolute(rel) ? rel : path.join(cwd, rel);
    if (!fs.existsSync(abs)) continue;
    if (rewriteChangelogFile(abs, prefixes)) changed += 1;
  }
  if (changed === 0) {
    console.error("rewriteChangelogCategories: no changelog files were rewritten.");
  }
}

main().catch((err) => {
  console.error(err instanceof Error ? err.message : err);
  process.exit(1);
});
CHIUBAKA_ORB_REWRITER_V1_EOF
