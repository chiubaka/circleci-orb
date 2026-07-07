#!/usr/bin/env node
/**
 * Write .releases/<cycle-id>/ tree after changeset version (ADR 0041, ADR 0042).
 *
 * Env:
 *   DEPLOYABLE_PACKAGES — comma-separated key=relative-path
 *   MANIFEST_TRAIN_TAG_PREFIX — remote tag prefix when allocating cycle N (default release/)
 *   UTC_DATE_OVERRIDE — test hook for calendar date (YYYY.MM.DD)
 *   UTC_TIMESTAMP_OVERRIDE — test hook for ISO timestamps
 *   RELEASES_DIR — default .releases
 *   RC_NOTES_CHANGELOG_PATHS — optional comma-separated CHANGELOG paths for rc notes
 *   FORMAT_CHANGESETS_BATCH_RELEASE_NOTES_SCRIPT — formatter module path
 *   RELEASE_NOTES_GROUPING — category | bump-type
 */
import fs from "node:fs";
import path from "node:path";
import { execSync, spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import {
  resolveCutPlan,
  resolveLatestProdCycleId,
  utcCalendarDateStr,
  utcIsoTimestamp,
} from "./lib/releaseCycle.mjs";

const SCRIPT_DIR = path.dirname(fileURLToPath(import.meta.url));

function fail(msg) {
  process.stderr.write(`writeReleaseCycle: ${msg}\n`);
  process.exit(1);
}

function parseDeployablePackages(raw) {
  if (!raw?.trim()) {
    fail(
      "DEPLOYABLE_PACKAGES is required when CREATE_RELEASE_MANIFEST is true (format: key=path,key2=path2).",
    );
  }
  const entries = [];
  for (const part of raw.split(",")) {
    const trimmed = part.trim();
    if (!trimmed) continue;
    const eq = trimmed.indexOf("=");
    if (eq < 1) {
      fail(`invalid deployable entry "${trimmed}"; expected key=relative/path`);
    }
    const key = trimmed.slice(0, eq).trim();
    const pkgPath = trimmed.slice(eq + 1).trim();
    if (!key || !pkgPath) {
      fail(`invalid deployable entry "${trimmed}"; expected key=relative/path`);
    }
    entries.push({ key, pkgPath });
  }
  if (entries.length === 0) {
    fail("DEPLOYABLE_PACKAGES parsed to zero deployables.");
  }
  return entries;
}

function resolvePackageJsonPath(pkgPath) {
  const abs = path.resolve(pkgPath);
  if (fs.existsSync(abs) && fs.statSync(abs).isDirectory()) {
    return path.join(abs, "package.json");
  }
  if (!abs.endsWith("package.json") && fs.existsSync(`${abs}/package.json`)) {
    return `${abs}/package.json`;
  }
  return abs;
}

function readPackageVersion(pkgPath) {
  const pkgJsonPath = resolvePackageJsonPath(pkgPath);
  if (!fs.existsSync(pkgJsonPath)) {
    fail(`package.json not found at ${pkgPath}`);
  }
  let data;
  try {
    data = JSON.parse(fs.readFileSync(pkgJsonPath, "utf8"));
  } catch (error) {
    fail(`failed to parse ${pkgJsonPath}: ${error.message}`);
  }
  const version = data.version;
  if (!version || typeof version !== "string") {
    fail(`package.json at ${pkgJsonPath} missing string "version"`);
  }
  return version;
}

function gitLsRemoteTags() {
  try {
    return execSync("git ls-remote --tags origin", {
      encoding: "utf8",
      stdio: ["ignore", "pipe", "pipe"],
    });
  } catch (error) {
    const detail =
      error.stderr?.toString?.().trim() ||
      error.message ||
      "unknown error";
    fail(
      `git ls-remote --tags origin failed (${detail}); cannot allocate cycle id safely.`,
    );
  }
}

function yamlQuote(value) {
  if (/^[a-zA-Z0-9._:-]+$/.test(value)) return value;
  return JSON.stringify(value);
}

function discoverChangelogPaths() {
  try {
    const diff = execSync("git diff --name-only", { encoding: "utf8" });
    const untracked = execSync("git ls-files --others --exclude-standard", {
      encoding: "utf8",
    });
    const paths = new Set();
    for (const line of `${diff}\n${untracked}`.split("\n")) {
      const trimmed = line.trim();
      if (trimmed.endsWith("/CHANGELOG.md") || trimmed === "CHANGELOG.md") {
        paths.add(trimmed);
      }
    }
    return [...paths].sort();
  } catch {
    return [];
  }
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
    "FORMAT_CHANGESETS_BATCH_RELEASE_NOTES_SCRIPT not set and formatChangesetsBatchReleaseNotes.mjs not found",
  );
}

