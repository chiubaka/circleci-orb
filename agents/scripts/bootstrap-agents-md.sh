#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: bootstrap-agents-md.sh [--check]

Bootstraps root AGENTS.md from org-managed guidance with marker sections.

Managed source:
  org/agents/AGENTS.org.md

Destination:
  AGENTS.md (repo root)

Sections in AGENTS.md:
  <!-- ORG_GUIDANCE_START -->
  <!-- ORG_GUIDANCE_END -->
  <!-- REPO_OVERRIDES_START -->
  <!-- REPO_OVERRIDES_END -->

Behavior:
  - If AGENTS.md is missing, create it with both marker sections.
  - If AGENTS.md exists with markers, replace only org-managed section.
  - Preserve repo override section exactly.
  - If markers are missing or malformed:
      * --check: fail with guidance
      * default mode: migrate existing AGENTS.md into repo override section and create a backup

Options:
  --check     Validate AGENTS.md is in sync; no writes.
  -h, --help  Show this help.
EOF
}

CHECK_MODE=0
case "${1:-}" in
  --check)
    CHECK_MODE=1
    ;;
  "" )
    ;;
  -h|--help)
    usage
    exit 0
    ;;
  *)
    echo "Unknown argument: $1" >&2
    usage >&2
    exit 2
    ;;
esac

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$REPO_ROOT" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
fi

ORG_SOURCE="$REPO_ROOT/org/agents/AGENTS.org.md"
TARGET_AGENTS="$REPO_ROOT/AGENTS.md"

ORG_START='<!-- ORG_GUIDANCE_START -->'
ORG_END='<!-- ORG_GUIDANCE_END -->'
REPO_START='<!-- REPO_OVERRIDES_START -->'
REPO_END='<!-- REPO_OVERRIDES_END -->'

if [[ ! -f "$ORG_SOURCE" ]]; then
  echo "Org guidance source not found: $ORG_SOURCE" >&2
  exit 1
fi

tmp_rendered="$(mktemp)"
cleanup() {
  rm -f "$tmp_rendered"
}
trap cleanup EXIT

{
  echo "# Agent notes (repo conventions)"
  echo
  echo "$ORG_START"
  cat "$ORG_SOURCE"
  echo
  echo "$ORG_END"
  echo
  echo "$REPO_START"
  echo "_Repository-specific overrides go here. These take precedence over org defaults._"
  echo "$REPO_END"
} > "$tmp_rendered"

if [[ ! -f "$TARGET_AGENTS" ]]; then
  if [[ "$CHECK_MODE" -eq 1 ]]; then
    echo "MISSING: $TARGET_AGENTS"
    exit 1
  fi
  cp "$tmp_rendered" "$TARGET_AGENTS"
  echo "CREATED: $TARGET_AGENTS"
  exit 0
fi

tmp_next="$(mktemp)"
cleanup() {
  rm -f "$tmp_rendered" "$tmp_next"
}
trap cleanup EXIT

if ! awk -v orgStart="$ORG_START" -v orgEnd="$ORG_END" -v repoStart="$REPO_START" -v repoEnd="$REPO_END" '
BEGIN {
  sawOrgStart=0; sawOrgEnd=0; sawRepoStart=0; sawRepoEnd=0;
  inOrg=0; inRepo=0;
}
{
  if ($0 == orgStart) {
    sawOrgStart++; inOrg=1;
    print $0;
    while ((getline line < "'"$ORG_SOURCE"'") > 0) {
      print line;
    }
    close("'"$ORG_SOURCE"'");
    next;
  }
  if ($0 == orgEnd) {
    sawOrgEnd++; inOrg=0;
    print $0;
    next;
  }
  if ($0 == repoStart) {
    sawRepoStart++; inRepo=1;
    print $0;
    next;
  }
  if ($0 == repoEnd) {
    sawRepoEnd++; inRepo=0;
    print $0;
    next;
  }
  if (inOrg == 1) {
    next;
  }
  print $0;
}
END {
  valid = (sawOrgStart==1 && sawOrgEnd==1 && sawRepoStart==1 && sawRepoEnd==1);
  if (!valid) {
    exit 42;
  }
}' "$TARGET_AGENTS" > "$tmp_next"; then
  if [[ "$CHECK_MODE" -eq 1 ]]; then
    echo "ERROR: $TARGET_AGENTS is missing required managed markers or has duplicates." >&2
    echo "Expected exactly one each of:" >&2
    echo "  $ORG_START / $ORG_END" >&2
    echo "  $REPO_START / $REPO_END" >&2
    exit 1
  fi

  backup_path="$TARGET_AGENTS.bak.$(date +%Y%m%d%H%M%S)"
  cp "$TARGET_AGENTS" "$backup_path"

  {
    echo "# Agent notes (repo conventions)"
    echo
    echo "$ORG_START"
    cat "$ORG_SOURCE"
    echo
    echo "$ORG_END"
    echo
    echo "$REPO_START"
    echo "_Repository-specific overrides migrated from previous AGENTS.md._"
    echo
    cat "$backup_path"
    echo
    echo "$REPO_END"
  } > "$tmp_next"

  cp "$tmp_next" "$TARGET_AGENTS"
  echo "MIGRATED: $TARGET_AGENTS (backup at $(basename "$backup_path"))"
  exit 0
fi

if cmp -s "$tmp_next" "$TARGET_AGENTS"; then
  echo "OK: $TARGET_AGENTS already in sync"
  exit 0
fi

if [[ "$CHECK_MODE" -eq 1 ]]; then
  echo "DRIFT: $TARGET_AGENTS differs from org-managed guidance"
  exit 1
fi

cp "$tmp_next" "$TARGET_AGENTS"
echo "UPDATED: $TARGET_AGENTS (org-managed section refreshed)"
