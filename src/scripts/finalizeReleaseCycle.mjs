#!/usr/bin/env node
/**
 * Set promotedAt on cycle.yml and write release-notes.md rollup (ADR 0041).
 * Usage: node finalizeReleaseCycle.mjs <.releases/cycle-id>
 */
import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { parseYamlScalar, utcIsoTimestamp } from "./lib/releaseCycle.mjs";

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

  const promotedAt = utcIsoTimestamp(process.env.UTC_TIMESTAMP_OVERRIDE);
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

  const rollupScript =
    process.env.ROLLUP_RELEASE_NOTES_SCRIPT ??
    path.join(SCRIPT_DIR, "rollupReleaseNotes.mjs");
  const result = spawnSync(process.execPath, [rollupScript, abs], {
    encoding: "utf8",
  });
  if (result.status !== 0) {
    process.stderr.write(result.stderr ?? "");
    process.exit(result.status ?? 1);
  }

  process.stdout.write(`CYCLE_YML=${cycleYml}\n`);
  process.stdout.write(`RELEASE_NOTES_PATH=${path.join(abs, "release-notes.md")}\n`);
  process.stdout.write(`PROMOTED_AT=${promotedAt}\n`);
}

main();
