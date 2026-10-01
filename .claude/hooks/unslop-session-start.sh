#!/usr/bin/env bash
# Load the unslop skill into context at session start, for every profile.
#
# unslop's description says "Must always apply", but a skill only applies if it
# gets invoked, and that is a judgment call the model can simply miss - it did,
# for a whole session, on 2026-08-19. A hook is not a judgment call.
#
# Injects the skill body directly rather than telling the model to go invoke it:
# a reminder is still something to comply with, whereas content already in
# context just applies. ~6.6KB, well under 2k tokens.
#
# Wired from settings.local.json, which link-claude.sh symlinks into ~/.claude.
# Reads the skill from its canonical dotfiles path rather than through the
# skills symlink, so it still works if that link is missing.
set -uo pipefail

SKILL="${HOME}/.dotfiles-macos/ai/skills/unslop/SKILL.md"

# Missing skill must not break session start - emit nothing and exit clean.
[ -r "$SKILL" ] || exit 0

{
  printf '%s\n\n' "The unslop skill is loaded below and applies to everything you write this session - code comments, docstrings, commit messages, PR descriptions, and your replies. Apply it without being asked and without announcing it."
  cat "$SKILL"
} | jq -Rs '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: .}}'
