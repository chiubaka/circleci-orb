---
"@chiubaka/circleci-orb": patch
---

Fix: default `target-ref` to empty on promote/tag/release commands so pipelines without `pipeline.git.revision` (API/schedule triggers) still compile; scripts already fall back to `CIRCLE_SHA1` or `HEAD`.
