#! /usr/bin/env bats

setup() {
  load "helpers/setup"
  _setup
  # shellcheck disable=SC1091
  source "$PROJECT_ROOT/src/scripts/lib/trainId.sh"
  export -f regex_escape_basic max_n_from_ls_remote_for_date utc_calendar_date_str compute_next_train_id_for_date
}

@test "max_n_from_ls_remote_for_date returns 0 when no matching tags" {
  run bash -c 'printf "%s\n" "deadbeef refs/tags/v1.0.0" | max_n_from_ls_remote_for_date "release/" "2026.05.08"'
  assert_success
  assert_output "0"
}

@test "max_n_from_ls_remote_for_date returns max N for prefix and UTC date" {
  run bash -c 'printf "%s\n" \
    "a refs/tags/release/2026.05.08.1" \
    "b refs/tags/release/2026.05.08.3^{}" \
    "c refs/tags/release/2026.05.08.2" \
    | max_n_from_ls_remote_for_date "release/" "2026.05.08"'
  assert_success
  assert_output "3"
}

@test "node trainId.mjs max-n matches bash helper" {
  local input_file
  input_file=$(mktemp)
  printf '%s\n' \
    "a refs/tags/release/2026.05.08.1" \
    "b refs/tags/release/2026.05.08.2" >"$input_file"
  run bash -c 'max_n_from_ls_remote_for_date "release/" "2026.05.08" < "$1"' _ "$input_file"
  assert_success
  assert_output "2"
  run node "$PROJECT_ROOT/src/scripts/lib/trainId.mjs" max-n --prefix "release/" --date "2026.05.08" --input "$input_file"
  assert_success
  assert_output "2"
  rm -f "$input_file"
}

@test "node trainId.mjs next-id increments from remote tags" {
  local clone
  cd "$BATS_TEST_TMPDIR" || exit 1
  parent=$(mktemp -d)
  bare="${parent}/origin.git"
  clone="${parent}/work"
  git init --bare "$bare" >/dev/null 2>&1
  mkdir -p "$clone"
  git -C "$clone" init >/dev/null 2>&1
  git -C "$clone" config user.email test@test
  git -C "$clone" config user.name Test
  bare_abs=$(cd "$(dirname "$bare")" && pwd)/$(basename "$bare")
  git -C "$clone" remote add origin "https://github.com/example/test.git"
  git -C "$clone" config url."file://${bare_abs}".insteadOf "https://github.com/example/test.git"
  echo base >"${clone}/README.md"
  git -C "$clone" add README.md
  git -C "$clone" commit -m init >/dev/null 2>&1
  git -C "$clone" branch -M master >/dev/null 2>&1
  git -C "$clone" push -u origin master >/dev/null 2>&1
  sha=$(git -C "$clone" rev-parse HEAD)
  git -C "$clone" -c tag.gpgSign=false tag -- "release/2099.01.01.1" "$sha"
  git -C "$clone" push origin "refs/tags/release/2099.01.01.1" >/dev/null 2>&1
  cd "$clone" || exit 1
  run env UTC_DATE_OVERRIDE=2099.01.01 node "$PROJECT_ROOT/src/scripts/lib/trainId.mjs" next-id --prefix "release/"
  assert_success
  assert_output "2099.01.01.2"
}
