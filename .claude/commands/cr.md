---
description: "Deep code review for bugs, duplication, silent failures, maintainability, and conventions"
allowed-tools: ["Bash", "Glob", "Grep", "Read", "Agent"]
argument-hint: "[pr | branch-name]"
---

# Code Review

Review code changes for duplication of existing patterns, maintainability, consistency with conventions, and potential bugs.

## Step 1: Determine Review Mode

Parse the arguments:
- `/cr` — local mode, diff against default base branch (`main` or `master`, whichever exists)
- `/cr pr` — PR mode, use `gh pr diff` for the current branch's PR
- `/cr <branch>` — local mode, diff against specified branch

## Step 2: Gather Context

1. **Get the diff and changed files:**
   - Local mode: `git diff <base-branch>...HEAD` + `git diff` (uncommitted). Changed files via `git diff --name-only <base-branch>...HEAD` + `git diff --name-only`
   - PR mode: `gh pr diff` and `gh pr diff --name-only`. Also `gh pr view --json title,body,headRefName,baseRefName`

2. **Find project guidelines:**
   - Root CLAUDE.md (if exists)
   - CLAUDE.md files in directories containing changed files
   - Read their contents

3. **Recent history:** `git log --oneline -20`

## Step 3: Load Agent Prompts and Launch 6 Parallel Agents

The 6 agent prompts are stored as markdown files. Read each one using the Read tool:

1. Read `~/.dotfiles-macos/.claude/plugins/code-review/agents/duplication-convention-checker.md`
2. Read `~/.dotfiles-macos/.claude/plugins/code-review/agents/deep-bug-reviewer.md`
3. Read `~/.dotfiles-macos/.claude/plugins/code-review/agents/guidelines-compliance.md`
4. Read `~/.dotfiles-macos/.claude/plugins/code-review/agents/silent-failure-hunter.md`
5. Read `~/.dotfiles-macos/.claude/plugins/code-review/agents/maintainability-reviewer.md`
6. Read `~/.dotfiles-macos/.claude/plugins/code-review/agents/quality-assurance.md`

For each file, extract the content AFTER the frontmatter (after the second `---`). This is the agent's system prompt.

Then launch ALL 6 agents in parallel using the Agent tool. For each agent, construct the prompt by combining:
- The agent's system prompt (from the markdown file)
- The full diff
- The list of changed files
- The CLAUDE.md contents (if any)
- The review mode (local vs PR) and base branch

The 6 agents are:
1. **duplication-convention-checker** — Does new code duplicate existing patterns or break conventions?
2. **deep-bug-reviewer** — Deep bug hunt with full context, git blame, and history
3. **guidelines-compliance** — CLAUDE.md rules and code comment compliance
4. **silent-failure-hunter** — Error handling audit, zero tolerance for silent failures
5. **maintainability-reviewer** — Complexity, naming, readability, coupling
6. **quality-assurance** — Test coverage gaps, type design, comment accuracy

## Step 4: Score and Filter

After all agents return, evaluate each issue:

- Only include issues with confidence >= 80
- For CLAUDE.md violations, verify the guideline explicitly mentions the issue
- Filter out:
  - Pre-existing issues not introduced in this change
  - Issues linters, typecheckers, or CI will catch
  - Pedantic nitpicks a senior engineer would skip
  - Issues on lines the user did not modify
  - Changes in functionality that are clearly intentional

## Step 5: Present Results

Show the user a clear report:

```
## Code Review Summary

**Mode:** [Local diff against <branch> | PR #<number>]
**Files reviewed:** <count>
**Issues found:** <count> (after filtering)

### Critical Issues (must fix)
<numbered list — file:line, description, which agent found it>

### Important Issues (should fix)
<numbered list — file:line, description, which agent found it>

### Suggestions (consider)
<numbered list — file:line, description, which agent found it>

### What Looks Good
<brief positive observations>
```

Keep it concise. No emojis. Link to specific files and lines.
For each issue, state the problem and the fix — nothing more.
Do NOT post anything to GitHub unless the user explicitly asks.
