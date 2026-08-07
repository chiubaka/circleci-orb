#!/usr/bin/env node
/**
 * Collate per-RC release-notes.md into cycle release-notes.md (ADR 0041).
 *
 * Merges all `rc<n>/release-notes.md` files into one document with the same
 * nesting as formatChangesetsBatchReleaseNotes (default: package-then-category).
 * Does not emit RC promotion headings — Artifact 3 is the full-cycle story
 * without referencing soak candidates.
 *
 * Usage: node rollupReleaseNotes.mjs <cycle-dir> [outfile]
 *
 * Env:
 *   RELEASE_NOTES_GROUPING — category | bump-type (default category)
 *   RELEASE_NOTES_NESTING — package-then-category | category-then-package
 *   CHANGESET_CATEGORY_PREFIXES_SCRIPT — optional override for prefixes module
 */
import fs from "node:fs";
import path from "node:path";
import { pathToFileURL, fileURLToPath } from "node:url";
import { listRcNotesPaths } from "./lib/releaseCycle.mjs";

const SCRIPT_DIR = path.dirname(fileURLToPath(import.meta.url));

const GROUPING = (process.env.RELEASE_NOTES_GROUPING || "category").toLowerCase();
const NESTING = (
  process.env.RELEASE_NOTES_NESTING || "package-then-category"
).toLowerCase();

const BUMP_TYPE_ORDER = ["major", "minor", "patch"];
const BUMP_TYPE_TITLES = {
  major: "### Major Changes",
  minor: "### Minor Changes",
  patch: "### Patch Changes",
};

function fail(msg) {
  process.stderr.write(`rollupReleaseNotes: ${msg}\n`);
  process.exit(1);
}

async function loadCategoryPrefixes() {
  const override = process.env.CHANGESET_CATEGORY_PREFIXES_SCRIPT;
  if (override) {
    return import(pathToFileURL(path.resolve(override)).href);
  }
  return import(pathToFileURL(path.join(SCRIPT_DIR, "changesetCategoryPrefixes.mjs")).href);
}

