---
name: clean-worktrees
description: Remove unused git worktrees in the current repo — ones with no open PR (merged/closed PR, or no PR and nothing unpushed) that no Claude/Codex session or other process is using. Checks open PRs with gh, live processes, worktree locks, recent Claude transcripts, and session scratchpads. Use when the user runs /clean-worktrees or asks to clean up, prune, or remove stale worktrees.
argument-hint: "[--yes] [--branches] [--active-minutes N]"
allowed-tools: ["Bash", "AskUserQuestion"]
---

# Clean up unused worktrees

Arguments: $ARGUMENTS

- `--yes`: remove the REMOVE bucket without asking first. The ASK bucket still needs a yes for each worktree.
- `--branches`: also delete the local branch of each removed worktree.
- `--active-minutes N`: a Claude transcript written within N minutes counts as in use (default 120).

## 1. Scan

From anywhere inside the repo:

```bash
python3 ~/.claude/skills/clean-worktrees/scan.py [--active-minutes N]
```

The scan is read-only (apart from `git fetch --prune`). It takes 10 to 20 seconds because `lsof` walks every process. It sorts each worktree into one of three buckets:

| Bucket | Meaning |
|---|---|
| **REMOVE** | Not in use, no open PR (the PR is merged or closed, or there was never one), clean tree, every commit is on a remote branch. Safe to remove. |
| **ASK** | Not in use and no open PR, but it has uncommitted files or commits that are on no remote branch. Removing it loses that work. |
| **KEEP** | Main worktree, the current worktree, has an open PR, has a live process inside (a Claude/Codex session, a shell, a dev server), is locked by a live pid, is in the scratchpad of a live session, or has a Claude transcript written recently. |

If `gh` fails, stop and tell the user. Never fall back to classifying without PR data.

## 2. Show the plan

Show the user a compact table: path (shortened, e.g. `.claude/worktrees/foo`), branch, and reason, grouped REMOVE, then ASK. Then give a single-line count of the KEEP bucket, plus the reasons for any KEEP entry that might surprise them, such as a lone idle `zsh` holding a worktree. If nothing is in REMOVE or ASK, say so and stop.

Unless `--yes` was given, confirm with AskUserQuestion: remove all of REMOVE, pick some, or cancel. For ASK, list what would be lost (run `git -C <path> status --short` and `git -C <path> log --oneline HEAD --not --remotes`) and ask about each worktree separately. The default answer is to keep it.

## 3. Remove

Just before removing, re-run `scan.py --json --no-fetch` and act only on entries that are still in the same bucket. A session may have started there in the meantime.

For each approved worktree:

```bash
git worktree unlock "<path>"      # only when the scan reported "stale lock"
git worktree remove "<path>"      # REMOVE bucket: never --force
git worktree remove --force "<path>"  # ASK bucket, only after an explicit yes for that worktree
```

If `git worktree remove` refuses, report the error and move on. Do not escalate to `--force` or `rm -rf`.

With `--branches`, delete the local branch after its worktree is removed. Use `git branch -D <branch>` for REMOVE entries: the scan already showed every commit is on a remote, and squash merges make `-d` refuse. For ASK entries use `git branch -d`, and keep the branch if that refuses. Never delete `main`, `master`, `dev`, `staging`, or the repo's default branch.

Finish with `git worktree prune`.

## 4. Report

Report what was removed, what was skipped and why, and any failures with their error text. If the project has per-worktree resources outside git, such as Docker compose projects, databases, or ports, mention that they may still be running. Do not touch them.

## Notes

- If this session is worktree-isolated and the harness blocks git commands that target other worktrees, tell the user to run `/clean-worktrees` from a session in the main checkout.
- Codex worktrees (`~/.codex/worktrees/...`) get the same rules. A dormant Codex thread whose worktree is removed can no longer resume in that tree. Say so when any are in REMOVE.
