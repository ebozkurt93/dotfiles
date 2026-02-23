---
description: Create a commit from staged changes
---
Create a git commit using only staged changes. Do not stage or modify files.

Explain the changes and rationale in 1-2 short paragraphs in the commit message body if needed.
Include a Co-authored-by line for the AI provider, chosen based on the active model at runtime.

Staged diff stats:
!`git diff --stat --staged`

Staged diff:
!`git diff --staged`

Commit format (use a single command, no editor):
git commit -m "<subject>" -m "" -m "<paragraph 1>" -m "<paragraph 2 if needed>" -m "" -m "Co-authored-by: <provider>"
