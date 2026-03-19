---
description: Create a commit from staged changes
---
Create a git commit using only staged changes. Do not stage or modify files.

Explain the changes and rationale in 1-2 short paragraphs in the commit message body if needed.
Include a Co-authored-by line for Claude Sonnet 4.6.

Run these commands to gather context:
- `git diff --stat --staged`
- `git diff --staged`

Commit format (use a single command, no editor):
```
git commit -m "<subject>" -m "" -m "<paragraph 1>" -m "<paragraph 2 if needed>" -m "" -m "Co-authored-by: Claude Sonnet 4.6 <noreply@anthropic.com>"
```
