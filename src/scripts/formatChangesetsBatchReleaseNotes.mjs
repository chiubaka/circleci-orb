#!/usr/bin/env node
/**
 * Build Directus-style grouped release notes from Changesets-style CHANGELOG.md files.
 * Uncategorized top-level bullets (before any ### Major|Minor|Patch) go under Patch Changes.
 * Invoked as: node formatChangesetsBatchReleaseNotes.mjs <outfile> <changelog.md> [...]
 *
 * CircleCI note: keep this file aligned with the embedded copy in
 * stageFormatChangesetsBatchReleaseNotes.sh (orb packs that script for consumer repos).
 */
import fs from "node:fs";
import path from "node:path";

const CATEGORY_ORDER = ["major", "minor", "patch"];
const CATEGORY_TITLE = {
  major: "### Major Changes",
  minor: "### Minor Changes",
  patch: "### Patch Changes",
};

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

function classifyHeading(line) {
  const m = String(line).match(/^###\s*(Major|Minor|Patch)(?:\s+Changes)?\s*$/i);
  return m ? m[1].toLowerCase() : null;
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

function collectUntilNextHeading(lines, start) {
  let i = start;
  while (i < lines.length) {
    const line = lines[i];
    if (classifyHeading(line)) break;
    if (/^##\s+[0-9]/.test(line)) break;
    i += 1;
  }
  const segment = lines.slice(start, i);
  return { blocks: splitBulletBlocks(segment), nextIdx: i };
}

/** @returns {{ major: string[][][], minor: string[][][], patch: string[][][] }} */
function parseVersionBody(bodyLines) {
  const buckets = {
    major: [],
    minor: [],
    patch: [],
  };
  let i = 0;
  while (i < bodyLines.length) {
    const line = bodyLines[i];
    const cat = classifyHeading(line);
    if (cat) {
      i += 1;
      const { blocks, nextIdx } = collectUntilNextHeading(bodyLines, i);
      i = nextIdx;
      for (const b of blocks) buckets[cat].push(b);
    } else {
      const start = i;
      while (i < bodyLines.length && !classifyHeading(bodyLines[i])) i += 1;
      const chunk = bodyLines.slice(start, i);
      for (const b of splitBulletBlocks(chunk)) buckets.patch.push(b);
    }
  }
  return buckets;
}

function emitNestedUnderPackage(blocks) {
  const out = [];
  for (const block of blocks) {
    if (!block || block.length === 0) continue;
    const first = block[0];
    const m = String(first).match(/^[-*]\s?(.*)$/);
    const rest0 = m ? m[1] : String(first).replace(/^[-*]\s?/, "");
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

function main() {
  const outFile = process.argv[2];
  const changelogPaths = process.argv.slice(3).filter(Boolean);
  if (!outFile || changelogPaths.length === 0) {
    console.error(
      "usage: node formatChangesetsBatchReleaseNotes.mjs <outfile> <changelog.md> [...]",
    );
    process.exit(2);
  }

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
    const buckets = parseVersionBody(bodyLines);
    packages.push({ name: meta.name, buckets });
    if (meta.published) published.add(meta.published);
  }

  const lines = [];
  const byName = (a, b) => a.name.localeCompare(b.name, "en");

  for (const cat of CATEGORY_ORDER) {
    const withBlocks = packages
      .map((p) => ({ name: p.name, blocks: p.buckets[cat] }))
      .filter((p) => p.blocks.length > 0)
      .sort(byName);
    if (withBlocks.length === 0) continue;
    lines.push(CATEGORY_TITLE[cat], "");
    for (const { name, blocks } of withBlocks) {
      lines.push(`- **${name}**`);
      lines.push(...emitNestedUnderPackage(blocks));
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

main();
