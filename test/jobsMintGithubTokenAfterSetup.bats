#! /usr/bin/env bats

setup() {
  load "helpers/setup"
  _setup
}

@test "install-and-push jobs mint github token after setup by default" {
  run python3 - "$PROJECT_ROOT" <<'PY'
from pathlib import Path
import re
import sys

root = Path(sys.argv[1])
jobs = [
    "changesets-release-pr.yml",
    "changesets-gated-publish.yml",
    "promote-prod-release.yml",
]
failures = []

for name in jobs:
    path = root / "src" / "jobs" / name
    text = path.read_text()
    if not re.search(
        r"(?m)^  mint-github-token:\n(?:.*\n)*?    default: true\n",
        text,
    ):
        failures.append(f"{name}: missing mint-github-token parameter defaulting to true")
        continue
    # Mint step must appear after the setup invocation.
    setup_idx = text.find("\n  - setup:\n")
    mint_idx = text.find("\n        - mint-github-token\n")
    if setup_idx < 0:
        failures.append(f"{name}: missing setup step")
    elif mint_idx < 0:
        failures.append(f"{name}: missing mint-github-token step")
    elif mint_idx < setup_idx:
        failures.append(f"{name}: mint-github-token must run after setup")

if failures:
    print("Job mint-after-setup contract failures:")
    for failure in failures:
        print(f"  {failure}")
    sys.exit(1)
PY
  assert_success
}

@test "setup install prefers GITHUB_PACKAGES_READ_TOKEN via override-ci-command" {
  run python3 - "$PROJECT_ROOT" <<'PY'
from pathlib import Path
import sys

text = (Path(sys.argv[1]) / "src" / "commands" / "setup.yml").read_text()
required = [
    "assertGithubPackagesTokenForInstall.sh",
    "GITHUB_PACKAGES_READ_TOKEN",
    "GITHUB_PACKAGES_TOKEN",
    "override-ci-command",
    "pnpm install --frozen-lockfile",
]
missing = [item for item in required if item not in text]
if missing:
    print("setup.yml missing required install-token wiring:")
    for item in missing:
        print(f"  {item}")
    sys.exit(1)
PY
  assert_success
}
