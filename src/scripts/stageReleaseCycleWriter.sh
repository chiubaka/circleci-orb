#!/usr/bin/env bash
# Materialize release cycle scripts for CircleCI consumers (orb packs this script;
# sibling .mjs files are not on disk in the client repo). Keep heredoc bodies in sync with
# writeReleaseCycle.mjs, lib/releaseCycle.mjs, lib/trainId.mjs, and related release-cycle modules.
set -euo pipefail

stage_dir=${WRITE_RELEASE_CYCLE_STAGE_DIR:-/tmp/chiubaka-release-cycle}
mkdir -p "${stage_dir}/lib"
cat >"${stage_dir}/lib/releaseCycle.mjs" <<'CHIUBAKA_ORB_LIB_RELEASE_CYCLE_V1_EOF'
#!/usr/bin/env node
/**
 * Release cycle and RC allocation (ADR 0041, ADR 0042).
 */
import fs from "node:fs";
import path from "node:path";
import { execFileSync } from "node:child_process";
import {
  maxNFromLsRemoteForDate,
  regexEscapeBasic,
  utcCalendarDateStr,
} from "./trainId.mjs";

const CYCLE_ID_RE = /^[0-9]{4}\.[0-9]{2}\.[0-9]{2}\.[0-9]+$/;

export function utcIsoTimestamp(override) {
  if (override) return override;
  return new Date().toISOString().replace(/\.\d{3}Z$/, "Z");
}

export function parseYamlScalar(key, text) {
  const re = new RegExp(`^${key}:\\s*(.+)$`, "m");
  const m = text.match(re);
  if (!m) return undefined;
  let value = m[1].trim();
  if (
    (value.startsWith('"') && value.endsWith('"')) ||
    (value.startsWith("'") && value.endsWith("'"))
  ) {
    value = value.slice(1, -1);
  }
  return value;
}

export function hasPromotedAt(cycleYmlText) {
  const value = parseYamlScalar("promotedAt", cycleYmlText);
  return Boolean(value?.trim());
}

export function findOpenCycles(releasesDir) {
  if (!fs.existsSync(releasesDir)) return [];
  const open = [];
  for (const entry of fs.readdirSync(releasesDir, { withFileTypes: true })) {
    if (!entry.isDirectory() || !CYCLE_ID_RE.test(entry.name)) continue;
    const cycleYml = path.join(releasesDir, entry.name, "cycle.yml");
    if (!fs.existsSync(cycleYml)) continue;
    const text = fs.readFileSync(cycleYml, "utf8");
    if (!hasPromotedAt(text)) open.push(entry.name);
  }
  return open.sort();
}

export function maxRcIndexInCycle(releasesDir, cycleId) {
  const cyclePath = path.join(releasesDir, cycleId);
  if (!fs.existsSync(cyclePath)) return 0;
  let max = 0;
  for (const entry of fs.readdirSync(cyclePath, { withFileTypes: true })) {
    if (!entry.isDirectory()) continue;
    const match = entry.name.match(/^rc([0-9]+)$/);
    if (match) {
      max = Math.max(max, Number.parseInt(match[1], 10));
    }
  }
  return max;
}

export function maxCycleNFromReleasesDir(releasesDir, dateStr) {
  if (!fs.existsSync(releasesDir)) return 0;
  let maxN = 0;
  const prefix = `${dateStr}.`;
  for (const entry of fs.readdirSync(releasesDir, { withFileTypes: true })) {
    if (!entry.isDirectory() || !entry.name.startsWith(prefix)) continue;
    if (!CYCLE_ID_RE.test(entry.name)) continue;
    const nStr = entry.name.slice(prefix.length);
    const n = Number.parseInt(nStr, 10);
    if (Number.isFinite(n) && n > maxN) maxN = n;
  }
  return maxN;
}

function maxNFromTagLines(lsRemoteText, tagPrefix, dateStr) {
  let maxN = maxNFromLsRemoteForDate(lsRemoteText, tagPrefix, dateStr);
  const escapedDate = regexEscapeBasic(dateStr);
  const escapedPrefix = regexEscapeBasic(tagPrefix);
  const pattern = new RegExp(
    `^${escapedPrefix}${escapedDate}\\.([0-9]+)(?:-rc[0-9]+)?$`,
  );
  for (const line of lsRemoteText.split("\n")) {
    if (!line.trim()) continue;
    const parts = line.trim().split(/\s+/);
    const ref = parts[1];
    if (!ref?.startsWith("refs/tags/")) continue;
    let name = ref.slice("refs/tags/".length);
    if (name.includes("^")) name = name.slice(0, name.indexOf("^"));
    const match = name.match(pattern);
    if (!match) continue;
    const n = Number.parseInt(match[1], 10);
    if (Number.isFinite(n) && n > maxN) maxN = n;
  }
  return maxN;
}

export function computeNextCycleId(releasesDir, prefix, dateStr, lsRemoteText) {
  const maxN = Math.max(
    maxNFromTagLines(lsRemoteText, prefix, dateStr),
    maxNFromTagLines(lsRemoteText, "prod-", dateStr),
    maxNFromTagLines(lsRemoteText, "staging-", dateStr),
    maxCycleNFromReleasesDir(releasesDir, dateStr),
  );
  return `${dateStr}.${maxN + 1}`;
}

export function compareCycleIds(a, b) {
  return a.localeCompare(b, undefined, { numeric: true });
}

export function resolveLatestProdCycleId(lsRemoteText) {
  let latest = null;
  const pattern = /refs\/tags\/prod-([0-9]{4}\.[0-9]{2}\.[0-9]{2}\.[0-9]+)/;
  for (const line of lsRemoteText.split("\n")) {
    const match = line.match(pattern);
    if (!match) continue;
    const cycleId = match[1];
    if (!latest || compareCycleIds(cycleId, latest) > 0) latest = cycleId;
  }
  return latest;
}

/**
 * @returns {{ cycleId: string, rcIndex: number, isNewCycle: boolean }}
 */
export function resolveCutPlan({
  releasesDir,
  prefix,
  dateStr,
  getLsRemoteText,
}) {
  const open = findOpenCycles(releasesDir);
  if (open.length > 1) {
    throw new Error(
      `multiple open release cycles without promotedAt (${open.join(", ")}); promote or close one before versioning`,
    );
  }
  if (open.length === 1) {
    const cycleId = open[0];
    const rcIndex = maxRcIndexInCycle(releasesDir, cycleId) + 1;
    const rcDir = path.join(releasesDir, cycleId, `rc${rcIndex}`);
    if (fs.existsSync(rcDir)) {
      throw new Error(
        `RC directory already exists at ${rcDir}; each RC directory is created once`,
      );
    }
    return { cycleId, rcIndex, isNewCycle: false };
  }

  const lsRemoteText = getLsRemoteText();
  const cycleId = computeNextCycleId(releasesDir, prefix, dateStr, lsRemoteText);
  const cycleDir = path.join(releasesDir, cycleId);
  if (fs.existsSync(cycleDir)) {
    throw new Error(
      `cycle directory ${cycleDir} already exists but is not an open cycle; fix cycle.yml promotedAt or directory state`,
    );
  }
  return { cycleId, rcIndex: 1, isNewCycle: true };
}

