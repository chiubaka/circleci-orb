#!/usr/bin/env bash
# Stage release cycle writer for CircleCI consumers (orb packs scripts; sibling .mjs files are not
# on disk in the client repo). Copies writeReleaseCycle.mjs and lib helpers to /tmp.
set -euo pipefail

stage_dir=${WRITE_RELEASE_CYCLE_STAGE_DIR:-/tmp/chiubaka-release-cycle}
script_root=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)

mkdir -p "${stage_dir}/lib"
cp "${script_root}/lib/releaseCycle.mjs" "${stage_dir}/lib/"
cp "${script_root}/lib/trainId.mjs" "${stage_dir}/lib/"
cp "${script_root}/writeReleaseCycle.mjs" "${stage_dir}/"
cp "${script_root}/resolveReleaseCycleOnCommit.mjs" "${stage_dir}/"
cp "${script_root}/finalizeReleaseCycle.mjs" "${stage_dir}/"
cp "${script_root}/rollupReleaseNotes.mjs" "${stage_dir}/"
cp "${script_root}/validateReleaseCycle.mjs" "${stage_dir}/"
cp "${script_root}/validateReleaseManifest.mjs" "${stage_dir}/"

printf '%s\n' "${stage_dir}/writeReleaseCycle.mjs"
