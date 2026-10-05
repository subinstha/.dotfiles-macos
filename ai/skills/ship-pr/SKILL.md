---
name: ship-pr
description: Review the current ComplyPilot change, move it to a CI-valid branch when needed, commit outstanding work, push it, open a pull request, and prepare its final title and body. Use when the user asks to ship changes, push a feature branch and open a PR, or run the repo's former Claude `/ship-pr` workflow.
---

# Ship a ComplyPilot pull request

Treat any text following `$ship-pr` as optional hints for the base branch, branch slug, or change scope. Infer omitted details from the repository state and diff.

## Inspect and scope

1. Read the root `CLAUDE.md`; it is this repository's source of truth. Obey its shared-worktree and Git guardrails.
2. Run `gh auth status`. If the active GitHub user is not `subinstha`, switch with `gh auth switch --user subinstha`.
3. Inspect the current branch, status, staged diff, unstaged diff, and commits relative to the intended base.
4. Default the PR base to `dev`. Use `staging` only when the user explicitly requests it. Use `master` only for an explicitly requested hotfix.
5. Identify only the files belonging to this change. Never absorb unrelated dirty files from another session. For an unfamiliar dirty file, inspect `git diff origin/dev --stat -- <file>` first, leave it unstaged, and report it.

## Use a CI-valid branch

Re-read `.github/workflows/branch-naming-check.yml` because it is authoritative.

- Keep an existing `feature/`, `fix/`, `chore/`, `hotfix/`, or `revert/` branch.
- Keep an already-pushed `claude/*` branch, but never create a new `claude/*` or `dependabot/*` branch manually.
- Never ship ordinary changes directly from `dev`, `staging`, `master`, `worktree-*`, local-only `claude/*`, or invalid prefixes such as `feat/`.
- When a new branch is needed, choose `feature/` for new functionality, `fix/` for bug fixes, `chore/` for maintenance/refactors/docs/tests/performance/CI/dependencies, `hotfix/` for an urgent production fix, or `revert/` for a revert. Build a lowercase hyphenated slug from the change or user's hint.
- Preserve the current commits and working tree when creating the branch. In the shared main worktree, take `/tmp/complypilot-main-worktree.lock` before any operation that rewrites tracked files.

## Review, commit, and push

1. Stage only explicit paths that belong to this change. Never use `git add .` or `git add -A` blindly.
2. Invoke `$cr` to review the scoped diff and fix confirmed findings before committing. For auth, RBAC, permissions, secrets, or migrations, also perform a focused security review using an available security-review capability.
3. If changes remain, invoke `$commit` and follow its atomic staging rules. Do not add AI co-author trailers.
4. Push with `git push -u origin <branch>`.

## Open and describe the PR

1. Create the PR with `gh pr create --base <base> --head <branch>`.
2. Follow `.github/pull_request_template.md`. Fill Summary, type checkboxes, applicable checklist items, Migration notes or `N/A`, and an evidence-based Test plan. Never claim tests that did not run.
3. Invoke `$prdesc` to draft the final title and body. Because `$prdesc` requires approval before editing GitHub, show the draft and wait for approval before applying it.
4. Report the PR URL, tests and reviews run, unrelated dirty files left untouched, and whether merging into `dev` will trigger deployment for the touched services.

## Constraints

- Never stage, commit, or overwrite another session's work.
- Never restart containers or deploy manually; follow the repository's CI deployment rules.
- Do not open a PR from an invalid head branch.
- Do not change the requested base silently.