export function listRcNotesPaths(releasesDir, cycleId) {
  const cyclePath = path.join(releasesDir, cycleId);
  if (!fs.existsSync(cyclePath)) return [];
  const rcDirs = fs
    .readdirSync(cyclePath, { withFileTypes: true })
    .filter((entry) => entry.isDirectory() && /^rc[0-9]+$/.test(entry.name))
    .map((entry) => ({
      index: Number.parseInt(entry.name.slice(2), 10),
      notesPath: path.join(cyclePath, entry.name, "release-notes.md"),
    }))
    .filter((entry) => fs.existsSync(entry.notesPath))
    .sort((a, b) => a.index - b.index);
  return rcDirs;
}

export function resolveHighestRcIndex(releasesDir, cycleId) {
  return maxRcIndexInCycle(releasesDir, cycleId);
}

export function resolveCycleOnCommit(releasesDir) {
  if (!fs.existsSync(releasesDir)) return null;
  const cycles = fs
    .readdirSync(releasesDir, { withFileTypes: true })
    .filter((entry) => entry.isDirectory() && CYCLE_ID_RE.test(entry.name))
    .map((entry) => entry.name);
  if (cycles.length === 0) return null;
  if (cycles.length === 1) {
    const cycleId = cycles[0];
    const rcIndex = resolveHighestRcIndex(releasesDir, cycleId);
    if (rcIndex < 1) return null;
    return { cycleId, rcIndex };
  }

  let best = null;
  for (const cycleId of cycles) {
    const rcIndex = resolveHighestRcIndex(releasesDir, cycleId);
    if (rcIndex < 1) continue;
    if (!best || compareCycleIds(cycleId, best.cycleId) > 0) {
      best = { cycleId, rcIndex };
    }
  }
  return best;
}

function gitLsTreeDirNames(sha, treePath) {
  try {
    const out = execFileSync(
      "git",
      ["ls-tree", "-d", "--name-only", `${sha}:${treePath}`],
      {
        encoding: "utf8",
        stdio: ["ignore", "pipe", "pipe"],
      },
    );
    return out
      .split("\n")
      .map((entry) => entry.trim())
      .filter(Boolean);
  } catch {
    return [];
  }
}

export function resolveCycleOnCommitAtSha(releasesDir, sha) {
  const cycleNames = gitLsTreeDirNames(sha, releasesDir).filter((name) =>
    CYCLE_ID_RE.test(name),
  );
  if (cycleNames.length === 0) return null;

  let best = null;
  for (const cycleId of cycleNames) {
    const rcNames = gitLsTreeDirNames(sha, `${releasesDir}/${cycleId}`).filter(
      (name) => /^rc[0-9]+$/.test(name),
    );
    let maxRc = 0;
    for (const rcName of rcNames) {
      maxRc = Math.max(maxRc, Number.parseInt(rcName.slice(2), 10));
    }
    if (maxRc < 1) continue;
    if (!best || compareCycleIds(cycleId, best.cycleId) > 0) {
      best = { cycleId, rcIndex: maxRc };
    }
  }
  return best;
}

export { CYCLE_ID_RE, utcCalendarDateStr };

CHIUBAKA_ORB_LIB_RELEASE_CYCLE_V1_EOF
cat >"${stage_dir}/lib/trainId.mjs" <<'CHIUBAKA_ORB_LIB_TRAIN_ID_MJS_V1_EOF'
#!/usr/bin/env node
/**
 * UTC calendar train id allocator (ADR 0037): YYYY.MM.DD.N from remote tag scan.
 * Shared by GitHub release train, release manifests, and promotion tags.
 */
import { execSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";

export function utcCalendarDateStr(override) {
  if (override) return override;
  const d = new Date();
  const y = d.getUTCFullYear();
  const m = String(d.getUTCMonth() + 1).padStart(2, "0");
  const day = String(d.getUTCDate()).padStart(2, "0");
  return `${y}.${m}.${day}`;
}

export function regexEscapeBasic(str) {
  return str.replace(/[][\\.^$*+?(){}|]/g, "\\$&");
}

/**
 * @param {string} lsRemoteText git ls-remote --tags output
 * @param {string} prefix tag prefix before date (e.g. release/ or staging-)
 * @param {string} dateStr YYYY.MM.DD
 * @returns {number} max N for that date, or 0 if none
 */
export function maxNFromLsRemoteForDate(lsRemoteText, prefix, dateStr) {
  const escapedPrefix = regexEscapeBasic(prefix);
  const escapedDate = regexEscapeBasic(dateStr);
  const pattern = new RegExp(`^${escapedPrefix}${escapedDate}\\.[0-9]+$`);
  let maxN = -1;
  for (const line of lsRemoteText.split("\n")) {
    if (!line.trim()) continue;
    const parts = line.trim().split(/\s+/);
    const ref = parts[1];
    if (!ref || !ref.startsWith("refs/tags/")) continue;
    let name = ref.slice("refs/tags/".length);
    if (name.includes("^")) name = name.slice(0, name.indexOf("^"));
    if (!pattern.test(name)) continue;
    const tagSuffix = name.slice(prefix.length);
    const nStr = tagSuffix.split(".").pop();
    const n = Number.parseInt(nStr, 10);
    if (Number.isFinite(n) && n > maxN) maxN = n;
  }
  return maxN < 0 ? 0 : maxN;
}

export function computeNextTrainIdForDate(prefix, dateStr, lsRemoteText) {
  const maxN = maxNFromLsRemoteForDate(lsRemoteText, prefix, dateStr);
  return `${dateStr}.${maxN + 1}`;
}

function gitLsRemoteTags() {
  try {
    return execSync("git ls-remote --tags origin 2>/dev/null || true", {
      encoding: "utf8",
      stdio: ["ignore", "pipe", "ignore"],
    });
  } catch {
    return "";
  }
}

async function readStdin() {
  const chunks = [];
  for await (const chunk of process.stdin) chunks.push(chunk);
  return Buffer.concat(chunks).toString("utf8");
}

function usage() {
  process.stderr.write(
    "trainId.mjs: max-n --prefix PREFIX --date DATE [--input FILE]\n" +
      "             next-id --prefix PREFIX [--date DATE] [--utc-date-override DATE]\n",
  );
}

async function main() {
  const args = process.argv.slice(2);
  const cmd = args[0];
  if (!cmd || cmd === "-h" || cmd === "--help") {
    usage();
    process.exit(cmd ? 0 : 1);
  }

  const getOpt = (name) => {
    const i = args.indexOf(name);
    return i >= 0 ? args[i + 1] : undefined;
  };

  if (cmd === "max-n") {
    const prefix = getOpt("--prefix") ?? "";
    const dateStr = getOpt("--date");
    if (!dateStr) {
      process.stderr.write("trainId.mjs max-n: --date is required\n");
      process.exit(1);
    }
    const inputFile = getOpt("--input");
    let text;
    if (inputFile) {
      text = readFileSync(inputFile, "utf8");
    } else if (!process.stdin.isTTY) {
      text = await readStdin();
    } else {
      process.stderr.write("trainId.mjs max-n: provide stdin or --input FILE\n");
      process.exit(1);
    }
    process.stdout.write(String(maxNFromLsRemoteForDate(text, prefix, dateStr)));
    return;
  }

  if (cmd === "next-id") {
    const prefix = getOpt("--prefix") ?? "release/";
    const dateStr =
      getOpt("--date") ??
      utcCalendarDateStr(getOpt("--utc-date-override") ?? process.env.UTC_DATE_OVERRIDE);
    const lsRemote = getOpt("--ls-remote-file");
    const text = lsRemote ? readFileSync(lsRemote, "utf8") : gitLsRemoteTags();
    process.stdout.write(computeNextTrainIdForDate(prefix, dateStr, text));
    return;
  }

  usage();
  process.exit(1);
}

const isCli =
  process.argv[1] &&
  path.resolve(process.argv[1]) === path.resolve(fileURLToPath(import.meta.url));

if (isCli) {
  main().catch((err) => {
    process.stderr.write(`${err?.message ?? err}\n`);
    process.exit(1);
  });
}
CHIUBAKA_ORB_LIB_TRAIN_ID_MJS_V1_EOF
cat >"${stage_dir}/writeReleaseCycle.mjs" <<'CHIUBAKA_ORB_WRITE_RELEASE_CYCLE_V1_EOF'
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
 *   ROLLUP_RELEASE_NOTES_SCRIPT — rollup module path
 *   RELEASE_NOTES_GROUPING — category | bump-type
 *   RELEASE_NOTES_NESTING — package-then-category | category-then-package
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
  const error = new Error(msg);
  error.name = "WriteReleaseCycleError";
  throw error;
}