function writeRcNotes(outPath, changelogPaths) {
  if (changelogPaths.length === 0) {
    fs.writeFileSync(
      outPath,
      "_No CHANGELOG.md updates in this version cut._\n",
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
      },
    },
  );
  if (result.status !== 0) {
    const detail = result.stderr?.trim() || result.stdout?.trim() || "unknown";
    fail(`failed to format rc notes: ${detail}`);
  }
}

function renderCycleYml(cycleId, openedAt, predecessorCycle) {
  const lines = [
    `release: ${yamlQuote(cycleId)}`,
    `openedAt: ${yamlQuote(openedAt)}`,
  ];
  if (predecessorCycle) {
    lines.push(`predecessorCycle: ${yamlQuote(predecessorCycle)}`);
  }
  lines.push("");
  return lines.join("\n");
}

function renderRcManifest(cycleId, rcIndex, cutAt, artifacts) {
  const lines = [
    `release: ${yamlQuote(cycleId)}`,
    `rc: ${rcIndex}`,
    `cutAt: ${yamlQuote(cutAt)}`,
    "",
    "artifacts:",
  ];
  for (const [key, tag] of Object.entries(artifacts).sort(([a], [b]) =>
    a.localeCompare(b),
  )) {
    lines.push(`  ${key}: ${yamlQuote(tag)}`);
  }
  lines.push("");
  return lines.join("\n");
}

function main() {
  const deployables = parseDeployablePackages(process.env.DEPLOYABLE_PACKAGES);
  const prefix = process.env.MANIFEST_TRAIN_TAG_PREFIX ?? "release/";
  const releasesDir = process.env.RELEASES_DIR ?? ".releases";
  const dateStr = utcCalendarDateStr(process.env.UTC_DATE_OVERRIDE);
  const timestamp = utcIsoTimestamp(process.env.UTC_TIMESTAMP_OVERRIDE);
  const lsRemote = gitLsRemoteTags();

  const plan = resolveCutPlan({
    releasesDir,
    prefix,
    dateStr,
    lsRemoteText: lsRemote,
  });

  const artifacts = {};
  for (const { key, pkgPath } of deployables) {
    const version = readPackageVersion(pkgPath);
    artifacts[key] = `${key}-v${version}`;
  }

  const cycleDir = path.join(releasesDir, plan.cycleId);
  const rcDir = path.join(cycleDir, `rc${plan.rcIndex}`);
  fs.mkdirSync(rcDir, { recursive: true });

  if (plan.isNewCycle) {
    const predecessorCycle = resolveLatestProdCycleId(lsRemote);
    fs.writeFileSync(
      path.join(cycleDir, "cycle.yml"),
      renderCycleYml(plan.cycleId, timestamp, predecessorCycle),
      "utf8",
    );
  }

  const manifestPath = path.join(rcDir, "manifest.yml");
  fs.writeFileSync(
    manifestPath,
    renderRcManifest(plan.cycleId, plan.rcIndex, timestamp, artifacts),
    "utf8",
  );

  const changelogPaths = process.env.RC_NOTES_CHANGELOG_PATHS
    ? process.env.RC_NOTES_CHANGELOG_PATHS.split(",")
        .map((entry) => entry.trim())
        .filter(Boolean)
    : discoverChangelogPaths();
  const notesPath = path.join(rcDir, "notes.md");
  writeRcNotes(notesPath, changelogPaths);

  process.stdout.write(`${manifestPath}\n`);
  process.stdout.write(`RELEASE_ID=${plan.cycleId}\n`);
  process.stdout.write(`RC_INDEX=${plan.rcIndex}\n`);
  process.stdout.write(`RC_NOTES_PATH=${notesPath}\n`);
}

main();
