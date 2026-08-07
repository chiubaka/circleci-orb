#! /usr/bin/env bats

setup() {
  load "helpers/setup"
  _setup
}

@test "jobs that accept primary-branch forward it into nested setup" {
  # Avoid PyYAML: CircleCI bats image has no yaml module. Stdlib-only scan.
  run python3 - "$PROJECT_ROOT" <<'PY'
from pathlib import Path
import re
import sys

root = Path(sys.argv[1])
failures = []
expected = "primary-branch: << parameters.primary-branch >>"
setup_block = re.compile(r"(?m)^  - setup:\n((?:      .*\n)*)")

for path in sorted((root / "src" / "jobs").glob("*.yml")):
    text = path.read_text()
    if not re.search(r"(?m)^  primary-branch:\s*$", text):
        continue
    for match in setup_block.finditer(text):
        block = match.group(1)
        if not re.search(
            rf"(?m)^      {re.escape(expected)}[ \t]*$",
            block,
        ):
            failures.append(path.relative_to(root).as_posix())

if failures:
    print("Jobs missing primary-branch forward to setup:")
    for failure in failures:
        print(f"  {failure}")
    sys.exit(1)
PY
  assert_success
}
