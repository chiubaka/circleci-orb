setup() {
  load "helpers/setup"
  _setup
}

@test "embedded formatter in stage script matches formatChangesetsBatchReleaseNotes.mjs" {
  local embedded expected
  embedded="$(python3 -c "
from pathlib import Path
import sys
t = Path(sys.argv[1]).read_text()
start_m = \"<<'CHIUBAKA_ORB_FORMATTER_V1_EOF'\\n\"
i = t.index(start_m) + len(start_m)
end = t.index('\\nCHIUBAKA_ORB_FORMATTER_V1_EOF', i)
sys.stdout.write(t[i : end + 1])
" "$PROJECT_ROOT/src/scripts/stageFormatChangesetsBatchReleaseNotes.sh")"
  expected="$(cat "$PROJECT_ROOT/src/scripts/formatChangesetsBatchReleaseNotes.mjs")"
  assert_equal "$expected" "$embedded"
}
