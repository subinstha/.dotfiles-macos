---
name: cr
description: Run a deep, high-confidence code review of staged changes, local branch changes, or a GitHub pull request using six specialized review perspectives. Use when the user asks for `/cr`, a thorough code review, PR review, bug hunt, convention audit, silent-failure audit, maintainability review, or test/type/comment quality review. Never post to GitHub unless explicitly asked.
---

# Deep code review

Treat text following `$cr` as an optional mode: `pr`, a PR number/link, or a base branch. Keep the workflow read-only unless the user separately asks for fixes.

## Determine the diff

1. Read applicable `AGENTS.md` files. If they point to `CLAUDE.md` or another source of truth, read it and any service-scoped guidance for changed files.
2. Choose the review target:
   - `$cr` with staged changes: review the staged diff first.
   - `$cr` with no staged changes: review committed branch changes against the repository's default base plus relevant unstaged changes.
   - `$cr pr` or a PR number/link: use `gh pr view` and `gh pr diff` for that PR.
   - `$cr <branch>`: compare against the named branch.
3. Gather the full diff, changed-file list, relevant full-file context, and recent history. Do not review unrelated pre-existing code as though the change introduced it.

## Run six review perspectives

Read the body after YAML frontmatter in each file under `references/`:

1. `duplication-convention-checker.md`
2. `deep-bug-reviewer.md`
3. `guidelines-compliance.md`
4. `silent-failure-hunter.md`
5. `maintainability-reviewer.md`
6. `quality-assurance.md`

Spawn one subagent per perspective and give each only the relevant raw artifacts: its reference prompt, diff, changed files, applicable repository guidance, review mode, and base. Run as many concurrently as the environment permits and queue the rest without omitting a perspective. Ask every reviewer for findings with file/line, impact, fix, and confidence.

If subagents are unavailable, perform the six passes sequentially and say so in the report.

## Verify and filter

Independently verify every candidate against the changed lines and full context. Keep only findings with confidence of at least 80/100. Exclude:

- Pre-existing issues not introduced or materially worsened by the change
- Findings that do not affect modified behavior
- Matters reliably caught by existing formatter, linter, typechecker, or required CI unless they reveal a deeper defect
- Pedantic style preferences without an explicit project rule
- Intentional behavior supported by the diff and requirements
- Claimed guideline violations without an exact applicable written rule

Deduplicate overlapping findings and rank by user impact: critical, important, then suggestion.

## Report

Lead with findings. For each finding, provide a clickable file/line, the concrete problem, why it matters, and the smallest credible fix. Then include:

- Review mode and base or PR
- Files reviewed
- Count by severity
- Brief test-coverage or residual-risk note
- A short "What looks good" section only when useful

If no findings survive verification, say so plainly and mention remaining test or context gaps. Do not post comments, approve, request changes, edit code, or mutate the PR unless the user explicitly asks.
