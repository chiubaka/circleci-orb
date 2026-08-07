#! /usr/bin/env bats

setup() {
  load "helpers/setup"
  _setup
}

@test "jobs that accept primary-branch forward it into nested setup" {
  run python3 - "$PROJECT_ROOT" <<'PY'
from pathlib import Path
import sys

import yaml

root = Path(sys.argv[1])
failures = []

for path in sorted((root / "src" / "jobs").glob("*.yml")):
    doc = yaml.safe_load(path.read_text())
    params = doc.get("parameters") or {}
    if "primary-branch" not in params:
        continue
    for step in doc.get("steps") or []:
        if not isinstance(step, dict) or "setup" not in step:
            continue
        setup = step["setup"] or {}
        if "primary-branch" not in setup:
            failures.append(path.relative_to(root).as_posix())
        break

if failures:
    print("Jobs missing primary-branch forward to setup:")
    for failure in failures:
        print(f"  {failure}")
    sys.exit(1)
PY
  assert_success
}
