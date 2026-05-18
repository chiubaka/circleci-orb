#!/usr/bin/env node
/**
 * Write .releases/<release-id>.yml after changeset version (ADR 0038, opt-in).
 * Env:
 *   DEPLOYABLE_PACKAGES — comma-separated key=relative-path (e.g. server=packages/server,web=apps/web)
 *   MANIFEST_TRAIN_TAG_PREFIX — prefix for remote tag scan when allocating N (default release/)
 *   UTC_DATE_OVERRIDE — test hook (YYYY.MM.DD)
 *   RELEASES_DIR — default .releases
 */
import fs from "node:fs";
import path from "node:path";
import {
  computeNextTrainIdForDate,
  utcCalendarDateStr,
} from "./lib/trainId.mjs";
import { execSync } from "node:child_process";

function fail(msg) {
  process.stderr.write(`writeReleaseManifest: ${msg}\n`);
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
  } catch (e) {
    fail(`failed to parse ${pkgJsonPath}: ${e.message}`);
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
      `git ls-remote --tags origin failed (${detail}); cannot allocate train id safely.`,
    );
  }
}

function yamlQuote(value) {
  if (/^[a-zA-Z0-9._-]+$/.test(value)) return value;
  return JSON.stringify(value);
}

function renderManifest(releaseId, artifacts) {
  const lines = [`release: ${yamlQuote(releaseId)}`, "", "artifacts:"];
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
  const lsRemote = gitLsRemoteTags();
  const releaseId = computeNextTrainIdForDate(prefix, dateStr, lsRemote);

  const artifacts = {};
  for (const { key, pkgPath } of deployables) {
    const version = readPackageVersion(pkgPath);
    artifacts[key] = `${key}-v${version}`;
  }

  fs.mkdirSync(releasesDir, { recursive: true });
  const outPath = path.join(releasesDir, `${releaseId}.yml`);
  if (fs.existsSync(outPath)) {
    fail(
      `manifest already exists at ${outPath}; delete or bump train id before re-running.`,
    );
  }
  fs.writeFileSync(outPath, renderManifest(releaseId, artifacts), "utf8");
  process.stdout.write(`${outPath}\n`);
  process.stdout.write(`RELEASE_ID=${releaseId}\n`);
}

main();
