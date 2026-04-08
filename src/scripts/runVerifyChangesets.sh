#! /usr/bin/env bash
# Runs changeset status or a repo-defined verify script. See org ADR 0024–0028.
set -euo pipefail

pnpm_bin=${PNPM_BINARY:-pnpm}
verify_script=${VERIFY_SCRIPT:-}

if [[ -z "$verify_script" ]]; then
  exec "$pnpm_bin" exec changeset status
fi

exec "$pnpm_bin" run "$verify_script"
