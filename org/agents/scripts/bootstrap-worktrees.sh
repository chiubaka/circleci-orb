#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: bootstrap-worktrees.sh [--check]

Ensures repository layout for in-repo git worktrees under .worktrees/:

  1) Root .gitignore contains a .worktrees/ entry
  2) .vscode/settings.json excludes **/.worktrees from files.exclude
     and search.exclude (merges into existing settings; does not wipe others)
  3) .cursorignore does not ignore .worktrees (warn / fail in --check)

Does not create worktrees. Does not add .worktrees to .cursorignore.

Options:
  --check     Read-only validation mode. Does not write files.
              Exits non-zero if required entries are missing or conflict.
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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$REPO_ROOT" ]]; then
  local_root="$(cd "$SCRIPT_DIR/../.." && pwd)"
  embedded_root="$(cd "$SCRIPT_DIR/../../.." && pwd)"
  if [[ -d "$embedded_root/org/agents/scripts" ]]; then
    REPO_ROOT="$embedded_root"
  else
    REPO_ROOT="$local_root"
  fi
fi

GITIGNORE="$REPO_ROOT/.gitignore"
VSCODE_SETTINGS="$REPO_ROOT/.vscode/settings.json"
CURSORIGNORE="$REPO_ROOT/.cursorignore"

ok=0
written=0
missing=0
conflicts=0
warnings=0

gitignore_has_worktrees() {
  local file="$1"
  [[ -f "$file" ]] || return 1
  # Match common ignore forms for the directory (anchored or unanchored).
  grep -Eq '^[[:space:]]*(/)?\.worktrees(/)?[[:space:]]*$' "$file" \
    || grep -Eq '^[[:space:]]*\*\*/\.worktrees(/)?[[:space:]]*$' "$file"
}

cursorignore_blocks_worktrees() {
  local file="$1"
  [[ -f "$file" ]] || return 1
  # Directory forms plus child globs (.worktrees/*, .worktrees/**/*, …).
  grep -Eq '^[[:space:]]*(/)?\.worktrees(/|\*\*|/\*|/\*\*|/\*\*/\*)?[[:space:]]*$' "$file" \
    || grep -Eq '^[[:space:]]*\*\*/\.worktrees(/|\*\*|/\*|/\*\*|/\*\*/\*)?[[:space:]]*$' "$file" \
    || grep -Eq '^[[:space:]]*\.worktrees/\*\*[[:space:]]*$' "$file"
}

ensure_gitignore() {
  if gitignore_has_worktrees "$GITIGNORE"; then
    ((ok+=1))
    echo "OK: .gitignore includes .worktrees/"
    return
  fi

  if [[ "$CHECK_MODE" -eq 1 ]]; then
    ((missing+=1))
    echo "MISSING: .gitignore entry for .worktrees/"
    return
  fi

  if [[ -e "$GITIGNORE" && ! -f "$GITIGNORE" ]]; then
    ((conflicts+=1))
    echo "CONFLICT: .gitignore exists and is not a regular file" >&2
    return
  fi

  if [[ -f "$GITIGNORE" ]]; then
    if [[ -s "$GITIGNORE" ]] && [[ "$(tail -c 1 "$GITIGNORE" | wc -l)" -eq 0 ]]; then
      printf '\n' >> "$GITIGNORE"
    fi
    {
      echo
      echo "# In-repo git worktrees (see org ADR 0047)"
      echo ".worktrees/"
    } >> "$GITIGNORE"
  else
    {
      echo "# In-repo git worktrees (see org ADR 0047)"
      echo ".worktrees/"
    } > "$GITIGNORE"
  fi

  ((written+=1))
  echo "WRITTEN: .gitignore entry for .worktrees/"
}

