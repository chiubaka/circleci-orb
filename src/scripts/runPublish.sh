#! /usr/bin/env bash
# Default: pnpm exec changeset publish (org standard). Override with PUBLISH_SCRIPT to run
# pnpm run <script>. Policy: org ADR 0024; Changesets config lives under client .changeset/.
set -euo pipefail

pnpm_bin=${PNPM_BINARY:-pnpm}
script=${PUBLISH_SCRIPT:-}
dry_raw=${DRY_RUN:-false}
dry_lower=$(printf '%s' "$dry_raw" | tr '[:upper:]' '[:lower:]')
dry=false
if [[ "$dry_lower" == "true" ]] || [[ "$dry_lower" == "1" ]]; then
  dry=true
fi

changeset_publish_help_has_dry_run() {
  local help
  help=$("$pnpm_bin" exec changeset publish --help 2>&1) || {
    echo "runPublish: failed to run \"${pnpm_bin} exec changeset publish --help\". Is @changesets/cli installed?" >&2
    return 1
  }
  if grep -qE '(^|[[:space:]])--dry-run' <<<"$help"; then
    return 0
  fi
  echo "runPublish: \"changeset publish\" does not advertise --dry-run in this @changesets/cli build. Upgrade @changesets/cli, or set publish-script to a package.json script that supports dry-run (orb passes \"pnpm run <script> -- --dry-run\")." >&2
  return 1
}

if [[ -n "$script" ]]; then
  if $dry; then
    exec "$pnpm_bin" run "$script" -- --dry-run
  fi
  exec "$pnpm_bin" run "$script"
fi

if $dry; then
  changeset_publish_help_has_dry_run || exit 1
  exec "$pnpm_bin" exec changeset publish --dry-run
fi

exec "$pnpm_bin" exec changeset publish
