# Changesets publishing fixtures

Static copies of minimal monorepo layouts used by **integration** Bats tests under `test/integration/`.

- **`minimal-monorepo/`** — pnpm workspace with one package `@fixture/lib`, a valid `.changeset/config.json`, and one pending changeset file. Used to exercise `runChangesetsReleasePr.sh` helpers against a realistic tree without calling `changeset version` or `gh` (those stay mocked or uninvoked in tests).

Do not reference these paths from orb `include()` scripts; they are test-only.

**CI:** `.circleci/config.yml` runs `pnpm exec bats -r ./test`, which executes every `*.bats` file under `test/` recursively, including `test/integration/changesetsPublishing.integration.bats` that copies these fixtures into a temp directory.
