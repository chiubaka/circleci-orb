#! /usr/bin/env bats
# Assert promote-prod-release configures git identity like sibling commit/tag jobs.
# CircleCI Docker executors have no default user.name / user.email; without this
# step the finalize commit fails with "Author identity unknown".

setup() {
  load "helpers/setup"
  _setup
}

@test "promote-prod-release job exposes configure-git-user parameters with sibling defaults" {
  run python3 - "$PROJECT_ROOT/src/jobs/promote-prod-release.yml" <<'PY'
from pathlib import Path
import re
import sys

text = Path(sys.argv[1]).read_text()
params = re.search(r"(?ms)^parameters:\n(.*?)(?=^steps:)", text)
if not params:
    print("no parameters block")
    sys.exit(1)
block = params.group(1)

def param_default(name: str):
    # Match one parameter stanza; stop before the next top-level param key.
    m = re.search(
        rf"(?m)^  {re.escape(name)}:\n((?:    .*\n)*)",
        block,
    )
    if not m:
        return None
    dm = re.search(r"(?m)^    default: (.+)$", m.group(1))
    return dm.group(1).strip() if dm else None

checks = {
    "configure-git-user": "true",
    "git-user-name": "CircleCI",
    "git-user-email": "circleci@chiubaka.com",
}
failed = False
for name, expected in checks.items():
    actual = param_default(name)
    if actual != expected:
        print(f"{name}: expected default {expected!r}, got {actual!r}")
        failed = True
sys.exit(1 if failed else 0)
PY
  assert_success
}

@test "promote-prod-release job configures git user after setup and before promote command" {
  run python3 - "$PROJECT_ROOT/src/jobs/promote-prod-release.yml" <<'PY'
from pathlib import Path
import re
import sys

text = Path(sys.argv[1]).read_text()
steps = re.search(r"(?ms)^steps:\n(.*)\Z", text)
if not steps:
    print("no steps block")
    sys.exit(1)
body = steps.group(1)

setup_at = body.find("- setup:")
configure_at = body.find("name: Configure git user")
promote_at = body.find("- promote-prod-release:")

if setup_at < 0:
    print("missing setup step")
    sys.exit(1)
if configure_at < 0:
    print("missing Configure git user step")
    sys.exit(1)
if promote_at < 0:
    print("missing promote-prod-release command step")
    sys.exit(1)
if not (setup_at < configure_at < promote_at):
    print(
        f"expected setup < configure < promote; got "
        f"setup={setup_at}, configure={configure_at}, promote={promote_at}"
    )
    sys.exit(1)

# Conditional when + defaults matching sibling jobs.
if "condition: << parameters.configure-git-user >>" not in body:
    print("missing when condition on configure-git-user")
    sys.exit(1)
# Pass identity through run-step env and quote at the shell so names with
# spaces / metacharacters are not word-split (safer than sibling inline expand).
required = [
    "GIT_USER_NAME: << parameters.git-user-name >>",
    "GIT_USER_EMAIL: << parameters.git-user-email >>",
    'git config --global user.name "$GIT_USER_NAME"',
    'git config --global user.email "$GIT_USER_EMAIL"',
]
for needle in required:
    if needle not in body:
        print(f"missing configure-git-user fragment: {needle}")
        sys.exit(1)
PY
  assert_success
}
