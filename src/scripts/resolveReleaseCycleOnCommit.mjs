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
