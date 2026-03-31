#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: bootstrap-skills.sh [--check]

Bootstraps org-managed skills by symlinking each directory under:
  org/agents/skills/<skill-name>
into:
  .agents/skills/<skill-name>

Behavior:
  - Creates .agents/skills if missing.
  - Never removes or modifies non-org local skills.
  - For org skill names:
      * Missing local path -> creates symlink
      * Matching symlink   -> no-op
      * Other existing path or mismatched symlink -> conflict

Options:
  --check   Read-only validation mode. Does not create symlinks.
            Exits non-zero if any link is missing or conflicts exist.
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

ORG_SKILLS_DIR="$REPO_ROOT/org/agents/skills"
LOCAL_SKILLS_DIR="$REPO_ROOT/.agents/skills"

resolve_realpath() {
  local target="$1"

  if command -v realpath >/dev/null 2>&1; then
    realpath "$target"
    return
  fi

  if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "$target"
    return
  fi

  echo "Unable to resolve absolute path for '$target': requires 'realpath' or 'python3'" >&2
  exit 1
}

if [[ ! -d "$ORG_SKILLS_DIR" ]]; then
  echo "Org skills directory not found: $ORG_SKILLS_DIR" >&2
  exit 1
fi

if [[ "$CHECK_MODE" -eq 0 ]]; then
  mkdir -p "$LOCAL_SKILLS_DIR"
fi

linked=0
ok=0
missing=0
conflicts=0

shopt -s nullglob
for skill_dir in "$ORG_SKILLS_DIR"/*; do
  [[ -d "$skill_dir" ]] || continue

  skill_name="$(basename "$skill_dir")"
  skill_manifest="$skill_dir/SKILL.md"
  if [[ ! -f "$skill_manifest" ]]; then
    echo "Skipping '$skill_name': no SKILL.md in $skill_dir"
    continue
  fi

  link_path="$LOCAL_SKILLS_DIR/$skill_name"
  link_target="../../org/agents/skills/$skill_name"

  if [[ -L "$link_path" ]]; then
    desired_abs="$(resolve_realpath "$skill_dir")"
    existing_abs="$(resolve_realpath "$link_path")"
    if [[ "$desired_abs" == "$existing_abs" ]]; then
      ((ok+=1))
      echo "OK: $link_path -> $(readlink "$link_path")"
    else
      ((conflicts+=1))
      echo "CONFLICT: $link_path points to $(readlink "$link_path"), expected $link_target" >&2
    fi
    continue
  fi

  if [[ -e "$link_path" ]]; then
    ((conflicts+=1))
    echo "CONFLICT: $link_path already exists and is not a symlink" >&2
    continue
  fi

  if [[ "$CHECK_MODE" -eq 1 ]]; then
    ((missing+=1))
    echo "MISSING: $link_path (should link to $link_target)"
  else
    ln -s "$link_target" "$link_path"
    ((linked+=1))
    echo "LINKED:  $link_path -> $link_target"
  fi
done

if [[ "$CHECK_MODE" -eq 1 ]]; then
  echo
  echo "Check summary: ok=$ok missing=$missing conflicts=$conflicts"
  if [[ "$missing" -gt 0 || "$conflicts" -gt 0 ]]; then
    exit 1
  fi
  exit 0
fi

echo
echo "Bootstrap summary: linked=$linked ok=$ok conflicts=$conflicts"
if [[ "$conflicts" -gt 0 ]]; then
  exit 1
fi
