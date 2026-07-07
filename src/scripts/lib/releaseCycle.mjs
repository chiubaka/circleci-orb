#!/usr/bin/env node
/**
 * Release cycle and RC allocation (ADR 0041, ADR 0042).
 */
import fs from "node:fs";
import path from "node:path";
import { execSync } from "node:child_process";
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
    const out = execSync(`git ls-tree -d --name-only ${sha}:${treePath}`, {
      encoding: "utf8",
      stdio: ["ignore", "pipe", "pipe"],
    });
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
