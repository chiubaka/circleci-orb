#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: bootstrap.sh [--check]

Delegates to org bootstrap scripts:
  1) bootstrap-skills.sh
  2) bootstrap-agents-md.sh

Options:
  --check     Run delegated scripts in read-only validation mode.
  -h, --help  Show this help.
EOF
}

CHECK_ARG=""
case "${1:-}" in
  --check)
    CHECK_ARG="--check"
    ;;
  "" )
    ;;
  -h|--help)
    usage
    exit 0
    ;;
  *)
    echo "Unknown argument: $1" >&2
    usage >&2
    exit 2
    ;;
esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"$SCRIPT_DIR/bootstrap-skills.sh" $CHECK_ARG
"$SCRIPT_DIR/bootstrap-agents-md.sh" $CHECK_ARG

echo "All bootstrap steps completed."
