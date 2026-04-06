#!/usr/bin/env bash
# Mirrors circleci/shellcheck orb defaults: recursive *.sh from repo root with the
# same --exclude list as .circleci/config.yml. Also checks test/*.bats and
# test/helpers/*.bash (local convention; orb does not scan those by default).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# Keep in sync with .circleci/config.yml shellcheck/check exclude
EXCLUDE="SC2148,SC2038,SC2086,SC2002,SC2016"

if [[ -x "$ROOT/node_modules/.bin/shellcheck" ]]; then
  SHELLCHECK=("$ROOT/node_modules/.bin/shellcheck")
elif command -v shellcheck >/dev/null 2>&1; then
  SHELLCHECK=(shellcheck)
else
  echo "shellcheck not found. Install deps: pnpm install" >&2
  exit 1
fi

sh_files=()
while IFS= read -r -d '' f; do
  sh_files+=("$f")
done < <(
  find . \( -path './.git' -o -path './node_modules' -o -path './.husky' \) -prune -o \
    -name '*.sh' -type f -print0
)

files=("${sh_files[@]}")
for f in test/*.bats test/helpers/*.bash; do
  [[ -e "$f" ]] || continue
  files+=("$f")
done

if [[ ${#files[@]} -eq 0 ]]; then
  echo "No shell scripts found to check." >&2
  exit 1
fi

exec "${SHELLCHECK[@]}" --exclude="$EXCLUDE" --severity=style "${files[@]}"
