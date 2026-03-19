---
description: Check changes against plan
---
Check current changes against the plan in PLAN.md and task.md (if they exist).

Rules:
- Determine related files by matching file paths referenced in the plan files; treat files under those directories as related.
- Focus only on related changes.
- Explicitly list any unrelated changed files under "Skipped (unrelated)".

Run these commands to gather context:
- `git status --porcelain=v1`
- `git diff --name-only`
- `git diff --name-only --staged`

Output format:
- Covered plan items
- Missing plan items
- Unplanned changes
- Skipped (unrelated)
