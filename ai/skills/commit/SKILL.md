---
name: commit
description: Create one or more atomic Git commits from the current working tree using explicit staging rules and Conventional Commits. Use when the user asks Codex to commit changes, commit staged files, commit everything, or split changes into logical commits.
---

# Commit Changes

Create focused commits while respecting the user's existing staging choices and unrelated work.

## Determine Eligible Changes

1. Run `git status --short`.
2. Run `git diff --cached`.
3. Run `git diff` when unstaged changes may be eligible.
4. Run `git log --oneline -5` to learn the repository's message style.

Apply these rules:

1. If files are already staged, commit only the staged changes. Do not stage unstaged files unless the user explicitly says `commit all` or `commit everything`.
2. If the user says `commit all` or `commit everything`, include all appropriate modified and untracked files.
3. If nothing is staged, include the appropriate modified and untracked files in scope.
4. Never include likely secrets such as `.env` or credential files.
5. Do not include unrelated or ambiguously owned changes. If including them would be necessary, stop and ask.
6. If there is nothing eligible to commit, report that instead of creating an empty commit.

## Plan Atomic Commits

Group eligible changes by logical concern, such as a feature, fix, refactor, test update, configuration change, or dependency update.

- Use one commit when all changes serve one concern.
- Use separate sequential commits when concerns are independent.
- Keep required tests, migrations, generated outputs, and supporting changes with the concern they validate or enable.
- Briefly show the grouping plan before committing.
- Stage explicit files or hunks for each group. Never use a broad staging command when it would capture changes outside that group.

## Write Commit Messages

**One line. Subject only.** No body, no bullet list, no trailers.

```text
<type>(<optional scope>): <description>
```

Allowed types:

- `feat`
- `fix`
- `docs`
- `style`
- `refactor`
- `perf`
- `test`
- `build`
- `ci`
- `chore`
- `revert`

Rules:

- Write one subject line and stop. Never write a body unless the user explicitly asks for one.
- Say what the commit changes, not why it changes or how it works. Rationale, root-cause analysis, and before/after narration belong in the PR description or a code comment.
- Use imperative mood. Start the description lowercase. No trailing period.
- Keep the whole subject under 72 characters; aim for 50.
- Name the change, not the process. Write `fix(blocks): define missing font weight tokens`, not `fix(blocks): correct the repairs from the previous pass`.
- If a commit cannot be described in one line, it is doing too much. Split it. Atomic commits are what replaces the body.
- Do not use Markdown code fences or placeholders in the message.
- Do not add `Co-Authored-By` or other AI attribution. The current user is the sole author.

### Run the unslop skill on every subject

Load the `unslop` skill and apply it to each subject line before committing. A commit subject is
prose, so it carries the same AI tells as any other writing. The rules that bite hardest here:

- No em dashes. No curly quotes.
- Cut puffery and AI vocabulary. No `comprehensive`, `robust`, `enhance`, `streamline`,
  `leverage`, `underscore`, `crucial`.
- Cut filler and hedging. `in order to` is `to`. `attempt to fix` is `fix`.
- Cut adverbs. An adverb propping up a weak verb means the verb is wrong. `significantly improve`
  is the measured change.
- Use the plain word. `use`, not `utilize` or `leverage`.
- Use the natural number of items. Do not pad a list to three.
- Name the mechanism, not the feeling. `define --icon-stroke-width` beats `improve icon styling`.
  If the subject could sit unchanged on another project's commit, it says nothing about this one.
- Prefer a concrete word to an abstract metaphor noun. `base`, not `substrate`. `add`, not
  `wedge in`. `way`, not `vector`.

## Commit

For each planned group:

1. Stage only that group's files or hunks.
2. Review the staged diff.
3. Create the commit with a single `-m` flag: `git commit -m "<subject>"`.
4. Verify the resulting commit before continuing to the next group.

Afterward, report the created commit hashes and subjects plus any changes intentionally left uncommitted. Do not push unless the user explicitly asks.
