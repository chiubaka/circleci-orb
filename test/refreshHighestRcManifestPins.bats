#! /usr/bin/env bats

setup() {
  load "helpers/setup"
  _setup
}

@test "refreshHighestRcManifestPins updates highest RC artifacts to current package versions" {
  repo="${BATS_TEST_TMPDIR}/refresh-pins"
  mkdir -p "$repo/apps/server" "$repo/.releases/2026.07.01.1/rc1" "$repo/.releases/2026.07.01.1/rc2"
  printf '%s\n' '{"name":"@ex/server","version":"5.2.1"}' >"$repo/apps/server/package.json"
  cat >"$repo/.releases/2026.07.01.1/rc2/manifest.yml" <<'EOF'
release: 2026.07.01.1
rc: 2
cutAt: 2026-07-03T09:15:00Z

artifacts:
  server: server-v5.2.1-rc.1
EOF
  cat >"$repo/.releases/2026.07.01.1/cycle.yml" <<'EOF'
release: 2026.07.01.1
openedAt: 2026-07-01T14:32:00Z
EOF

  cd "$repo"
  run env DEPLOYABLE_PACKAGES=server=apps/server \
    RELEASE_ID=2026.07.01.1 \
    node "$PROJECT_ROOT/src/scripts/refreshHighestRcManifestPins.mjs"
  assert_success
  run cat .releases/2026.07.01.1/rc2/manifest.yml
  assert_success
  assert_output --partial "server: server-v5.2.1"
  refute_output --partial "rc.1"
  assert_output --partial "cutAt: 2026-07-03T09:15:00Z"
}
