# Commit Changes

Create a git commit following these staging rules:

## Staging Rules

1. **If files are already staged** — commit ONLY the staged files. Do NOT stage or commit unstaged files unless the user explicitly says "commit all" or "commit everything".
2. **If the user says "commit all" or "commit everything"** — stage and commit all modified/untracked files (staged + unstaged).
3. **If NO files are staged** — stage and commit all modified/untracked files.

## Atomic Commits

Create **one commit per logical concern** instead of one big commit for everything:

1. After determining which files to commit (via staging rules), analyze the diff and group changes by logical concern (e.g., a bug fix, a feature, a refactor, a config change, a dependency update)
2. If all changes belong to **one concern** — create a single commit
3. If changes span **multiple concerns** — create separate sequential commits, staging only the relevant files for each
4. Each commit gets its own conventional commit message
5. Before committing, briefly list the grouping plan so the user can see what will be committed

## Instructions

1. Run `git status` to see staged and unstaged files
2. Run `git diff --cached` to see staged changes (if any)
3. Run `git diff` to see unstaged changes (if applicable per staging rules above)
4. Run `git log --oneline -5` to see recent commit message style
5. Apply the staging rules above to determine which files are eligible
6. Analyze the eligible changes and group them by logical concern (see Atomic Commits above)
7. Present the grouping plan briefly (e.g., "Group 1: fix(auth): ..., Group 2: chore(deps): ...")
8. For each group: stage only its files, then commit with an appropriate message
9. Repeat until all groups are committed

## Commit Message Format

Use [Conventional Commits](https://www.conventionalcommits.org/) format:

```
<type>(<optional scope>): <description>

<optional body>
```

### Types

- `feat` — new feature
- `fix` — bug fix
- `docs` — documentation only
- `style` — formatting, missing semicolons, etc. (no code change)
- `refactor` — code change that neither fixes a bug nor adds a feature
- `perf` — performance improvement
- `test` — adding or updating tests
- `build` — build system or external dependencies
- `ci` — CI configuration
- `chore` — maintenance tasks (deps, configs, etc.)
- `revert` — reverting a previous commit

### Rules

- Use imperative mood in the description (e.g., "add feature" not "added feature")
- Keep the first line (type + scope + description) under 72 characters
- Use lowercase for the description (no capital first letter)
- Do NOT end the description with a period
- Add a body with bullet points below for explanatory details when needed
- Do NOT include `Co-Authored-By` - only the current user should be the author
- Do NOT use markdown code blocks in the commit message
- Do NOT include placeholders
- Do NOT commit files that likely contain secrets (.env, credentials.json, etc.)
- If there are no changes to commit, inform the user instead of creating an empty commit
