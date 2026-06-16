#!/usr/bin/env node
/**
 * Build grouped release notes from Changesets-style CHANGELOG.md files.
 *
 * Default (bump-type): group under ### Major|Minor|Patch Changes; uncategorized bullets -> Patch.
 * Category mode (RELEASE_NOTES_GROUPING=category): group under ### Features / Improvements /
 * Bug Fixes / Other Changes; bullets without a recognized prefix fail formatting.
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
      if (/^###\s*Features?\s*$/i.test(t)) return "features";
      if (/^###\s*Improvements?\s*$/i.test(t)) return "improvements";
      if (/^###\s*(?:Bug\s+)?Fix(?:es)?\s*$/i.test(t)) return "bugfixes";
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
        `(Feature:, Improvement:, Fix:, Other:, etc.). Examples: ${samples}`,
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
