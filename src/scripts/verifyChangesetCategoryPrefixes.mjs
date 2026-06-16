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
