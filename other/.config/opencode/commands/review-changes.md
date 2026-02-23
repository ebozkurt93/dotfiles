---
description: Review current changes against plan
---
Review the current working tree changes and compare them against the plan in @PLAN.md and @task.md.

Rules:
- Determine related files by matching file paths referenced in the plan files; treat files under those directories as related.
- Ignore unrelated changes in the review, but explicitly list them under "Skipped (unrelated)".
- If no plan-related files are found, say so and provide a minimal high-level summary.

Changed files:
!`git status --porcelain=v1`

Unstaged changed file list:
!`git diff --name-only`

Staged changed file list:
!`git diff --name-only --staged`

Unstaged diff:
!`git diff`

Staged diff:
!`git diff --staged`

Output format:
- Summary
- Plan alignment
- Risks/issues
- Suggestions
- Skipped (unrelated)
