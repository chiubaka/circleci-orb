#! /usr/bin/env bash
# Resolve GITHUB_TOKEN for downstream orb steps: mint a GitHub App installation token
# when GITHUB_APP_ID, GITHUB_APP_PRIVATE_KEY, and GITHUB_APP_INSTALLATION_ID are set;
# otherwise use GITHUB_TOKEN when provided directly.
set -euo pipefail

github_api_url=${GITHUB_API_URL:-https://api.github.com}

base64url_encode() {
  openssl base64 -e -A | tr '+/' '-_' | tr -d $'\n=' 
}

normalize_app_private_key() {
  local raw=$1
  if [[ "$raw" == *'-----BEGIN'* ]]; then
    if [[ "$raw" == *'\\n'* ]]; then
      printf '%b' "$raw"
    else
      printf '%s' "$raw"
    fi
    return 0
  fi
  printf '%s' "$raw" | base64 -d
}

count_set_github_app_credentials() {
  local count=0
  [[ -n "${GITHUB_APP_ID:-}" ]] && count=$((count + 1))
  [[ -n "${GITHUB_APP_PRIVATE_KEY:-}" ]] && count=$((count + 1))
  [[ -n "${GITHUB_APP_INSTALLATION_ID:-}" ]] && count=$((count + 1))
  printf '%s' "$count"
}

build_github_app_jwt() {
  local app_id=$1
  local private_key_pem=$2
  local key_file now issued_at expires_at header payload unsigned signature

  now=$(date +%s)
  issued_at=$((now - 60))
  expires_at=$((now + 540))

  header='{"alg":"RS256","typ":"JWT"}'
  payload=$(printf '{"iat":%s,"exp":%s,"iss":"%s"}' "$issued_at" "$expires_at" "$app_id")

  header_b64=$(printf '%s' "$header" | base64url_encode)
  payload_b64=$(printf '%s' "$payload" | base64url_encode)
  unsigned="${header_b64}.${payload_b64}"

  key_file=$(mktemp)
  normalize_app_private_key "$private_key_pem" >"$key_file"
  signature=$(printf '%s' "$unsigned" | openssl dgst -sha256 -sign "$key_file" -binary | base64url_encode)
  rm -f "$key_file"
  printf '%s.%s' "$unsigned" "$signature"
}

mint_github_app_installation_token() {
  local app_id=$1
  local private_key_pem=$2
  local installation_id=$3
  local jwt response token

  jwt=$(build_github_app_jwt "$app_id" "$private_key_pem")
  response=$(
    curl -fsS -X POST \
      -H "Authorization: Bearer ${jwt}" \
      -H "Accept: application/vnd.github+json" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      "${github_api_url%/}/app/installations/${installation_id}/access_tokens"
  )
  token=$(printf '%s' "$response" | python3 -c 'import json,sys; print(json.load(sys.stdin)["token"])')
  if [[ -z "$token" ]]; then
    echo "mintGithubToken: GitHub API returned an empty installation token." >&2
    exit 1
  fi
  printf '%s' "$token"
}

export_github_token() {
  local token=$1
  export GITHUB_TOKEN="$token"
  export GH_TOKEN="$token"
  if [[ -n "${BASH_ENV:-}" ]]; then
    {
      printf 'export GITHUB_TOKEN=%q\n' "$token"
      printf 'export GH_TOKEN=%q\n' "$token"
    } >>"$BASH_ENV"
  fi
}

resolve_github_token() {
  local app_credentials_set=${1:-0}

  if [[ "$app_credentials_set" -eq 3 ]]; then
    mint_github_app_installation_token \
      "$GITHUB_APP_ID" \
      "$GITHUB_APP_PRIVATE_KEY" \
      "$GITHUB_APP_INSTALLATION_ID"
    return 0
  fi

  if [[ "$app_credentials_set" -ne 0 ]]; then
    echo "mintGithubToken: set all of GITHUB_APP_ID, GITHUB_APP_PRIVATE_KEY, and GITHUB_APP_INSTALLATION_ID together, or none of them." >&2
    exit 1
  fi

  if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    printf '%s' "$GITHUB_TOKEN"
    return 0
  fi

  echo "mintGithubToken: set GITHUB_APP_ID, GITHUB_APP_PRIVATE_KEY, and GITHUB_APP_INSTALLATION_ID to mint a token, or set GITHUB_TOKEN directly." >&2
  exit 1
}

mint_github_token_main() {
  local token app_credentials_set

  app_credentials_set=$(count_set_github_app_credentials)
  token=$(resolve_github_token "$app_credentials_set")
  export_github_token "$token"

  if [[ "$app_credentials_set" -eq 3 ]]; then
    echo "mintGithubToken: exported minted GitHub App installation token as GITHUB_TOKEN."
  else
    echo "mintGithubToken: exported provided GITHUB_TOKEN."
  fi
}

if [[ "${MINT_GITHUB_TOKEN_SOURCE_ONLY:-}" != "true" ]]; then
  mint_github_token_main "$@"
fi
