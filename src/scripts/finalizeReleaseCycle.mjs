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
