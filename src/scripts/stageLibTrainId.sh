#! /usr/bin/env bash
# Materialize UTC train id bash helpers for CircleCI consumers (orb packs parent scripts;
# lib/trainId.sh is not on disk in the client repo). Keep heredoc body in sync with lib/trainId.sh.
set -euo pipefail
train_id_out=${TRAIN_ID_STAGE_PATH:-/tmp/chiubaka-lib-trainId.sh}
cat >"$train_id_out" <<'CHIUBAKA_ORB_LIB_TRAIN_ID_V1_EOF'
#! /usr/bin/env bash
# UTC train id helpers (ADR 0037). Sourced by release train and promotion-tag scripts.
# Canonical logic also lives in trainId.mjs for Node callers.

regex_escape_basic() {
  printf '%s' "$1" | sed 's/[][\\.^$*+?(){}|]/\\&/g'
}

utc_calendar_date_str() {
  if [[ -n "${UTC_DATE_OVERRIDE:-}" ]]; then
    printf '%s' "$UTC_DATE_OVERRIDE"
    return
  fi
  date -u +%Y.%m.%d
}

# stdin: git ls-remote --tags style lines; args: train_tag_prefix date_str
max_n_from_ls_remote_for_date() {
  local prefix=$1 date_str=$2 escaped_prefix escaped_date pattern line ref tag_suffix n max_n=-1
  escaped_prefix=$(regex_escape_basic "$prefix")
  escaped_date=$(regex_escape_basic "$date_str")
  pattern="^${escaped_prefix}${escaped_date}\\.[0-9]+$"
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -n "$line" ]] || continue
    ref=$(awk '{print $2}' <<<"$line")
    [[ "$ref" == refs/tags/* ]] || continue
    ref=${ref#refs/tags/}
    [[ "$ref" == *'^'* ]] && ref=${ref%^*}
    [[ "$ref" =~ $pattern ]] || continue
    tag_suffix=${ref#"$prefix"}
    n=${tag_suffix##*.}
    if [[ "$n" =~ ^[0-9]+$ ]] && [[ "$n" -gt "$max_n" ]]; then
      max_n=$n
    fi
  done
  if [[ "$max_n" -lt 0 ]]; then
    printf '%s' "0"
  else
    printf '%s' "$max_n"
  fi
}

compute_next_train_id_for_date() {
  local prefix=$1 date_str=$2 ls_out max_n next_n
  ls_out=$(git ls-remote --tags origin 2>/dev/null || true)
  max_n=$(printf '%s\n' "$ls_out" | max_n_from_ls_remote_for_date "$prefix" "$date_str")
  next_n=$((max_n + 1))
  printf '%s' "${date_str}.${next_n}"
}

compute_next_train_id() {
  compute_next_train_id_for_date "${TRAIN_TAG_PREFIX:-release/}" "$(utc_calendar_date_str)"
}
CHIUBAKA_ORB_LIB_TRAIN_ID_V1_EOF
