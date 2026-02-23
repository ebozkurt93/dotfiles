---
description: Scan current changes for risks
---
Scan the current changes for potential risks (secrets, credentials, unsafe commands) without making edits.

Changed files:
!`git status --porcelain=v1`

Unstaged diff:
!`git diff`

Staged diff:
!`git diff --staged`

Output format:
- Findings
- Risk level
- Suggested next steps