function classifyCategoryHeading(line) {
  const t = String(line).trim().replace(/^#{1,6}\s+/, "");
  if (/^Breaking(?:\s+Changes)?$/i.test(t)) return "breaking";
  if (/^Security$/i.test(t)) return "security";
  if (/^Features?$/i.test(t)) return "features";
  if (/^Improvements?$/i.test(t)) return "improvements";
  if (/^(?:Bug\s+)?Fix(?:es)?$/i.test(t)) return "bugfixes";
  if (/^Deprecations?$/i.test(t)) return "deprecations";
  if (/^Other(?:\s+Changes)?$/i.test(t)) return "other";
  return null;
}

function classifyBumpHeading(line) {
  const t = String(line).trim().replace(/^#{1,6}\s+/, "");
  const m = t.match(/^(Major|Minor|Patch)(?:\s+Changes)?$/i);
  return m ? m[1].toLowerCase() : null;
}

function headingLevel(line) {
  const m = String(line).match(/^(#{1,6})\s+\S/);
  return m ? m[1].length : 0;
}

function isPublishedVersionsHeading(line) {
  return /^##\s+Published versions\s*$/i.test(String(line).trim());
}

function isEmptyNotesPlaceholder(text) {
  return /_No CHANGELOG\.md updates in this version cut\._/i.test(text);
}

function emptyBuckets(order) {
  return Object.fromEntries(order.map((key) => [key, []]));
}

function ensurePackage(map, name, order) {
  if (!map.has(name)) {
    map.set(name, { name, buckets: emptyBuckets(order) });
  }
  return map.get(name);
}

function isTopLevelBullet(line) {
  const t = String(line).replace(/\r$/, "");
  return /^[-*]\s/.test(t) && !/^\s/.test(t);
}

function isIndentedBullet(line) {
  return /^\s{2,}[-*]\s/.test(String(line));
}

function packageBulletName(line) {
  const m = String(line).match(/^[-*]\s+\*\*(.+?)\*\*\s*$/);
  return m ? m[1].trim() : null;
}

function stripListMarker(line) {
  return String(line).replace(/^\s*[-*]\s+/, "");
}

function splitTopLevelBulletBlocks(lines) {
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

function splitIndentedBulletBlocks(lines) {
  const blocks = [];
  let i = 0;
  while (i < lines.length) {
    while (i < lines.length && String(lines[i]).trim() === "") i += 1;
    if (i >= lines.length) break;
    if (!isIndentedBullet(lines[i])) {
      i += 1;
      continue;
    }
    const block = [];
    while (i < lines.length) {
      const line = lines[i];
      if (line === undefined) break;
      if (isIndentedBullet(line) && block.length > 0) break;
      if (block.length === 0 && !isIndentedBullet(line)) break;
      if (isTopLevelBullet(line)) break;
      block.push(line);
      i += 1;
    }
    if (block.length > 0) {
      const normalized = block.map((ln, idx) => {
        if (idx === 0) return `- ${stripListMarker(ln)}`;
        if (ln.trim() === "") return "";
        return `  ${ln.trimStart()}`;
      });
      blocks.push(normalized);
    }
  }
  return blocks;
}

function bulletKey(block) {
  if (!block || block.length === 0) return "";
  return stripListMarker(block[0]).trim();
}

function appendUniqueBlocks(target, blocks) {
  const seen = new Set(target.map(bulletKey));
  for (const block of blocks) {
    const key = bulletKey(block);
    if (!key || seen.has(key)) continue;
    seen.add(key);
    target.push(block);
  }
}

function classifySectionHeading(line, grouping) {
  if (grouping === "bump-type") return classifyBumpHeading(line);
  return classifyCategoryHeading(line);
}

/**
 * Parse one RC notes file into package buckets + published versions.
 * Accepts both package-then-category and category-then-package layouts.
 */
function parseRcNotes(content, order, grouping) {
  const packages = new Map();
  const published = [];
  if (isEmptyNotesPlaceholder(content)) {
    return { packages, published };
  }

  const lines = content.replace(/\r\n/g, "\n").split("\n");
  let i = 0;
  let currentPackage = null;
  let currentCategory = null;

  const flushCategoryBlocks = (pkgName, cat, segmentLines) => {
    if (!pkgName || !cat || !order.includes(cat)) return;
    const pkg = ensurePackage(packages, pkgName, order);
    const blocks = splitTopLevelBulletBlocks(segmentLines);
    appendUniqueBlocks(pkg.buckets[cat], blocks);
  };

  const flushNestedPackageBlocks = (cat, segmentLines) => {
    if (!cat || !order.includes(cat)) return;
    let j = 0;
    while (j < segmentLines.length) {
      while (j < segmentLines.length && String(segmentLines[j]).trim() === "") j += 1;
      if (j >= segmentLines.length) break;
      const pkgName = packageBulletName(segmentLines[j]);
      if (!pkgName) {
        j += 1;
        continue;
      }
      j += 1;
      const nested = [];
      while (j < segmentLines.length) {
        const line = segmentLines[j];
        if (packageBulletName(line)) break;
        if (isTopLevelBullet(line) && !packageBulletName(line)) break;
        nested.push(line);
        j += 1;
      }
      const pkg = ensurePackage(packages, pkgName, order);
      appendUniqueBlocks(pkg.buckets[cat], splitIndentedBulletBlocks(nested));
    }
  };

  while (i < lines.length) {
    const line = lines[i];
    const level = headingLevel(line);

    if (isPublishedVersionsHeading(line)) {
      i += 1;
      while (i < lines.length && headingLevel(lines[i]) === 0) {
        const m = String(lines[i]).match(/^[-*]\s+`([^`]+)`\s*$/);
        if (m) published.push(m[1]);
        i += 1;
      }
      continue;
    }

    if (level >= 2 && /^##\s+\S/.test(line) && !isPublishedVersionsHeading(line)) {
      // Skip stray ## headings (e.g. legacy RC ids if re-rolled).
      i += 1;
      continue;
    }

    if (level === 3 || level === 4) {
      const section = classifySectionHeading(line, grouping);
      if (section) {
        if (level === 3 && currentPackage === null) {
          // category-then-package: ### Category
          currentCategory = section;
          i += 1;
          const segment = [];
          while (i < lines.length) {
            const lvl = headingLevel(lines[i]);
            if (lvl > 0 && lvl <= 3) break;
            if (isPublishedVersionsHeading(lines[i])) break;
            segment.push(lines[i]);
            i += 1;
          }
          flushNestedPackageBlocks(currentCategory, segment);
          currentCategory = null;
          continue;
        }
        if (currentPackage !== null) {
          // package-then-category: #### Category under ### package
          currentCategory = section;
          i += 1;
          const segment = [];
          while (i < lines.length) {
            const lvl = headingLevel(lines[i]);
            if (lvl > 0 && lvl <= 4) break;
            if (isPublishedVersionsHeading(lines[i])) break;
            segment.push(lines[i]);
            i += 1;
          }
          flushCategoryBlocks(currentPackage, currentCategory, segment);
          currentCategory = null;
          continue;
        }
      }

      if (level === 3 && !section) {
        // package-then-category: ### @scope/name
        currentPackage = String(line).replace(/^###\s+/, "").trim();
        currentCategory = null;
        i += 1;
        continue;
      }
    }

    i += 1;
  }

  return { packages, published };
}

function demoteHeading(title) {
  return String(title).replace(/^###\s/, "#### ");
}

function emitTopLevelBullets(blocks) {
  const out = [];
  for (const block of blocks) {
    if (!block || block.length === 0) continue;
    out.push(...block);
  }
  return out;
}

function emitNestedUnderPackage(blocks) {
  const out = [];
  for (const block of blocks) {
    if (!block || block.length === 0) continue;
    out.push(`  - ${stripListMarker(block[0])}`);
    for (let k = 1; k < block.length; k += 1) {
      const ln = block[k];
      if (ln === "") {
        out.push("");
        continue;
      }
      out.push(`    ${String(ln).trimStart()}`);
    }
  }
  return out;
}

function emitCategoryThenPackage(packages, order, titles) {
  const lines = [];
  const sorted = [...packages.values()].sort((a, b) =>
    a.name.localeCompare(b.name, "en"),
  );
  for (const cat of order) {
    const withBlocks = sorted.filter((p) => p.buckets[cat]?.length > 0);
    if (withBlocks.length === 0) continue;
    lines.push(titles[cat], "");
    for (const pkg of withBlocks) {
      lines.push(`- **${pkg.name}**`);
      lines.push(...emitNestedUnderPackage(pkg.buckets[cat]));
      lines.push("");
    }
  }
  return lines;
}

function emitPackageThenCategory(packages, order, titles) {
  const lines = [];
  const sorted = [...packages.values()].sort((a, b) =>
    a.name.localeCompare(b.name, "en"),
  );
  for (const pkg of sorted) {
    const cats = order.filter((cat) => pkg.buckets[cat]?.length > 0);
    if (cats.length === 0) continue;
    lines.push(`### ${pkg.name}`, "");
    for (const cat of cats) {
      lines.push(demoteHeading(titles[cat]), "");
      lines.push(...emitTopLevelBullets(pkg.buckets[cat]));
      lines.push("");
    }
  }
  return lines;
}

function mergePublishedVersions(existing, next) {
  // Later RCs win for the same package name (left of @).
  const byName = new Map();
  for (const entry of existing) {
    const name = entry.includes("@")
      ? entry.slice(0, entry.lastIndexOf("@"))
      : entry;
    byName.set(name, entry);
  }
  for (const entry of next) {
    const name = entry.includes("@")
      ? entry.slice(0, entry.lastIndexOf("@"))
      : entry;
    byName.set(name, entry);
  }
  return [...byName.values()].sort((a, b) => a.localeCompare(b, "en"));
}

async function main() {
  const cycleDir = process.argv[2];
  if (!cycleDir) {
    fail("usage: rollupReleaseNotes.mjs <.releases/cycle-id> [outfile]");
  }
  if (
    NESTING !== "package-then-category" &&
    NESTING !== "category-then-package"
  ) {
    fail(
      `invalid RELEASE_NOTES_NESTING "${NESTING}" ` +
        `(expected package-then-category or category-then-package)`,
    );
  }
  if (GROUPING !== "category" && GROUPING !== "bump-type") {
    fail(
      `invalid RELEASE_NOTES_GROUPING "${GROUPING}" (expected category or bump-type)`,
    );
  }

  const absCycleDir = path.resolve(cycleDir);
  const cycleId = path.basename(absCycleDir);
  const outPath =
    process.argv[3] ?? path.join(absCycleDir, "release-notes.md");

  const rcNotes = listRcNotesPaths(path.dirname(absCycleDir), cycleId);
  if (rcNotes.length === 0) {
    fail(`no rc*/release-notes.md files found under ${absCycleDir}`);
  }

  let order;
  let titles;
  if (GROUPING === "bump-type") {
    order = BUMP_TYPE_ORDER;
    titles = BUMP_TYPE_TITLES;
  } else {
    const prefixes = await loadCategoryPrefixes();
    order = prefixes.CATEGORY_ORDER;
    titles = prefixes.CATEGORY_SECTION_TITLE;
  }

  const merged = new Map();
  let published = [];

  for (const { notesPath } of rcNotes) {
    const body = fs.readFileSync(notesPath, "utf8");
    const parsed = parseRcNotes(body, order, GROUPING);
    for (const [name, pkg] of parsed.packages) {
      const target = ensurePackage(merged, name, order);
      for (const cat of order) {
        appendUniqueBlocks(target.buckets[cat], pkg.buckets[cat]);
      }
    }
    published = mergePublishedVersions(published, parsed.published);
  }

  const lines =
    NESTING === "category-then-package"
      ? emitCategoryThenPackage(merged, order, titles)
      : emitPackageThenCategory(merged, order, titles);

  if (published.length > 0) {
    lines.push("## Published versions", "");
    for (const entry of published) {
      lines.push(`- \`${entry}\``);
    }
    lines.push("");
  }

  if (lines.length === 0) {
    lines.push("_No CHANGELOG.md updates in this release cycle._", "");
  }

  const content = `${lines.join("\n").replace(/\n{3,}/g, "\n\n").trimEnd()}\n`;
  fs.writeFileSync(outPath, content, "utf8");
  process.stdout.write(`${outPath}\n`);
}

main().catch((err) => {
  process.stderr.write(
    `rollupReleaseNotes: ${err instanceof Error ? err.message : err}\n`,
  );
  process.exit(1);
});
