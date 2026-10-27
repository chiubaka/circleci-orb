#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: bootstrap-rules.sh [--check]

Projects org-managed always-on agent rules from:
  org/agents/rules/<name>.md
into consuming-repo tool paths:
  .cursor/rules/<name>.mdc   (YAML frontmatter + body; alwaysApply: true)
  .claude/rules/<name>.md    (body only)

In the org repository itself (no org/ subtree prefix), the source is:
  agents/rules/<name>.md

Behavior:
  - Creates .cursor/rules and .claude/rules if missing (write mode).
  - For each org rule markdown file:
      * Missing target     -> write expected content (write mode)
      * Matching content   -> no-op
      * Differing content  -> conflict (does not overwrite)
  - Leaves non-org local rule files untouched.

Options:
  --check   Read-only validation mode. Does not write files.
            Exits non-zero if any projection is missing, stale, or conflicts.
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
  # agents/scripts -> ../.. is org-repo root; ../../.. is consuming-repo root when embedded under org/.
  local_root="$(cd "$SCRIPT_DIR/../.." && pwd)"
  embedded_root="$(cd "$SCRIPT_DIR/../../.." && pwd)"

  # Prefer consuming-repo layout first so projections land at the consumer root, not under org/.
  if [[ -d "$embedded_root/org/agents/rules" ]]; then
    REPO_ROOT="$embedded_root"
  elif [[ -d "$local_root/agents/rules" ]]; then
    REPO_ROOT="$local_root"
  else
    REPO_ROOT="$local_root"
  fi
fi

# Consuming repos embed this tree under org/; the org repo authors at agents/.
if [[ -d "$REPO_ROOT/org/agents/rules" ]]; then
  ORG_RULES_DIR="$REPO_ROOT/org/agents/rules"
elif [[ -d "$REPO_ROOT/agents/rules" ]]; then
  ORG_RULES_DIR="$REPO_ROOT/agents/rules"
else
  echo "Org rules directory not found (tried org/agents/rules and agents/rules under $REPO_ROOT)" >&2
  exit 1
fi

CURSOR_RULES_DIR="$REPO_ROOT/.cursor/rules"
CLAUDE_RULES_DIR="$REPO_ROOT/.claude/rules"

written=0
ok=0
missing=0
conflicts=0

cursor_description_for() {
  local rule_name="$1"
  case "$rule_name" in
    coding-discipline)
      echo 'Coding discipline—clarify assumptions, prefer simplicity, keep diffs surgical, verify with goals.'
      ;;
    *)
      echo "Org always-on agent rule: ${rule_name}"
      ;;
  esac
}

cursor_expected_content() {
  local body_file="$1"
  local rule_name="$2"
  local description
  description="$(cursor_description_for "$rule_name")"
  {
    echo '---'
    echo "description: ${description}"
    echo 'alwaysApply: true'
    echo '---'
    echo
    cat "$body_file"
  }
}

claude_expected_content() {
  local body_file="$1"
  cat "$body_file"
}

ensure_dir() {
  local dir="$1"
  if [[ "$CHECK_MODE" -eq 0 ]]; then
    mkdir -p "$dir"
  fi
}

sync_file() {
  local label="$1"
  local target="$2"
  local expected_file="$3"

  if [[ -e "$target" && ! -f "$target" ]]; then
    ((conflicts+=1))
    echo "CONFLICT: $label exists and is not a regular file: $target" >&2
    return
  fi

  if [[ -f "$target" ]]; then
    if cmp -s "$expected_file" "$target"; then
      ((ok+=1))
      echo "OK: $label"
      return
    fi

    ((conflicts+=1))
    echo "CONFLICT: $label differs from org projection (refusing to overwrite)" >&2
    return
  fi

  if [[ "$CHECK_MODE" -eq 1 ]]; then
    ((missing+=1))
    echo "MISSING: $label"
    return
  fi

  cp "$expected_file" "$target"
  ((written+=1))
  echo "WRITTEN: $label"
}

ensure_dir "$CURSOR_RULES_DIR"
ensure_dir "$CLAUDE_RULES_DIR"

tmp_dir="$(mktemp -d)"
cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

shopt -s nullglob
rule_files=("$ORG_RULES_DIR"/*.md)
if [[ "${#rule_files[@]}" -eq 0 ]]; then
  echo "No org rule markdown files found in $ORG_RULES_DIR" >&2
  exit 1
fi

for body_file in "${rule_files[@]}"; do
  [[ -f "$body_file" ]] || continue

  rule_name="$(basename "$body_file" .md)"
  cursor_target="$CURSOR_RULES_DIR/${rule_name}.mdc"
  claude_target="$CLAUDE_RULES_DIR/${rule_name}.md"

  cursor_expected="$tmp_dir/${rule_name}.mdc"
  claude_expected="$tmp_dir/${rule_name}.md"
  cursor_expected_content "$body_file" "$rule_name" > "$cursor_expected"
  claude_expected_content "$body_file" > "$claude_expected"

  sync_file ".cursor/rules/${rule_name}.mdc" "$cursor_target" "$cursor_expected"
  sync_file ".claude/rules/${rule_name}.md" "$claude_target" "$claude_expected"
done

if [[ "$CHECK_MODE" -eq 1 ]]; then
  echo
  echo "Rules check summary: ok=$ok missing=$missing conflicts=$conflicts"
  if [[ "$missing" -gt 0 || "$conflicts" -gt 0 ]]; then
    exit 1
  fi
  exit 0
fi

echo
echo "Rules bootstrap summary: written=$written ok=$ok conflicts=$conflicts"
if [[ "$conflicts" -gt 0 ]]; then
  exit 1
fi
