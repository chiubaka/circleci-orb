# shellcheck disable=SC2030,SC2031
setup() {
  load "helpers/setup"
  _setup
  unset GITHUB_TOKEN GH_TOKEN GITHUB_APP_ID GITHUB_APP_PRIVATE_KEY GITHUB_APP_INSTALLATION_ID
  MINT_GITHUB_TOKEN_SOURCE_ONLY=true
  # shellcheck disable=SC1091
  source "$PROJECT_ROOT/src/scripts/mintGithubToken.sh"
  export -f \
    base64url_encode \
    normalize_app_private_key \
    count_set_github_app_credentials \
    build_github_app_jwt \
    mint_github_app_installation_token \
    export_github_token \
    resolve_github_token

  TEST_APP_PRIVATE_KEY=$(
    openssl genrsa 2048 2>/dev/null
  )
}

teardown() {
  unset GITHUB_TOKEN GH_TOKEN GITHUB_APP_ID GITHUB_APP_PRIVATE_KEY GITHUB_APP_INSTALLATION_ID
}

@test "resolve_github_token returns provided GITHUB_TOKEN when app credentials are unset" {
  GITHUB_TOKEN=ghp_direct
  run resolve_github_token 0
  assert_success
  assert_output "ghp_direct"
}

@test "resolve_github_token fails when no credentials are configured" {
  run resolve_github_token 0
  assert_failure
  assert_output --partial "set GITHUB_APP_ID"
}

@test "resolve_github_token fails when app credentials are partial" {
  GITHUB_APP_ID=12345
  run resolve_github_token 1
  assert_failure
  assert_output --partial "set all of GITHUB_APP_ID"
}

@test "build_github_app_jwt produces a three-part RS256 token" {
  jwt=$(build_github_app_jwt "12345" "$TEST_APP_PRIVATE_KEY")
  [[ "$jwt" == *.*.* ]] || false
  IFS=. read -r header payload signature <<<"$jwt"
  [[ -n "$header" && -n "$payload" && -n "$signature" ]] || false
}

@test "normalize_app_private_key decodes base64-encoded PEM" {
  encoded=$(printf '%s' "$TEST_APP_PRIVATE_KEY" | base64 -w0 2>/dev/null || printf '%s' "$TEST_APP_PRIVATE_KEY" | base64)
  normalized=$(normalize_app_private_key "$encoded")
  [[ "$normalized" == *"BEGIN RSA PRIVATE KEY"* ]] || [[ "$normalized" == *"BEGIN PRIVATE KEY"* ]] || false
}

_run_mint_github_token_main() {
  # Orb steps inline this script; source it in tests so exports match CircleCI behavior.
  # shellcheck disable=SC1091
  source "$PROJECT_ROOT/src/scripts/mintGithubToken.sh"
  mint_github_token_main "$@"
}

@test "mint_github_token_main exports provided GITHUB_TOKEN" {
  GITHUB_TOKEN=ghp_direct
  _run_mint_github_token_main >/dev/null
  assert_equal "ghp_direct" "$GITHUB_TOKEN"
  assert_equal "ghp_direct" "$GH_TOKEN"
}

@test "mint_github_token_main writes provided GITHUB_TOKEN to BASH_ENV" {
  bash_env="${BATS_TEST_TMPDIR}/bash_env"
  : >"$bash_env"
  GITHUB_TOKEN=ghp_direct BASH_ENV="$bash_env" _run_mint_github_token_main >/dev/null
  run grep 'GITHUB_TOKEN=ghp_direct' "$bash_env"
  assert_success
  run grep 'GH_TOKEN=ghp_direct' "$bash_env"
  assert_success
}

@test "resolve_github_token prefers app credentials over an existing GITHUB_TOKEN" {
  GITHUB_TOKEN=ghp_direct
  GITHUB_APP_ID=12345
  GITHUB_APP_PRIVATE_KEY="$TEST_APP_PRIVATE_KEY"
  GITHUB_APP_INSTALLATION_ID=98765

  local curl_mock bindir
  curl_mock="$(mock_create)"
  mock_set_output "${curl_mock}" '{"token":"ghs_minted_test_token","expires_at":"2099-01-01T00:00:00Z"}'
  bindir=$(mktemp -d)
  ln -sf "$curl_mock" "${bindir}/curl"

  PATH="${bindir}:$PATH" run resolve_github_token 3
  assert_success
  assert_output "ghs_minted_test_token"
}

@test "mint_github_token_main mints installation token from app credentials" {
  curl_mock="$(mock_create)"
  mock_set_output "${curl_mock}" '{"token":"ghs_minted_test_token","expires_at":"2099-01-01T00:00:00Z"}'
  bindir=$(mktemp -d)
  ln -sf "$curl_mock" "${bindir}/curl"

  GITHUB_APP_ID=12345
  GITHUB_APP_PRIVATE_KEY="$TEST_APP_PRIVATE_KEY"
  GITHUB_APP_INSTALLATION_ID=98765
  PATH="${bindir}:$PATH" _run_mint_github_token_main >/dev/null

  assert_equal "ghs_minted_test_token" "$GITHUB_TOKEN"
  args=$(mock_get_call_args "$curl_mock" 1)
  [[ "$args" == *"/app/installations/98765/access_tokens"* ]] || false
  [[ "$args" == *"Authorization: Bearer "* ]] || false
}
