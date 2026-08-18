#!/usr/bin/env node
/**
 * Set promotedAt on cycle.yml and write release-notes.md (ADR 0041).
 *
 * When STABLE_RELEASE_NOTES_CHANGELOG_PATHS is set (comma-separated CHANGELOG paths
 * after ADR 0043 pre-exit), formats cycle release-notes.md from stable changelogs.
 * Otherwise rolls up per-RC release-notes.md files.
 *
 * Usage: node finalizeReleaseCycle.mjs <.releases/cycle-id>
 */
import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import {
  hasPromotedAt,
  parseYamlScalar,
  utcIsoTimestamp,
} from "./lib/releaseCycle.mjs";

const SCRIPT_DIR = path.dirname(fileURLToPath(import.meta.url));

function fail(msg) {
  process.stderr.write(`finalizeReleaseCycle: ${msg}\n`);
  process.exit(1);
}

function yamlQuote(value) {
  if (/^[a-zA-Z0-9._:-]+$/.test(value)) return value;
  return JSON.stringify(value);
}

function parseStableChangelogPaths() {
  if (process.env.STABLE_RELEASE_NOTES_CHANGELOG_PATHS === undefined) {
    return null;
  }
  return process.env.STABLE_RELEASE_NOTES_CHANGELOG_PATHS.split(",")
    .map((entry) => entry.trim())
    .filter(Boolean);
}

function resolveFormatterScript() {
  const override = process.env.FORMAT_CHANGESETS_BATCH_RELEASE_NOTES_SCRIPT;
  if (override && fs.existsSync(override)) return override;
  const sibling = path.join(
    SCRIPT_DIR,
    "formatChangesetsBatchReleaseNotes.mjs",
  );
  if (fs.existsSync(sibling)) return sibling;
  fail(
    "STABLE_RELEASE_NOTES_CHANGELOG_PATHS set but FORMAT_CHANGESETS_BATCH_RELEASE_NOTES_SCRIPT " +
      "not set and formatChangesetsBatchReleaseNotes.mjs not found",
  );
}

function writeStableReleaseNotes(cycleDir, changelogPaths) {
  const outPath = path.join(cycleDir, "release-notes.md");
  if (changelogPaths.length === 0) {
    fs.writeFileSync(
      outPath,
      "_No CHANGELOG.md updates in the stable version cut._\n",
      "utf8",
    );
    return;
  }
  const formatter = resolveFormatterScript();
  const result = spawnSync(
    process.execPath,
    [formatter, outPath, ...changelogPaths],
    {
      encoding: "utf8",
      env: {
        ...process.env,
        RELEASE_NOTES_GROUPING:
          process.env.RELEASE_NOTES_GROUPING ?? "category",
        RELEASE_NOTES_NESTING:
          process.env.RELEASE_NOTES_NESTING ?? "package-then-category",
      },
    },
  );
  if (result.status !== 0) {
    const detail = result.stderr?.trim() || result.stdout?.trim() || "unknown";
    fail(`failed to format stable cycle release-notes.md: ${detail}`);
  }
}

function rollupReleaseNotes(cycleDir) {
  const rollupScript =
    process.env.ROLLUP_RELEASE_NOTES_SCRIPT ??
    path.join(SCRIPT_DIR, "rollupReleaseNotes.mjs");
  const result = spawnSync(process.execPath, [rollupScript, cycleDir], {
    encoding: "utf8",
  });
  if (result.status !== 0) {
    if (result.error) process.stderr.write(`${result.error.message}\n`);
    process.stderr.write(result.stderr ?? "");
    process.exit(result.status ?? 1);
  }
}

function main() {
  const cycleDir = process.argv[2];
  if (!cycleDir) {
    fail("usage: finalizeReleaseCycle.mjs <.releases/cycle-id>");
  }
  const abs = path.resolve(cycleDir);
  const cycleYml = path.join(abs, "cycle.yml");
  if (!fs.existsSync(cycleYml)) {
    fail(`missing ${cycleYml}`);
  }

  const text = fs.readFileSync(cycleYml, "utf8");
  const release = parseYamlScalar("release", text);
  const openedAt = parseYamlScalar("openedAt", text);
  const predecessorCycle = parseYamlScalar("predecessorCycle", text);
  if (!release) fail(`${cycleYml}: missing release field`);

  const stableChangelogPaths = parseStableChangelogPaths();
  if (stableChangelogPaths !== null) {
    writeStableReleaseNotes(abs, stableChangelogPaths);
  } else {
    rollupReleaseNotes(abs);
  }

  const alreadyPromoted = hasPromotedAt(text);
  const promotedAt = alreadyPromoted
    ? parseYamlScalar("promotedAt", text)
    : utcIsoTimestamp(process.env.UTC_TIMESTAMP_OVERRIDE);
  if (!alreadyPromoted) {
    const lines = [
      `release: ${yamlQuote(release)}`,
      `openedAt: ${yamlQuote(openedAt)}`,
      `promotedAt: ${yamlQuote(promotedAt)}`,
    ];
    if (predecessorCycle) {
      lines.splice(2, 0, `predecessorCycle: ${yamlQuote(predecessorCycle)}`);
    }
    lines.push("");
    fs.writeFileSync(cycleYml, lines.join("\n"), "utf8");
  }

  process.stdout.write(`CYCLE_YML=${cycleYml}\n`);
  process.stdout.write(`RELEASE_NOTES_PATH=${path.join(abs, "release-notes.md")}\n`);
  process.stdout.write(`PROMOTED_AT=${promotedAt}\n`);
}

main();
