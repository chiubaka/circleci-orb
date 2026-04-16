setup() {
  load "helpers/setup"
  _setup
  PATH="$PROJECT_ROOT/src/scripts:$PATH"
}

@test "exits 0 and prints version when gh is already on PATH" {
  mkdir -p "${BATS_TEST_TMPDIR}/bin"
  cat >"${BATS_TEST_TMPDIR}/bin/gh" <<'EOF'
#!/bin/sh
echo "gh version 99.0.0 (test stub)"
EOF
  chmod +x "${BATS_TEST_TMPDIR}/bin/gh"

  PATH="${BATS_TEST_TMPDIR}/bin:${PATH}" run installGithubCli.sh

  assert_success
  assert_output --partial "gh version 99.0.0"
}