merge_vscode_settings() {
  local mode="$1" # check | write
  python3 - "$VSCODE_SETTINGS" "$mode" <<'PY'
import json
import re
import sys
from pathlib import Path

settings_path = Path(sys.argv[1])
mode = sys.argv[2]
exclude_key = "**/.worktrees"

def strip_jsonc(text: str) -> str:
    """Strip // and /* */ comments outside strings; drop trailing commas."""
    out = []
    i = 0
    n = len(text)
    in_string = False
    escape = False
    while i < n:
        ch = text[i]
        if in_string:
            out.append(ch)
            if escape:
                escape = False
            elif ch == "\\":
                escape = True
            elif ch == '"':
                in_string = False
            i += 1
            continue
        if ch == '"':
            in_string = True
            out.append(ch)
            i += 1
            continue
        if ch == "/" and i + 1 < n:
            nxt = text[i + 1]
            if nxt == "/":
                i += 2
                while i < n and text[i] not in "\r\n":
                    i += 1
                continue
            if nxt == "*":
                i += 2
                while i + 1 < n and not (text[i] == "*" and text[i + 1] == "/"):
                    i += 1
                i = min(i + 2, n)
                continue
        out.append(ch)
        i += 1
    return re.sub(r",(\s*[}\]])", r"\1", "".join(out))

def load_settings(path: Path):
    if not path.exists():
        return {}, "missing"
    if not path.is_file():
        return None, "not_file"
    try:
        text = path.read_text(encoding="utf-8")
        if not text.strip():
            return {}, "empty"
        data = json.loads(strip_jsonc(text))
    except json.JSONDecodeError as exc:
        return None, f"invalid_json:{exc}"
    if not isinstance(data, dict):
        return None, "not_object"
    return data, "ok"

data, status = load_settings(settings_path)
if data is None:
    print(f"CONFLICT:{status}")
    sys.exit(2)

needed = {
    "files.exclude": {exclude_key: True},
    "search.exclude": {exclude_key: True},
}

def section_ok(section_name: str) -> str:
    section = data.get(section_name)
    if section is None:
        return "missing"
    if not isinstance(section, dict):
        return "conflict_type"
    if exclude_key not in section:
        return "missing"
    if section[exclude_key] is True:
        return "ok"
    return "conflict_value"

results = {name: section_ok(name) for name in needed}

if mode == "check":
    if all(v == "ok" for v in results.values()):
        print("OK")
        sys.exit(0)
    if any(v.startswith("conflict") for v in results.values()):
        print("CONFLICT:" + ",".join(f"{k}={v}" for k, v in results.items()))
        sys.exit(2)
    print("MISSING:" + ",".join(k for k, v in results.items() if v == "missing"))
    sys.exit(1)

# write mode
if any(v.startswith("conflict") for v in results.values()):
    print("CONFLICT:" + ",".join(f"{k}={v}" for k, v in results.items()))
    sys.exit(2)

changed = False
for section_name, patch in needed.items():
    section = data.get(section_name)
    if section is None:
        data[section_name] = dict(patch)
        changed = True
        continue
    if not isinstance(section, dict):
        print(f"CONFLICT:{section_name}=conflict_type")
        sys.exit(2)
    for key, value in patch.items():
        if key not in section:
            section[key] = value
            changed = True
        elif section[key] is not True:
            print(f"CONFLICT:{section_name}=conflict_value")
            sys.exit(2)

if not changed and all(v == "ok" for v in results.values()):
    print("OK")
    sys.exit(0)

settings_path.parent.mkdir(parents=True, exist_ok=True)
settings_path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
print("WRITTEN")
sys.exit(0)
PY
}

ensure_vscode_settings() {
  local result
  local rc=0
  set +e
  result="$(merge_vscode_settings "$([[ "$CHECK_MODE" -eq 1 ]] && echo check || echo write)")"
  rc=$?
  set -e

  case "$rc" in
    0)
      if [[ "$result" == "OK" ]]; then
        ((ok+=1))
        echo "OK: .vscode/settings.json excludes **/.worktrees"
      else
        ((written+=1))
        echo "WRITTEN: .vscode/settings.json excludes **/.worktrees"
      fi
      ;;
    1)
      ((missing+=1))
      echo "MISSING: .vscode/settings.json excludes **/.worktrees ($result)"
      ;;
    2)
      ((conflicts+=1))
      echo "CONFLICT: .vscode/settings.json ($result)" >&2
      ;;
    *)
      ((conflicts+=1))
      echo "CONFLICT: .vscode/settings.json merge failed (rc=$rc result=$result)" >&2
      ;;
  esac
}

check_cursorignore() {
  if [[ ! -f "$CURSORIGNORE" ]]; then
    ((ok+=1))
    echo "OK: .cursorignore absent (worktrees not blocked)"
    return
  fi

  if cursorignore_blocks_worktrees "$CURSORIGNORE"; then
    if [[ "$CHECK_MODE" -eq 1 ]]; then
      ((conflicts+=1))
      echo "CONFLICT: .cursorignore ignores .worktrees (remove so agents can access in-repo worktrees)" >&2
    else
      ((warnings+=1))
      echo "WARNING: .cursorignore ignores .worktrees — remove that entry so agents can access in-repo worktrees from the primary checkout" >&2
    fi
    return
  fi

  ((ok+=1))
  echo "OK: .cursorignore does not ignore .worktrees"
}

ensure_gitignore
ensure_vscode_settings
check_cursorignore

if [[ "$CHECK_MODE" -eq 1 ]]; then
  echo
  echo "Worktrees check summary: ok=$ok missing=$missing conflicts=$conflicts warnings=$warnings"
  if [[ "$missing" -gt 0 || "$conflicts" -gt 0 ]]; then
    exit 1
  fi
  exit 0
fi

echo
echo "Worktrees bootstrap summary: written=$written ok=$ok conflicts=$conflicts warnings=$warnings"
if [[ "$conflicts" -gt 0 ]]; then
  exit 1
fi
