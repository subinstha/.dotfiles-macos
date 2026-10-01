---
name: prdesc
description: Draft and, after explicit user approval, update the current GitHub pull request title and description from its actual diff, commits, template, and existing body. Use when the user asks to write, refresh, improve, or apply a PR title or description.
---

# Update PR Title and Description

Update the current pull request from its actual changes while preserving valuable material already in its body.

## Inspect

1. Run `gh pr view --json number,title,body,headRefName,baseRefName`.
2. Look for `.github/pull_request_template.md`, `.github/PULL_REQUEST_TEMPLATE.md`, or `docs/pull_request_template.md`.
3. Run `gh pr diff`.
4. Review commits between the PR base and `HEAD`. Use the returned `baseRefName`; prefer the corresponding remote-tracking ref when available. Do not assume the base is `main`.
5. Understand both what changed and why before drafting.

If there is no current PR, stop and tell the user. Do not create one unless explicitly requested.

## Preserve

Keep existing material unless the user asks to remove it:

- Markdown images and HTML `<img>` tags
- Video links and attachments
- Jira, Linear, GitHub issue, and other ticket links
- `Fixes #`, `Closes #`, and `Relates to #` references

Preserve these in their original location when practical, otherwise place them in the most appropriate template section.

## Draft

Create an imperative title under 72 characters using one prefix:

- `[Feature]`
- `[Fix]`
- `[Docs]`
- `[Style]`
- `[Refactor]`
- `[Perf]`
- `[Test]`
- `[Chore]`

Follow the repository PR template when one exists and fill every applicable section. Without a template, use:

```markdown
## Summary
Briefly explain what the PR does and why.

## Changes
- List the key changes.

## Context
Explain relevant reasoning, tradeoffs, and related issues.
```

Do not invent tests, verification, issue links, screenshots, or behavior that the diff does not support.

## Review and Apply

1. Show the proposed title and complete body to the user.
2. Wait for explicit approval or requested revisions.
3. After approval, apply the exact approved content with `gh pr edit`. Prefer `--body-file` for multiline Markdown so shell quoting cannot alter it.
4. Re-read the PR title and body and report the confirmed result.

Never edit the PR before approval.
