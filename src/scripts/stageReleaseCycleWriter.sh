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
      notesPath: path.join(cyclePath, entry.name, "notes.md"),
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
  const notesPath = path.join(rcDir, "notes.md");
  writeRcNotes(notesPath, changelogPaths);

  process.stdout.write(`${manifestPath}\n`);
  process.stdout.write(`RELEASE_ID=${plan.cycleId}\n`);
  process.stdout.write(`RC_INDEX=${plan.rcIndex}\n`);
  process.stdout.write(`RC_NOTES_PATH=${notesPath}\n`);
}

main();
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
 * Set promotedAt on cycle.yml and write release-notes.md rollup (ADR 0041).
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

  const rollupScript =
    process.env.ROLLUP_RELEASE_NOTES_SCRIPT ??
    path.join(SCRIPT_DIR, "rollupReleaseNotes.mjs");
  const result = spawnSync(process.execPath, [rollupScript, abs], {
    encoding: "utf8",
  });
  if (result.status !== 0) {
    if (result.error) process.stderr.write(`${result.error.message}\n`);
    process.stderr.write(result.stderr ?? "");
    process.exit(result.status ?? 1);
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
 * Roll up per-RC notes into cycle release-notes.md (ADR 0041 artifact 3).
 * Usage: node rollupReleaseNotes.mjs <cycle-dir> [outfile]
 */
import fs from "node:fs";
import path from "node:path";
import { listRcNotesPaths } from "./lib/releaseCycle.mjs";

function fail(msg) {
  process.stderr.write(`rollupReleaseNotes: ${msg}\n`);
  process.exit(1);
}

function main() {
  const cycleDir = process.argv[2];
  if (!cycleDir) {
    fail("usage: rollupReleaseNotes.mjs <.releases/cycle-id> [outfile]");
  }
  const absCycleDir = path.resolve(cycleDir);
  const cycleId = path.basename(absCycleDir);
  const outPath =
    process.argv[3] ?? path.join(absCycleDir, "release-notes.md");

  const rcNotes = listRcNotesPaths(path.dirname(absCycleDir), cycleId);
  if (rcNotes.length === 0) {
    fail(`no rc*/notes.md files found under ${absCycleDir}`);
  }

  const sections = [];
  for (const { index, notesPath } of rcNotes) {
    const body = fs.readFileSync(notesPath, "utf8").trimEnd();
    sections.push(`## ${cycleId}-rc${index}`, "", body, "");
  }

  const content = `${sections.join("\n").trimEnd()}\n`;
  fs.writeFileSync(outPath, content, "utf8");
  process.stdout.write(`${outPath}\n`);
}

main();
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
  hasPromotedAt,
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
  return { promoted: hasPromotedAt(text) };
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

  const { promoted } = validateCycleYml(abs, cycleId);
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
    const notes = path.join(rcDir, "notes.md");
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

  if (promoted) {
    const releaseNotes = path.join(abs, "release-notes.md");
    if (!fs.existsSync(releaseNotes)) {
      fail(`${abs}: promoted cycle must include release-notes.md`);
    }
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
  const { classifyChangelogBullet, CATEGORY_ORDER, CATEGORY_SECTION_TITLE } = prefixes;
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
      return classifyChangelogBullet(text);
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
  const stripFn = prefixes?.stripChangelogBulletCategoryPrefix ?? ((t) => t);
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
printf '%s\n' "${stage_dir}/writeReleaseCycle.mjs"
