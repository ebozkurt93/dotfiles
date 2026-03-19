---
description: Scan current changes for risks
---
Scan the current changes for potential risks (secrets, credentials, unsafe commands) without making edits.

Run these commands to gather context:
- `git status --porcelain=v1`
- `git diff`
- `git diff --staged`

Output format:
- Findings
- Risk level
- Suggested next steps
