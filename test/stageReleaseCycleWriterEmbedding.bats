setup() {
  load "helpers/setup"
  _setup
}

_extract_embedded() {
  local marker=$1
  python3 -c "
from pathlib import Path
import sys
marker, path = sys.argv[1], Path(sys.argv[2])
t = path.read_text()
start_m = f\"<<'{marker}'\\n\"
i = t.index(start_m) + len(start_m)
end = t.index(f'\\n{marker}', i)
sys.stdout.write(t[i : end + 1])
" "$marker" "$PROJECT_ROOT/src/scripts/stageReleaseCycleWriter.sh"
}

_assert_embedded_matches_source() {
  local marker=$1 source_rel=$2 embedded
  embedded="$(_extract_embedded "$marker")"
  assert_equal "$(cat "$PROJECT_ROOT/src/scripts/${source_rel}")" "$embedded"
}

@test "embedded release cycle scripts match source modules" {
  # Assert every module the stage writer embeds so drift in any packaged file is caught.
  _assert_embedded_matches_source CHIUBAKA_ORB_LIB_RELEASE_CYCLE_V1_EOF lib/releaseCycle.mjs
  _assert_embedded_matches_source CHIUBAKA_ORB_LIB_TRAIN_ID_MJS_V1_EOF lib/trainId.mjs
  _assert_embedded_matches_source CHIUBAKA_ORB_WRITE_RELEASE_CYCLE_V1_EOF writeReleaseCycle.mjs
  _assert_embedded_matches_source CHIUBAKA_ORB_RESOLVE_RELEASE_CYCLE_ON_COMMIT_V1_EOF resolveReleaseCycleOnCommit.mjs
  _assert_embedded_matches_source CHIUBAKA_ORB_FINALIZE_RELEASE_CYCLE_V1_EOF finalizeReleaseCycle.mjs
  _assert_embedded_matches_source CHIUBAKA_ORB_ROLLUP_RELEASE_NOTES_V1_EOF rollupReleaseNotes.mjs
  _assert_embedded_matches_source CHIUBAKA_ORB_VALIDATE_RELEASE_CYCLE_V1_EOF validateReleaseCycle.mjs
  _assert_embedded_matches_source CHIUBAKA_ORB_VALIDATE_RELEASE_MANIFEST_V1_EOF validateReleaseManifest.mjs
  _assert_embedded_matches_source CHIUBAKA_ORB_FORMAT_CHANGESETS_BATCH_RELEASE_NOTES_V1_EOF formatChangesetsBatchReleaseNotes.mjs
  _assert_embedded_matches_source CHIUBAKA_ORB_CHANGESET_CATEGORY_PREFIXES_V1_EOF changesetCategoryPrefixes.mjs
}

@test "stage script works when inlined like CircleCI orb include" {
  local stage_dir
  stage_dir="${BATS_TEST_TMPDIR}/chiubaka-release-cycle-inlined"
  run bash -c '
    set -euo pipefail
    WRITE_RELEASE_CYCLE_STAGE_DIR="$1" bash -s <<'"'"'INLINE_EOF'"'"'
'"$(cat "$PROJECT_ROOT/src/scripts/stageReleaseCycleWriter.sh")"'
INLINE_EOF
  ' bash "$stage_dir"
  assert_success
  assert [ -f "${stage_dir}/lib/releaseCycle.mjs" ]
  assert [ -f "${stage_dir}/validateReleaseManifest.mjs" ]
  assert [ -f "${stage_dir}/writeReleaseCycle.mjs" ]
}
