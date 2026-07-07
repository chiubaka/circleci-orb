#!/usr/bin/env node
/**
 * Resolve the release cycle and highest RC on the current commit.
 * Usage: node resolveReleaseCycleOnCommit.mjs
 */
import { resolveCycleOnCommit } from "./lib/releaseCycle.mjs";

const releasesDir = process.env.RELEASES_DIR ?? ".releases";
const resolved = resolveCycleOnCommit(releasesDir);
if (!resolved) {
  process.stderr.write(
    `resolveReleaseCycleOnCommit: no .releases/<cycle-id>/rc<n>/ tree found under ${releasesDir}\n`,
  );
  process.exit(1);
}

process.stdout.write(`CYCLE_ID=${resolved.cycleId}\n`);
process.stdout.write(`RC_INDEX=${resolved.rcIndex}\n`);
