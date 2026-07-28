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

function parseYamlScalar(key, text) {
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

function main() {
  const deployables = parseDeployablePackages(process.env.DEPLOYABLE_PACKAGES);
  const releasesDir = process.env.RELEASES_DIR ?? ".releases";
  let cycleId = process.env.RELEASE_ID?.trim() || "";
  let rcIndex;

  if (cycleId) {
    rcIndex = resolveHighestRcIndex(releasesDir, cycleId);
    if (rcIndex < 1) {
      fail(`no rc*/ directories under ${releasesDir}/${cycleId}`);
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
