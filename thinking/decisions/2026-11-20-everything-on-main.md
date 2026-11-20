# Everything on main, no branches

**Date:** 2026-11-20 · **Who decided:** Haylee

**Decision:** No working branches. The overnight branch `claude/optimistic-allen-mifsgp` was merged into `main` on the MacBook Air (the only conflict was two INDEX lines, both kept). New work goes straight to main.

**Why:** Haylee: "There shouldn't be any branches." The branch's "git pull on claude/optimistic-allen-mifsgp" steps in status-latest now mean main.

**Also on the MacBook Air:** Xcode 26.6 couldn't type-check `Kit.safetyTexts` (KidSafety.swift) as one expression, so it is now built in steps (same output). After that, `swift test` in NutmegCore: 823 tests, all pass (about 15 minutes).
