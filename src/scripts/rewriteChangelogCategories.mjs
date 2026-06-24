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
  const { classifyChangelogBullet, CATEGORY_ORDER, stripChangelogBulletCategoryPrefix } =
    prefixes;
  /** @type {Record<string, string[][][]>} */
  const buckets = Object.fromEntries(CATEGORY_ORDER.map((key) => [key, []]));
  const unclassified = [];

  function addBlocks(blocks) {
    for (const block of blocks) {
      const bucket = classifyChangelogBullet(bulletSummaryText(block));
      if (bucket === null) {
        unclassified.push(block);
      } else {
        buckets[bucket].push(
          stripCategoryTokenFromBlock(block, stripChangelogBulletCategoryPrefix),
        );
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