function removePathIfExists(target) {
  if (fs.existsSync(target)) {
    fs.rmSync(target, { recursive: true, force: true });
  }
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
        RELEASE_NOTES_NESTING:
          process.env.RELEASE_NOTES_NESTING ?? "package-then-category",
      },
    },
  );
  if (result.status !== 0) {
    const detail = result.stderr?.trim() || result.stdout?.trim() || "unknown";
    fail(`failed to format rc notes: ${detail}`);
  }
}

function refreshCycleReleaseNotes(cycleDir) {
  const rollupScript =
    process.env.ROLLUP_RELEASE_NOTES_SCRIPT ??
    path.join(SCRIPT_DIR, "rollupReleaseNotes.mjs");
  const result = spawnSync(process.execPath, [rollupScript, cycleDir], {
    encoding: "utf8",
  });
  if (result.status !== 0) {
    const detail = result.stderr?.trim() || result.stdout?.trim() || "unknown";
    fail(`failed to roll up cycle release-notes.md: ${detail}`);
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

  const plan = resolveCutPlan({
    releasesDir,
    prefix,
    dateStr,
    getLsRemoteText: gitLsRemoteTags,
  });

  const artifacts = {};
  for (const { key, pkgPath } of deployables) {
    const version = readPackageVersion(pkgPath);
    artifacts[key] = `${key}-v${version}`;
  }

  const cycleDir = path.join(releasesDir, plan.cycleId);
  const rcDir = path.join(cycleDir, `rc${plan.rcIndex}`);
  const createdNewCycle = plan.isNewCycle && !fs.existsSync(cycleDir);
  let rcArtifactsCommitted = false;

  try {
    fs.mkdirSync(rcDir, { recursive: true });

    if (plan.isNewCycle) {
      const predecessorCycle = resolveLatestProdCycleId(gitLsRemoteTags());
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
    const notesPath = path.join(rcDir, "release-notes.md");
    writeRcNotes(notesPath, changelogPaths);
    refreshCycleReleaseNotes(cycleDir);
    rcArtifactsCommitted = true;

    process.stdout.write(`${manifestPath}\n`);
    process.stdout.write(`RELEASE_ID=${plan.cycleId}\n`);
    process.stdout.write(`RC_INDEX=${plan.rcIndex}\n`);
    process.stdout.write(`RC_NOTES_PATH=${notesPath}\n`);
    process.stdout.write(
      `RELEASE_NOTES_PATH=${path.join(cycleDir, "release-notes.md")}\n`,
    );
  } finally {
    if (!rcArtifactsCommitted) {
      removePathIfExists(rcDir);
      if (createdNewCycle) {
        removePathIfExists(cycleDir);
      }
    }
  }
}

try {
  main();
} catch (error) {
  process.stderr.write(`writeReleaseCycle: ${error.message}\n`);
  process.exit(1);
}

CHIUBAKA_ORB_WRITE_RELEASE_CYCLE_V1_EOF
cat >"${stage_dir}/resolveReleaseCycleOnCommit.mjs" <<'CHIUBAKA_ORB_RESOLVE_RELEASE_CYCLE_ON_COMMIT_V1_EOF'
#!/usr/bin/env node
/**
 * Resolve the release cycle and highest RC on a commit.
 * Usage: node resolveReleaseCycleOnCommit.mjs
 * Env: TARGET_SHA (optional), RELEASES_DIR (default .releases)
 */
import {
  resolveCycleOnCommit,
  resolveCycleOnCommitAtSha,
} from "./lib/releaseCycle.mjs";

const releasesDir = process.env.RELEASES_DIR ?? ".releases";
const sha = process.env.TARGET_SHA?.trim();
const resolved = sha
  ? resolveCycleOnCommitAtSha(releasesDir, sha)
  : resolveCycleOnCommit(releasesDir);
if (!resolved) {
  process.stderr.write(
    `resolveReleaseCycleOnCommit: no .releases/<cycle-id>/rc<n>/ tree found` +
      (sha ? ` at ${sha}` : ` under ${releasesDir}`) +
      "\n",
  );
  process.exit(1);
}

process.stdout.write(`CYCLE_ID=${resolved.cycleId}\n`);
process.stdout.write(`RC_INDEX=${resolved.rcIndex}\n`);
CHIUBAKA_ORB_RESOLVE_RELEASE_CYCLE_ON_COMMIT_V1_EOF
cat >"${stage_dir}/finalizeReleaseCycle.mjs" <<'CHIUBAKA_ORB_FINALIZE_RELEASE_CYCLE_V1_EOF'
#!/usr/bin/env node
/**
 * Set promotedAt on cycle.yml and write release-notes.md (ADR 0041).
 *
 * Always rolls up per-RC release-notes.md files. When STABLE_PACKAGE_VERSIONS is set
 * (name=version pairs after ADR 0043 pre-exit), refreshes existing Published
 * versions entries to those stable semvers without adding packages.
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

/** Stable MAJOR.MINOR.PATCH only (no prerelease suffix). */
function isStableSemver(version) {
  return /^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$/.test(String(version));
}

function parseStablePackageVersions() {
  const raw = process.env.STABLE_PACKAGE_VERSIONS;
  if (!raw?.trim()) return null;
  const versions = new Map();
  for (const part of raw.split(",")) {
    const trimmed = part.trim();
    if (!trimmed) continue;
    const eq = trimmed.indexOf("=");
    if (eq < 1) continue;
    const name = trimmed.slice(0, eq).trim();
    const version = trimmed.slice(eq + 1).trim();
    if (name && isStableSemver(version)) versions.set(name, version);
  }
  return versions.size > 0 ? versions : null;
}

function publishedPackageName(entry) {
  const at = String(entry).lastIndexOf("@");
  if (at <= 0) return "";
  return entry.slice(0, at);
}

function refreshPublishedVersions(notesPath, versions) {
  if (!versions || !fs.existsSync(notesPath)) return;
  const lines = fs.readFileSync(notesPath, "utf8").split("\n");
  let inPublished = false;
  let changed = false;
  const out = [];
  for (const line of lines) {
    if (/^##\s+Published versions\s*$/i.test(line.trim())) {
      inPublished = true;
      out.push(line);
      continue;
    }
    if (inPublished && /^##\s+\S/.test(line.trim())) {
      inPublished = false;
    }
    if (inPublished) {
      const match = line.match(/^[-*]\s+`([^`]+)`\s*$/);
      if (match) {
        const entry = match[1];
        const name = publishedPackageName(entry);
        const version = name ? versions.get(name) : undefined;
        if (version) {
          const next = `${name}@${version}`;
          if (next !== entry) {
            out.push(`- \`${next}\``);
            changed = true;
            continue;
          }
        }
      }
    }
    out.push(line);
  }
  if (changed) {
    fs.writeFileSync(notesPath, out.join("\n"), "utf8");
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

  rollupReleaseNotes(abs);
  const stableVersions = parseStablePackageVersions();
  if (stableVersions) {
    refreshPublishedVersions(path.join(abs, "release-notes.md"), stableVersions);
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

CHIUBAKA_ORB_FINALIZE_RELEASE_CYCLE_V1_EOF
cat >"${stage_dir}/rollupReleaseNotes.mjs" <<'CHIUBAKA_ORB_ROLLUP_RELEASE_NOTES_V1_EOF'
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
 *   ROLLUP_ALLOW_UNPARSED_RELEASE_NOTES — when "true", warn on unparsed lines
 *     instead of failing (default: fail)
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

function classifyCategoryHeading(line, titles) {
  const t = String(line).trim().replace(/^#{1,6}\s+/, "");
  const normalized = t.toLowerCase();
  for (const [key, title] of Object.entries(titles ?? {})) {
    const bare = String(title).replace(/^#+\s*/, "").trim().toLowerCase();
    if (normalized === bare) return key;
  }
  return null;
}

function classifyBumpHeading(line) {
  const t = String(line).trim().replace(/^#{1,6}\s+/, "");
  const m = t.match(/^(Major|Minor|Patch)(?:\s+Changes)?$/i);
  return m ? m[1].toLowerCase() : null;
}

function classifySectionHeading(line, grouping, titles) {
  if (grouping === "bump-type") return classifyBumpHeading(line);
  return classifyCategoryHeading(line, titles);
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
  /** @type {number[]} */
  const consumedOffsets = [];
  let i = 0;
  while (i < lines.length) {
    while (i < lines.length && String(lines[i]).trim() === "") {
      consumedOffsets.push(i);
      i += 1;
    }
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
      consumedOffsets.push(i);
      i += 1;
    }
    if (block.length > 0) blocks.push(block);
  }
  return { blocks, consumedOffsets };
}

function splitIndentedBulletBlocks(lines) {
  const blocks = [];
  /** @type {number[]} */
  const consumedOffsets = [];
  let i = 0;
  while (i < lines.length) {
    while (i < lines.length && String(lines[i]).trim() === "") {
      consumedOffsets.push(i);
      i += 1;
    }
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
      consumedOffsets.push(i);
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
  return { blocks, consumedOffsets };
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

/**
 * Parse one RC notes file into package buckets + published versions.
 * Accepts both package-then-category and category-then-package layouts.
 * @returns {{ packages: Map<string, {name: string, buckets: Record<string, string[][]>}>, published: string[], unparsed: {line: number, text: string}[] }}
 */
function parseRcNotes(content, order, grouping, titles) {
  const packages = new Map();
  const published = [];
  /** @type {Set<number>} */
  const consumed = new Set();
  const mark = (...idxs) => {
    for (const idx of idxs) {
      if (typeof idx === "number" && idx >= 0) consumed.add(idx);
    }
  };
  const markOffsets = (base, offsets) => {
    for (const offset of offsets) mark(base + offset);
  };

  if (isEmptyNotesPlaceholder(content)) {
    return { packages, published, unparsed: [] };
  }

  const lines = content.replace(/\r\n/g, "\n").split("\n");
  let i = 0;
  let currentPackage = null;

  const flushCategoryBlocks = (pkgName, cat, segmentStart, segmentLines) => {
    if (!pkgName || !cat || !order.includes(cat)) return;
    const pkg = ensurePackage(packages, pkgName, order);
    const { blocks, consumedOffsets } = splitTopLevelBulletBlocks(segmentLines);
    appendUniqueBlocks(pkg.buckets[cat], blocks);
    markOffsets(segmentStart, consumedOffsets);
  };

  const flushNestedPackageBlocks = (cat, segmentStart, segmentLines) => {
    if (!cat || !order.includes(cat)) return;
    let j = 0;
    while (j < segmentLines.length) {
      while (j < segmentLines.length && String(segmentLines[j]).trim() === "") {
        mark(segmentStart + j);
        j += 1;
      }
      if (j >= segmentLines.length) break;
      const pkgName = packageBulletName(segmentLines[j]);
      if (!pkgName) {
        j += 1;
        continue;
      }
      mark(segmentStart + j);
      j += 1;
      const nestedStart = j;
      const nested = [];
      while (j < segmentLines.length) {
        const line = segmentLines[j];
        if (packageBulletName(line)) break;
        if (isTopLevelBullet(line) && !packageBulletName(line)) break;
        nested.push(line);
        j += 1;
      }
      const pkg = ensurePackage(packages, pkgName, order);
      const { blocks, consumedOffsets } = splitIndentedBulletBlocks(nested);
      appendUniqueBlocks(pkg.buckets[cat], blocks);
      markOffsets(segmentStart + nestedStart, consumedOffsets);
    }
  };

  while (i < lines.length) {
    const line = lines[i];
    const level = headingLevel(line);

    if (isPublishedVersionsHeading(line)) {
      mark(i);
      i += 1;
      while (i < lines.length && headingLevel(lines[i]) === 0) {
        const m = String(lines[i]).match(/^[-*]\s+`([^`]+)`\s*$/);
        if (m) {
          published.push(m[1]);
          mark(i);
        } else if (String(lines[i]).trim() === "") {
          mark(i);
        }
        i += 1;
      }
      continue;
    }

    if (level >= 2 && /^##\s+\S/.test(line) && !isPublishedVersionsHeading(line)) {
      // Leave unrecognized ## sections unparsed (including following body).
      i += 1;
      continue;
    }

    if (level === 3 || level === 4) {
      const section = classifySectionHeading(line, grouping, titles);
      if (section) {
        if (level === 3 && currentPackage === null) {
          mark(i);
          i += 1;
          const segmentStart = i;
          const segment = [];
          while (i < lines.length) {
            const lvl = headingLevel(lines[i]);
            if (lvl > 0 && lvl <= 3) break;
            if (isPublishedVersionsHeading(lines[i])) break;
            segment.push(lines[i]);
            i += 1;
          }
          flushNestedPackageBlocks(section, segmentStart, segment);
          continue;
        }
        if (currentPackage !== null) {
          mark(i);
          i += 1;
          const segmentStart = i;
          const segment = [];
          while (i < lines.length) {
            const lvl = headingLevel(lines[i]);
            if (lvl > 0 && lvl <= 4) break;
            if (isPublishedVersionsHeading(lines[i])) break;
            segment.push(lines[i]);
            i += 1;
          }
          flushCategoryBlocks(currentPackage, section, segmentStart, segment);
          continue;
        }
      }

      if (level === 3 && !section) {
        currentPackage = String(line).replace(/^###\s+/, "").trim();
        mark(i);
        i += 1;
        continue;
      }
    }

    if (String(line).trim() === "") {
      mark(i);
    }
    i += 1;
  }

  const unparsed = [];
  for (let idx = 0; idx < lines.length; idx += 1) {
    if (consumed.has(idx)) continue;
    if (String(lines[idx]).trim() === "") continue;
    unparsed.push({ line: idx + 1, text: lines[idx] });
  }

  return { packages, published, unparsed };
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
  const allowUnparsed =
    String(process.env.ROLLUP_ALLOW_UNPARSED_RELEASE_NOTES || "")
      .trim()
      .toLowerCase() === "true";
  /** @type {{ path: string, line: number, text: string }[]} */
  const unparsedAll = [];

  for (const { notesPath } of rcNotes) {
    const body = fs.readFileSync(notesPath, "utf8");
    const parsed = parseRcNotes(body, order, GROUPING, titles);
    for (const [name, pkg] of parsed.packages) {
      const target = ensurePackage(merged, name, order);
      for (const cat of order) {
        appendUniqueBlocks(target.buckets[cat], pkg.buckets[cat]);
      }
    }
    published = mergePublishedVersions(published, parsed.published);
    for (const entry of parsed.unparsed) {
      unparsedAll.push({ path: notesPath, ...entry });
    }
  }

  if (unparsedAll.length > 0) {
    const samples = unparsedAll
      .slice(0, 5)
      .map((entry) => `${entry.path}:${entry.line}: ${entry.text.trim()}`)
      .join("\n");
    const detail =
      `unparsed ${unparsedAll.length} line(s) in rc release-notes ` +
      `(would be omitted from cycle Artifact 3). Examples:\n${samples}`;
    if (allowUnparsed) {
      process.stderr.write(`rollupReleaseNotes: warning: ${detail}\n`);
    } else {
      fail(
        `${detail}\nSet ROLLUP_ALLOW_UNPARSED_RELEASE_NOTES=true to warn instead of fail.`,
      );
    }
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
CHIUBAKA_ORB_ROLLUP_RELEASE_NOTES_V1_EOF
cat >"${stage_dir}/validateReleaseCycle.mjs" <<'CHIUBAKA_ORB_VALIDATE_RELEASE_CYCLE_V1_EOF'
#!/usr/bin/env node
/**
 * Validate a release cycle directory (cycle.yml + rc manifests).
 * Usage: node validateReleaseCycle.mjs <.releases/cycle-id>
 */
import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import {
  CYCLE_ID_RE,
  maxRcIndexInCycle,
  parseYamlScalar,
} from "./lib/releaseCycle.mjs";

const SCRIPT_DIR = path.dirname(fileURLToPath(import.meta.url));

function fail(msg) {
  process.stderr.write(`validateReleaseCycle: ${msg}\n`);
  process.exit(1);
}

function resolveValidatorScript() {
  const override = process.env.VALIDATE_RELEASE_MANIFEST_SCRIPT;
  if (override && fs.existsSync(override)) return override;
  const sibling = path.join(SCRIPT_DIR, "validateReleaseManifest.mjs");
  if (fs.existsSync(sibling)) return sibling;
  fail("validateReleaseManifest.mjs not found");
}

function validateCycleYml(cycleDir, cycleId) {
  const cycleYml = path.join(cycleDir, "cycle.yml");
  if (!fs.existsSync(cycleYml)) {
    fail(`${cycleDir}: missing required cycle.yml`);
  }
  const text = fs.readFileSync(cycleYml, "utf8");
  const release = parseYamlScalar("release", text);
  const openedAt = parseYamlScalar("openedAt", text);
  if (!release) fail(`${cycleYml}: missing required field "release"`);
  if (release !== cycleId) {
    fail(
      `${cycleYml}: release field "${release}" must match directory "${cycleId}"`,
    );
  }
  if (!openedAt?.trim()) {
    fail(`${cycleYml}: missing required field "openedAt"`);
  }
}

function main() {
  const cycleDir = process.argv[2];
  if (!cycleDir) {
    fail("usage: validateReleaseCycle.mjs <.releases/cycle-id>");
  }
  const abs = path.resolve(cycleDir);
  const cycleId = path.basename(abs);
  if (!CYCLE_ID_RE.test(cycleId)) {
    fail(`${abs}: cycle directory name must match YYYY.MM.DD.N`);
  }

  validateCycleYml(abs, cycleId);
  const maxRc = maxRcIndexInCycle(path.dirname(abs), cycleId);
  if (maxRc < 1) {
    fail(`${abs}: expected at least rc1/ with manifest.yml`);
  }

  const validator = resolveValidatorScript();
  for (let rc = 1; rc <= maxRc; rc += 1) {
    const rcDir = path.join(abs, `rc${rc}`);
    const manifest = path.join(rcDir, "manifest.yml");
    if (!fs.existsSync(manifest)) {
      fail(`${abs}: missing ${path.relative(abs, manifest)}`);
    }
    const notes = path.join(rcDir, "release-notes.md");
    if (!fs.existsSync(notes)) {
      fail(`${abs}: missing ${path.relative(abs, notes)}`);
    }
    const result = spawnSync(process.execPath, [validator, manifest], {
      encoding: "utf8",
    });
    if (result.status !== 0) {
      process.stderr.write(result.stderr ?? "");
      process.exit(result.status ?? 1);
    }
  }

  const releaseNotes = path.join(abs, "release-notes.md");
  if (!fs.existsSync(releaseNotes)) {
    fail(`${abs}: missing release-notes.md`);
  }

  process.stdout.write(`RELEASE_CYCLE_PATH=${abs}\n`);
  process.stdout.write(`RELEASE_ID=${cycleId}\n`);
  process.stdout.write(`RC_COUNT=${maxRc}\n`);
}

main();

CHIUBAKA_ORB_VALIDATE_RELEASE_CYCLE_V1_EOF
cat >"${stage_dir}/validateReleaseManifest.mjs" <<'CHIUBAKA_ORB_VALIDATE_RELEASE_MANIFEST_V1_EOF'
#!/usr/bin/env node
/**
 * Strict pin-only release manifest validation (ADR 0039, ADR 0042).
 * Usage: node validateReleaseManifest.mjs <path-to-manifest.yml>
 * Exports RELEASE_MANIFEST_PATH, RELEASE_ID, RC_INDEX, ARTIFACTS_JSON on success (stdout).
 */
import fs from "node:fs";
import path from "node:path";
import { CYCLE_ID_RE } from "./lib/releaseCycle.mjs";

const RELEASE_ID_RE = CYCLE_ID_RE;
const RC_MANIFEST_KEYS = new Set(["release", "rc", "cutAt", "artifacts"]);

function fail(msg) {
  process.stderr.write(`validateReleaseManifest: ${msg}\n`);
  process.exit(1);
}

function unquoteYamlScalar(value) {
  if (
    (value.startsWith('"') && value.endsWith('"')) ||
    (value.startsWith("'") && value.endsWith("'"))
  ) {
    return value.slice(1, -1);
  }
  return value;
}

function parsePinOnlyYaml(text, filePath, allowedTopKeys) {
  const lines = text.split(/\r?\n/);
  const doc = {};
  let inArtifacts = false;
  const seenTop = new Set();

  for (let i = 0; i < lines.length; i++) {
    const raw = lines[i];
    const line = raw.replace(/\s+#.*$/, "").trimEnd();
    if (!line.trim() || line.trim().startsWith("#")) continue;

    if (/^\S/.test(line)) {
      const match = line.match(/^([a-zA-Z0-9_-]+):\s*(.*)$/);
      if (!match) fail(`${filePath}:${i + 1}: expected top-level key: value`);
      const key = match[1];
      const value = match[2].trim();
      if (!allowedTopKeys.has(key)) {
        fail(
          `${filePath}:${i + 1}: unknown top-level key "${key}" (allowed: ${[...allowedTopKeys].join(", ")})`,
        );
      }
      if (seenTop.has(key)) {
        fail(`${filePath}:${i + 1}: duplicate top-level key "${key}"`);
      }
      seenTop.add(key);
      if (key === "artifacts") {
        inArtifacts = true;
        if (value) {
          fail(`${filePath}:${i + 1}: artifacts must be a mapping, not inline value`);
        }
        doc.artifacts ??= {};
      } else {
        inArtifacts = false;
        doc[key] = unquoteYamlScalar(value);
      }
      continue;
    }

    if (inArtifacts) {
      const match = line.match(/^\s{2,}([a-zA-Z0-9_-]+):\s*(.+)$/);
      if (!match) {
        fail(`${filePath}:${i + 1}: expected artifact key under artifacts:`);
      }
      const artKey = match[1];
      const artVal = unquoteYamlScalar(match[2].trim());
      doc.artifacts ??= {};
      if (Object.prototype.hasOwnProperty.call(doc.artifacts, artKey)) {
        fail(`${filePath}:${i + 1}: duplicate artifact key "${artKey}"`);
      }
      doc.artifacts[artKey] = artVal;
    } else {
      fail(`${filePath}:${i + 1}: unexpected indented line outside artifacts`);
    }
  }

  return doc;
}

function detectManifestKind(filePath) {
  const normalized = filePath.replace(/\\/g, "/");
  const rcMatch = normalized.match(
    /\/([0-9]{4}\.[0-9]{2}\.[0-9]{2}\.[0-9]+)\/rc([0-9]+)\/manifest\.yml$/,
  );
  if (rcMatch) {
    return {
      kind: "rc",
      cycleId: rcMatch[1],
      rcIndex: Number.parseInt(rcMatch[2], 10),
    };
  }
  if (/\/\.releases\/[^/]+\.yml$/.test(normalized) || /\/release-manifests\/[^/]+\.yml$/.test(normalized)) {
    fail(
      `${filePath}: flat .releases/<id>.yml manifests are no longer supported; use .releases/<cycle-id>/rc<n>/manifest.yml (ADR 0042)`,
    );
  }
  fail(
    `${filePath}: expected an RC manifest path ending in /<cycle-id>/rc<n>/manifest.yml`,
  );
}

function validateArtifacts(abs, artifacts) {
  if (!artifacts || Object.keys(artifacts).length === 0) {
    fail(`${abs}: artifacts mapping must be present and non-empty`);
  }
  for (const [key, val] of Object.entries(artifacts)) {
    if (!key.trim()) fail(`${abs}: empty artifact key`);
    if (!val || typeof val !== "string" || !val.trim()) {
      fail(`${abs}: artifact "${key}" must be a non-empty string tag`);
    }
  }
}

function validateManifestFile(filePath) {
  const abs = path.resolve(filePath);
  if (!fs.existsSync(abs)) {
    fail(`file not found: ${filePath}`);
  }
  const text = fs.readFileSync(abs, "utf8");
  if (/^deploy\s*:/m.test(text)) {
    fail(
      `${abs}: pin-only manifests must not include a top-level deploy key (ADR 0039); ordering belongs in repo deploy tooling`,
    );
  }

  const kindInfo = detectManifestKind(abs);
    const allowedKeys = RC_MANIFEST_KEYS;
  const doc = parsePinOnlyYaml(text, abs, allowedKeys);

  if (!doc.release) {
    fail(`${abs}: missing required field "release"`);
  }
  if (!RELEASE_ID_RE.test(doc.release)) {
    fail(
      `${abs}: release must match YYYY.MM.DD.N (got "${doc.release}"); see ADR 0042`,
    );
  }

  if (kindInfo.kind === "rc") {
    if (doc.release !== kindInfo.cycleId) {
      fail(
        `${abs}: release field "${doc.release}" must match parent cycle directory "${kindInfo.cycleId}"`,
      );
    }
    const rc = Number.parseInt(String(doc.rc), 10);
    if (!Number.isFinite(rc) || rc !== kindInfo.rcIndex) {
      fail(
        `${abs}: rc field must match directory rc${kindInfo.rcIndex} (got "${doc.rc}")`,
      );
    }
    if (!doc.cutAt?.trim()) {
      fail(`${abs}: missing required field "cutAt"`);
    }
    validateArtifacts(abs, doc.artifacts);
    return {
      release: doc.release,
      rcIndex: rc,
      artifacts: doc.artifacts,
      path: abs,
    };
  }

  fail(`${abs}: unsupported manifest path shape`);
}

function main() {
  const filePath = process.argv[2] ?? process.env.RELEASE_MANIFEST_PATH;
  if (!filePath) {
    fail("usage: validateReleaseManifest.mjs <path-to-manifest.yml>");
  }
  const result = validateManifestFile(filePath);
  process.stdout.write(`RELEASE_MANIFEST_PATH=${result.path}\n`);
  process.stdout.write(`RELEASE_ID=${result.release}\n`);
  if (result.rcIndex != null) {
    process.stdout.write(`RC_INDEX=${result.rcIndex}\n`);
  }
  process.stdout.write(`ARTIFACTS_JSON=${JSON.stringify(result.artifacts)}\n`);
}

main();
CHIUBAKA_ORB_VALIDATE_RELEASE_MANIFEST_V1_EOF
cat >"${stage_dir}/formatChangesetsBatchReleaseNotes.mjs" <<'CHIUBAKA_ORB_FORMAT_CHANGESETS_BATCH_RELEASE_NOTES_V1_EOF'
#!/usr/bin/env node
/**
 * Build grouped release notes from Changesets-style CHANGELOG.md files.
 *
 * Grouping (RELEASE_NOTES_GROUPING):
 *   category (orb default via callers) — Breaking / Security / Features / …
 *   bump-type — Major / Minor / Patch (legacy escape hatch)
 *
 * Nesting (RELEASE_NOTES_NESTING, default package-then-category):
 *   package-then-category — ### package, then #### category, then bullets
 *   category-then-package — ### category, then package bullets (legacy)
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
const NESTING = (
  process.env.RELEASE_NOTES_NESTING || "package-then-category"
).toLowerCase();

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

function bulletSummaryText(block) {
  const first = block[0];
  const m = String(first).match(/^[-*]\s?(.*)$/);
  return m ? m[1] : String(first).replace(/^[-*]\s?/, "");
}

function buildCategoryConfig(prefixes) {
  const {
    classifyChangelogBullet,
    CATEGORY_ORDER,
    CATEGORY_SECTION_TITLE,
    isDependencyBumpBullet,
  } = prefixes;
  return {
    order: CATEGORY_ORDER,
    titles: CATEGORY_SECTION_TITLE,
    fallbackBucket: null,
    isDependencyBumpBullet:
      typeof isDependencyBumpBullet === "function"
        ? isDependencyBumpBullet
        : () => false,
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
      return classifyChangelogBullet(bulletSummaryText(block));
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

function shouldDropDependencyBump(block, config) {
  if (typeof config.isDependencyBumpBullet !== "function") return false;
  return config.isDependencyBumpBullet(bulletSummaryText(block));
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
        } else if (shouldDropDependencyBump(b, config)) {
          continue;
        } else {
          const bucket = config.classifyBulletBlock(b);
          // rewriteChangelogCategories strips prefix tokens after placing bullets under category
          // headings; trust the section when the headline no longer carries a prefix token.
          buckets[bucket ?? cat].push(b);
        }
      }
    } else {
      const start = i;
      while (i < bodyLines.length && !config.classifyHeading(bodyLines[i])) i += 1;
      const chunk = bodyLines.slice(start, i);
      for (const b of splitBulletBlocks(chunk)) {
        if (shouldDropDependencyBump(b, config)) continue;
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

function stripBulletPrefix(firstLine, prefixes) {
  const stripFn = prefixes?.stripChangelogBulletCategoryPrefix ?? ((t) => t);
  const m = String(firstLine).match(/^[-*]\s?(.*)$/);
  let rest0 = m ? m[1] : String(firstLine).replace(/^[-*]\s?/, "");
  if (GROUPING === "category") {
    rest0 = stripFn(rest0);
  }
  return rest0;
}

/** Bullets nested under a package list item (category-then-package layout). */
function emitNestedUnderPackage(blocks, prefixes) {
  const out = [];
  for (const block of blocks) {
    if (!block || block.length === 0) continue;
    out.push(`  - ${stripBulletPrefix(block[0], prefixes)}`);
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

/** Top-level bullets under a category heading (package-then-category layout). */
function emitTopLevelBullets(blocks, prefixes) {
  const out = [];
  for (const block of blocks) {
    if (!block || block.length === 0) continue;
    out.push(`- ${stripBulletPrefix(block[0], prefixes)}`);
    for (let k = 1; k < block.length; k += 1) {
      const ln = block[k];
      if (ln === "") {
        out.push("");
        continue;
      }
      out.push(`  ${ln}`);
    }
  }
  return out;
}

function demoteHeading(title) {
  return String(title).replace(/^###\s/, "#### ");
}

function emitCategoryThenPackage(packages, config, prefixes) {
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
  return lines;
}

function emitPackageThenCategory(packages, config, prefixes) {
  const lines = [];
  const sorted = [...packages].sort((a, b) => a.name.localeCompare(b.name, "en"));
  for (const pkg of sorted) {
    const cats = config.order.filter((cat) => pkg.buckets[cat]?.length > 0);
    if (cats.length === 0) continue;
    lines.push(`### ${pkg.name}`, "");
    for (const cat of cats) {
      lines.push(demoteHeading(config.titles[cat]), "");
      lines.push(...emitTopLevelBullets(pkg.buckets[cat], prefixes));
      lines.push("");
    }
  }
  return lines;
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

  if (
    NESTING !== "package-then-category" &&
    NESTING !== "category-then-package"
  ) {
    console.error(
      `formatChangesetsBatchReleaseNotes: invalid RELEASE_NOTES_NESTING "${NESTING}" ` +
        `(expected package-then-category or category-then-package)`,
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

  const lines =
    NESTING === "category-then-package"
      ? emitCategoryThenPackage(packages, config, prefixes)
      : emitPackageThenCategory(packages, config, prefixes);

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
CHIUBAKA_ORB_FORMAT_CHANGESETS_BATCH_RELEASE_NOTES_V1_EOF
cat >"${stage_dir}/changesetCategoryPrefixes.mjs" <<'CHIUBAKA_ORB_CHANGESET_CATEGORY_PREFIXES_V1_EOF'
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
 * True when the summary after a recognized category prefix uses sentence case:
 * the first character must not be a lowercase letter (uppercase letters and
 * non-letters such as digits, backticks, or quotes are allowed).
 *
 * @param {string} headline Prefixed summary headline (first line of a changeset body).
 * @returns {boolean}
 */
export function hasCapitalizedSummaryAfterPrefix(headline) {
  const summary = stripCategoryPrefix(headline).trimStart();
  if (!summary) return false;
  const firstCharacter = [...summary][0];
  return !/\p{Ll}/u.test(firstCharacter);
}

/**
 * Strip Changesets changelog bullet metadata before category matching.
 * `@changesets/cli/changelog` re-exports `@changesets/changelog-git`, which prefixes bullets with
 * `<shortSha>: ` when a changeset commit is known. `@changesets/changelog-github` may prefix with
 * PR/commit links and a `Thanks …! - ` segment before the summary headline.
 *
 * @param {string} text Changelog bullet text after the list marker (`- `).
 * @returns {string} Headline suitable for {@link classifyCategoryToken}.
 */
export function stripChangelogBulletAnnotations(text) {
  let t = String(text).trim();
  if (classifyCategoryToken(t) !== null) return t;

  const github = t.match(/^[\s\S]+?\s+-\s+([\s\S]+)$/);
  if (github) {
    const candidate = github[1].trim();
    if (classifyCategoryToken(candidate) !== null) return candidate;
  }

  const git = t.match(/^[0-9a-f]{7,40}\s*:\s*([\s\S]+)$/i);
  if (git) {
    const candidate = git[1].trim();
    if (classifyCategoryToken(candidate) !== null) return candidate;
  }

  const linkedCommit = t.match(
    /^\[(?:`)?[0-9a-f]{7,40}(?:`)?\]\([^)]+\)\s*:?\s*([\s\S]+)$/i,
  );
  if (linkedCommit) {
    const candidate = linkedCommit[1].trim();
    if (classifyCategoryToken(candidate) !== null) return candidate;
  }

  let prev;
  do {
    prev = t;
    t = t.replace(/^\[[^\]]+\]\([^)]+\)\s+/i, "").trim();
    if (classifyCategoryToken(t) !== null) return t;
  } while (t !== prev);

  return String(text).trim();
}

/**
 * One Changesets dependency-line SHA reference:
 * - bare hex (`@changesets/changelog-git`)
 * - backtick-wrapped hex (`@changesets/changelog-github` fallback)
 * - Markdown commit link `` [`sha`](url) `` (`changelog-github`)
 */
const DEPENDENCY_SHA_REF_RE =
  "(?:[0-9a-f]{7,40}|`[0-9a-f]{7,40}`|\\[`[0-9a-f]{7,40}`\\]\\([^)]+\\))";

/**
 * Changesets `getDependencyReleaseLine` parent bullet, optionally with one or
 * more commit SHA refs and/or a trailing colon
 * (e.g. `Updated dependencies [abc1234]:`, or
 * `Updated dependencies [[\`abc1234\`](https://…)]:`). Non-SHA bracket text
 * such as `[docs]` is intentionally not matched so authored unprefixed
 * bullets stay subject to the strict category-prefix error path.
 */
const UPDATED_DEPENDENCIES_BULLET_RE = new RegExp(
  `^Updated dependencies(?:\\s+\\[${DEPENDENCY_SHA_REF_RE}(?:\\s*,\\s*${DEPENDENCY_SHA_REF_RE})*\\])?\\s*:?\\s*$`,
  "i",
);

/**
 * Bare package@version line produced when Prettier promotes an orphaned
 * indented dependency child to a top-level bullet (scoped or unscoped, with
 * optional prerelease/build metadata).
 */
const PACKAGE_AT_VERSION_BULLET_RE =
  /^(?:@[a-z0-9-~][a-z0-9-._~]*\/)?[a-z0-9-~][a-z0-9-._~]*@(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-((?:0|[1-9]\d*|\d*[a-z-][0-9a-z-]*)(?:\.(?:0|[1-9]\d*|\d*[a-z-][0-9a-z-]*))*))?(?:\+([0-9a-z-]+(?:\.[0-9a-z-]+)*))?$/i;

/**
 * True when a changelog bullet is Changesets internal dependency-bump noise
 * rather than an authored category-prefixed summary. Matches both the
 * `Updated dependencies` parent line and bare `pkg@version` orphan children.
 *
 * @param {string} text Changelog bullet text after the list marker (`- `).
 * @returns {boolean}
 */
export function isDependencyBumpBullet(text) {
  const t = String(text).trim();
  if (!t) return false;
  if (UPDATED_DEPENDENCIES_BULLET_RE.test(t)) return true;
  return PACKAGE_AT_VERSION_BULLET_RE.test(t);
}

/**
 * @param {string} text Changelog bullet text after the list marker (`- `).
 * @returns {CategoryBucket | null}
 */
export function classifyChangelogBullet(text) {
  return classifyCategoryToken(stripChangelogBulletAnnotations(text));
}

/**
 * @param {string} text Changelog bullet text after the list marker (`- `).
 * @returns {string}
 */
export function stripChangelogBulletCategoryPrefix(text) {
  return stripCategoryPrefix(stripChangelogBulletAnnotations(text));
}

/**
 * YAML between the opening `---` delimiters of a Changesets file (package bump declarations).
 * @param {string} content
 * @returns {string | null} Null when frontmatter delimiters are missing.
 */
export function extractChangesetFrontmatterYaml(content) {
  const normalized = String(content).replace(/\r\n/g, "\n");
  if (!normalized.startsWith("---")) return null;
  const close = normalized.indexOf("\n---", 3);
  if (close === -1) return null;
  return normalized.slice(3, close).trim();
}

/**
 * True when a changeset deliberately releases no packages (`changeset add --empty`).
 * @param {string} content
 * @returns {boolean}
 */
export function isEmptyChangeset(content) {
  const yaml = extractChangesetFrontmatterYaml(content);
  return yaml !== null && yaml === "";
}

/**
 * @param {string} content Full changeset markdown file contents.
 * @returns {{ ok: true, empty: true } | { ok: true, headline: string, bucket: CategoryBucket } | { ok: false, error: string }}
 */
export function validateChangesetSummaryCategory(content) {
  if (isEmptyChangeset(content)) {
    return { ok: true, empty: true };
  }
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
  if (!hasCapitalizedSummaryAfterPrefix(headline)) {
    return {
      ok: false,
      error:
        `summary text after the category prefix must be capitalized (sentence case); ` +
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
CHIUBAKA_ORB_CHANGESET_CATEGORY_PREFIXES_V1_EOF
cat >"${stage_dir}/refreshHighestRcManifestPins.mjs" <<'CHIUBAKA_ORB_REFRESH_HIGHEST_RC_MANIFEST_PINS_V1_EOF'
#!/usr/bin/env node
/**
 * Refresh artifact pins on the highest RC manifest.yml from current package.json
 * versions (ADR 0043 production finalization after changeset pre exit).
 *
 * Env:
 *   DEPLOYABLE_PACKAGES — comma-separated key=relative-path (required)
 *   RELEASES_DIR — default .releases
 *   RELEASE_ID — optional cycle id; when empty, uses resolveCycleOnCommit
 */
import fs from "node:fs";
import path from "node:path";
import {
  parseYamlScalar,
  resolveCycleOnCommit,
  resolveHighestRcIndex,
} from "./lib/releaseCycle.mjs";

function fail(msg) {
  process.stderr.write(`refreshHighestRcManifestPins: ${msg}\n`);
  process.exit(1);
}

function parseDeployablePackages(raw) {
  if (!raw?.trim()) {
    fail(
      "DEPLOYABLE_PACKAGES is required (format: key=path,key2=path2).",
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

function yamlQuote(value) {
  if (/^[a-zA-Z0-9._:-]+$/.test(value)) return value;
  return JSON.stringify(value);
}

/** Collect artifact keys under the `artifacts:` mapping in a pin-only manifest. */
function parseArtifactKeys(text) {
  const keys = [];
  let inArtifacts = false;
  for (const line of text.split(/\r?\n/)) {
    if (/^[^\s#]/.test(line)) {
      const top = line.match(/^([A-Za-z0-9_-]+):\s*(.*)$/);
      if (top) {
        inArtifacts = top[1] === "artifacts";
        continue;
      }
      inArtifacts = false;
      continue;
    }
    if (!inArtifacts) continue;
    const match = line.match(/^\s{2,}([a-zA-Z0-9_-]+):\s*(.+)$/);
    if (match) keys.push(match[1]);
  }
  return keys;
}

function assertArtifactKeySetMatches(manifestPath, existingText, deployableKeys) {
  const existingKeys = parseArtifactKeys(existingText);
  if (existingKeys.length === 0) {
    fail(`${manifestPath}: artifacts mapping must be present and non-empty`);
  }
  const existingSet = new Set(existingKeys);
  const deployableSet = new Set(deployableKeys);
  const missing = [...existingSet].filter((k) => !deployableSet.has(k)).sort();
  const extra = [...deployableSet].filter((k) => !existingSet.has(k)).sort();
  if (missing.length > 0 || extra.length > 0) {
    const parts = [];
    if (missing.length > 0) {
      parts.push(`missing from DEPLOYABLE_PACKAGES: ${missing.join(", ")}`);
    }
    if (extra.length > 0) {
      parts.push(`extra in DEPLOYABLE_PACKAGES: ${extra.join(", ")}`);
    }
    fail(
      `${manifestPath}: artifact key set must match DEPLOYABLE_PACKAGES (${parts.join("; ")})`,
    );
  }
}

function main() {
  const deployables = parseDeployablePackages(process.env.DEPLOYABLE_PACKAGES);
  const releasesDir = process.env.RELEASES_DIR ?? ".releases";
  let cycleId = process.env.RELEASE_ID?.trim() || "";
  let rcIndex;

  if (cycleId) {
    rcIndex = resolveHighestRcIndex(releasesDir, cycleId);
    if (rcIndex < 1) {
      fail(`no rc*/directories under ${releasesDir}/${cycleId}`);
    }
  } else {
    const resolved = resolveCycleOnCommit(releasesDir);
    if (!resolved) {
      fail(`could not resolve cycle under ${releasesDir}`);
    }
    cycleId = resolved.cycleId;
    rcIndex = resolved.rcIndex;
  }

  const manifestPath = path.join(
    releasesDir,
    cycleId,
    `rc${rcIndex}`,
    "manifest.yml",
  );
  if (!fs.existsSync(manifestPath)) {
    fail(`missing manifest at ${manifestPath}`);
  }

  const existing = fs.readFileSync(manifestPath, "utf8");
  assertArtifactKeySetMatches(
    manifestPath,
    existing,
    deployables.map((d) => d.key),
  );

  const release = parseYamlScalar("release", existing) ?? cycleId;
  const rc = parseYamlScalar("rc", existing) ?? String(rcIndex);
  const cutAt = parseYamlScalar("cutAt", existing);
  if (!cutAt) {
    fail(`${manifestPath}: missing cutAt`);
  }

  const artifacts = {};
  for (const { key, pkgPath } of deployables) {
    const version = readPackageVersion(pkgPath);
    artifacts[key] = `${key}-v${version}`;
  }

  const lines = [
    `release: ${yamlQuote(release)}`,
    `rc: ${rc}`,
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
  fs.writeFileSync(manifestPath, lines.join("\n"), "utf8");

  process.stdout.write(`${manifestPath}\n`);
  process.stdout.write(`RELEASE_ID=${cycleId}\n`);
  process.stdout.write(`RC_INDEX=${rcIndex}\n`);
}

main();
CHIUBAKA_ORB_REFRESH_HIGHEST_RC_MANIFEST_PINS_V1_EOF
printf '%s\n' "${stage_dir}/writeReleaseCycle.mjs"
