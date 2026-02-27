---
description: Review dependency and type safety of branch vs main
---
Review all committed changes on the current branch compared to main (or master if main does not exist). Focus on dependency and type correctness — do not go online or read external docs.

Steps:
1. Identify the base branch (prefer `main`, fall back to `master`).
2. Collect the full diff of committed changes on this branch vs the base.
3. Look for dependency-related changes (package.json, go.mod, Cargo.toml, requirements.txt, pyproject.toml, pom.xml, build.gradle, flake.nix, etc.) and diff them.
4. For any dependency whose call sites appear in the diff, read the relevant source files locally to check whether the usage still matches the (potentially new) API signature.
5. Run the project's type-checker or build tool locally if one can be inferred from the repo (tsc, pyright, mypy, cargo check, go build, etc.) and capture output.
6. Identify and report issues; fix them if they are straightforward and confined to the changed files.

Base branch detection:
!`git rev-parse --verify main 2>/dev/null && echo main || echo master`

Current branch:
!`git rev-parse --abbrev-ref HEAD`

Commits on this branch vs base:
!`git log --oneline $(git rev-parse --verify main 2>/dev/null && echo main || echo master)..HEAD`

Full diff vs base:
!`git diff $(git rev-parse --verify main 2>/dev/null && echo main || echo master)..HEAD`

Dependency file changes:
!`git diff $(git rev-parse --verify main 2>/dev/null && echo main || echo master)..HEAD -- '*.json' '*.toml' '*.mod' '*.sum' '*.lock' 'requirements*.txt' 'pyproject.toml' 'pom.xml' 'build.gradle' '*.nix'`

Rules:
- Do not fetch from the internet or read README/changelog files.
- Use only local source files and git history to reason about API changes.
- Only fix issues that are clearly caused by the branch changes and are safe to touch.
- Leave unrelated pre-existing issues as findings, not fixes.

Output format:
- Branch summary (commits, files changed)
- Dependency changes (added / removed / version-bumped)
- API / signature concerns (based on local source inspection)
- Type / build check results
- Issues found & fixed
- Remaining issues (with file:line references)
- Verdict (ready / needs work)
