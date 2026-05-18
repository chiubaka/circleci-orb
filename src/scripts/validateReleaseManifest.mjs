#!/usr/bin/env node
/**
 * Strict pin-only release manifest validation (ADR 0038).
 * Usage: node validateReleaseManifest.mjs <path-to-manifest.yml>
 * Exports RELEASE_MANIFEST_PATH, RELEASE_ID, ARTIFACTS_JSON on success (stdout).
 */
import fs from "node:fs";
import path from "node:path";

const RELEASE_ID_RE = /^[0-9]{4}\.[0-9]{2}\.[0-9]{2}\.[0-9]+$/;
const ALLOWED_TOP_KEYS = new Set(["release", "artifacts"]);

function fail(msg) {
  process.stderr.write(`validateReleaseManifest: ${msg}\n`);
  process.exit(1);
}

function parsePinOnlyYaml(text, filePath) {
  const lines = text.split(/\r?\n/);
  let release;
  const artifacts = {};
  let inArtifacts = false;
  const seenTop = new Set();

  for (let i = 0; i < lines.length; i++) {
    const raw = lines[i];
    const line = raw.replace(/\s+#.*$/, "").trimEnd();
    if (!line.trim() || line.trim().startsWith("#")) continue;

    if (/^\S/.test(line) && !line.startsWith("artifacts:")) {
      const m = line.match(/^([a-zA-Z0-9_-]+):\s*(.*)$/);
      if (!m) fail(`${filePath}:${i + 1}: expected top-level key: value`);
      const key = m[1];
      const value = m[2].trim();
      if (!ALLOWED_TOP_KEYS.has(key)) {
        fail(
          `${filePath}:${i + 1}: unknown top-level key "${key}" (pin-only manifests allow only release and artifacts; see ADR 0038)`,
        );
      }
      if (seenTop.has(key)) {
        fail(`${filePath}:${i + 1}: duplicate top-level key "${key}"`);
      }
      seenTop.add(key);
      if (key === "release") {
        release = unquoteYamlScalar(value);
        inArtifacts = false;
      } else if (key === "artifacts") {
        inArtifacts = true;
        if (value) fail(`${filePath}:${i + 1}: artifacts must be a mapping, not inline value`);
      }
      continue;
    }

    if (line.startsWith("artifacts:")) {
      inArtifacts = true;
      seenTop.add("artifacts");
      continue;
    }

    if (inArtifacts) {
      const m = line.match(/^\s{2,}([a-zA-Z0-9_-]+):\s*(.+)$/);
      if (!m) {
        fail(`${filePath}:${i + 1}: expected artifact key under artifacts:`);
      }
      const artKey = m[1];
      const artVal = unquoteYamlScalar(m[2].trim());
      if (Object.prototype.hasOwnProperty.call(artifacts, artKey)) {
        fail(`${filePath}:${i + 1}: duplicate artifact key "${artKey}"`);
      }
      artifacts[artKey] = artVal;
    } else {
      fail(`${filePath}:${i + 1}: unexpected indented line outside artifacts`);
    }
  }

  return { release, artifacts };
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

function validateManifestFile(filePath) {
  const abs = path.resolve(filePath);
  if (!fs.existsSync(abs)) {
    fail(`file not found: ${filePath}`);
  }
  const base = path.basename(abs, path.extname(abs));
  const text = fs.readFileSync(abs, "utf8");
  if (/^deploy\s*:/m.test(text)) {
    fail(
      `${abs}: pin-only manifests must not include a top-level deploy key (ADR 0038); ordering belongs in repo deploy tooling`,
    );
  }
  const doc = parsePinOnlyYaml(text, abs);

  if (!doc.release) {
    fail(`${abs}: missing required field "release"`);
  }
  if (!RELEASE_ID_RE.test(doc.release)) {
    fail(
      `${abs}: release must match YYYY.MM.DD.N (got "${doc.release}"); see ADR 0031`,
    );
  }
  if (base !== doc.release) {
    fail(
      `${abs}: filename stem "${base}" must match release field "${doc.release}"`,
    );
  }
  if (!doc.artifacts || Object.keys(doc.artifacts).length === 0) {
    fail(`${abs}: artifacts mapping must be present and non-empty`);
  }
  for (const [key, val] of Object.entries(doc.artifacts)) {
    if (!key.trim()) fail(`${abs}: empty artifact key`);
    if (!val || typeof val !== "string" || !val.trim()) {
      fail(`${abs}: artifact "${key}" must be a non-empty string tag`);
    }
  }

  return { release: doc.release, artifacts: doc.artifacts, path: abs };
}

function main() {
  const filePath = process.argv[2] ?? process.env.RELEASE_MANIFEST_PATH;
  if (!filePath) {
    fail("usage: validateReleaseManifest.mjs <path-to-manifest.yml>");
  }
  const result = validateManifestFile(filePath);
  process.stdout.write(`RELEASE_MANIFEST_PATH=${result.path}\n`);
  process.stdout.write(`RELEASE_ID=${result.release}\n`);
  process.stdout.write(`ARTIFACTS_JSON=${JSON.stringify(result.artifacts)}\n`);
}

main();
