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

    if (/^\S/.test(line) && !line.startsWith("artifacts:")) {
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
      } else {
        inArtifacts = false;
        doc[key] = unquoteYamlScalar(value);
      }
      continue;
    }

    if (line.startsWith("artifacts:")) {
      inArtifacts = true;
      seenTop.add("artifacts");
      doc.artifacts ??= {};
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
