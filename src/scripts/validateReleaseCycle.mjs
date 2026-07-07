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
