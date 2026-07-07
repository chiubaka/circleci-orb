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
