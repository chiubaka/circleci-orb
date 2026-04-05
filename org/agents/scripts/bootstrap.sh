#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: bootstrap.sh [--check]

Delegates to org bootstrap scripts:
  1) bootstrap-skills.sh
  2) bootstrap-agents-md.sh

Options:
  --check     Run delegated scripts in read-only validation mode.
  -h, --help  Show this help.
EOF
}

CHECK_ARG=""
CHECK_MODE=0
case "${1:-}" in
  --check)
    CHECK_ARG="--check"
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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
fi

TOOL_LINKS=(".claude/skills" ".cursor/skills")
TOOL_REL_TARGET="../.agents/skills"
tool_linked=0
tool_ok=0
tool_missing=0
tool_conflicts=0

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

ensure_tool_link() {
  local link_rel="$1"
  local target_rel="$2"
  local target_abs="$3"
  local link_abs="$REPO_ROOT/$link_rel"
  local parent_dir
  parent_dir="$(dirname "$link_abs")"

  if [[ "$CHECK_MODE" -eq 0 ]]; then
    mkdir -p "$parent_dir"
  fi

  if [[ -L "$link_abs" ]]; then
    local existing_abs
    existing_abs="$(resolve_realpath "$link_abs")"
    if [[ "$existing_abs" == "$target_abs" ]]; then
      ((tool_ok+=1))
      echo "OK: $link_rel -> $(readlink "$link_abs")"
    else
      ((tool_conflicts+=1))
      echo "CONFLICT: $link_rel points to $(readlink "$link_abs"), expected $target_rel" >&2
    fi
    return
  fi

  if [[ -e "$link_abs" ]]; then
    ((tool_conflicts+=1))
    echo "CONFLICT: $link_rel already exists and is not a symlink" >&2
    return
  fi

  if [[ "$CHECK_MODE" -eq 1 ]]; then
    ((tool_missing+=1))
    echo "MISSING: $link_rel (should link to $target_rel)"
    return
  fi

  ln -s "$target_rel" "$link_abs"
  ((tool_linked+=1))
  echo "LINKED:  $link_rel -> $target_rel"
}

ensure_tool_links() {
  local target_abs="$REPO_ROOT/.agents/skills"
  if [[ ! -d "$target_abs" ]]; then
    echo "Missing skills directory: $target_abs" >&2
    return 1
  fi

  local link_rel
  for link_rel in "${TOOL_LINKS[@]}"; do
    ensure_tool_link "$link_rel" "$TOOL_REL_TARGET" "$target_abs"
  done

  if [[ "$CHECK_MODE" -eq 1 ]]; then
    echo
    echo "Tool links check: linked=$tool_linked ok=$tool_ok missing=$tool_missing conflicts=$tool_conflicts"
    if ((tool_missing > 0 || tool_conflicts > 0)); then
      return 1
    fi
    return 0
  fi

  echo
  echo "Tool links sync: linked=$tool_linked ok=$tool_ok conflicts=$tool_conflicts"
  if ((tool_conflicts > 0)); then
    return 1
  fi
  return 0
}

create_claude_md_link() {
  local claude_path="$REPO_ROOT/CLAUDE.md"
  local agents_target="AGENTS.md"

  if [[ ! -e "$REPO_ROOT/$agents_target" ]]; then
    echo "Missing AGENTS.md; cannot create CLAUDE.md link" >&2
    return 1
  fi

  if [[ -L "$claude_path" ]]; then
    local existing
    existing="$(readlink "$claude_path")"
    if [[ "$existing" == "$agents_target" ]]; then
      echo "OK: CLAUDE.md -> $existing"
      return 0
    fi
    echo "CONFLICT: CLAUDE.md points to $existing, expected $agents_target" >&2
    return 1
  fi

  if [[ -e "$claude_path" ]]; then
    echo "CONFLICT: CLAUDE.md already exists and is not a symlink" >&2
    return 1
  fi

  if [[ "$CHECK_MODE" -eq 1 ]]; then
    echo "MISSING: CLAUDE.md (should link to $agents_target)"
    return 0
  fi

  ln -s "$agents_target" "$claude_path"
  echo "LINKED:  CLAUDE.md -> $agents_target"
  return 0
}

"$SCRIPT_DIR/bootstrap-skills.sh" $CHECK_ARG
"$SCRIPT_DIR/bootstrap-agents-md.sh" $CHECK_ARG

if ! ensure_tool_links; then
  exit 1
fi

if ! create_claude_md_link; then
  exit 1
fi

echo "All bootstrap steps completed."
