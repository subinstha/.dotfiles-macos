#!/bin/sh

# Symlink the portable Claude Code config into ~/.claude.
#
# Split of responsibilities:
#   ~/.dotfiles-macos/ai/skills   skills, shared by every agent (Claude, Codex).
#                                 Agent-neutral, so it sits outside .claude.
#   ~/.dotfiles-macos/.claude     Claude-specific config - commands, hooks and
#                                 the shared settings.local.json. Lives in git.
#   ~/.claude                     runtime state - history, sessions, projects,
#                                 plugins, settings.json. Machine-local.
#
# There used to be three profiles (.claude, .claude-work, .claude-personal)
# selected with CLAUDE_CONFIG_DIR. Collapsed to one on 2026-08-19; the work
# account is gone and two personal profiles were never worth the split.
#
# Skills used to be symlinks into a ~/.agents/skills store managed by the
# `skills` CLI, which meant the dotfiles pointed at content that was not in
# git. They are real directories under ai/skills now. Project-specific skills
# (the Celigo set) live in their own repo instead of loading everywhere.

ROOT="$HOME/.dotfiles-macos"
DOTFILES="$ROOT/.claude"
SKILLS="$ROOT/ai/skills"
CLAUDE="$HOME/.claude"

mkdir -p "$CLAUDE"

# rm -rf, not rm -f: on a second run the target is a symlink, but on the first
# it may be a real directory Claude Code created.
for item in commands hooks; do
  rm -rf "$CLAUDE/$item"
  ln -s "$DOTFILES/$item" "$CLAUDE/$item"
done

rm -rf "$CLAUDE/skills"
ln -s "$SKILLS" "$CLAUDE/skills"

# settings.local.json overrides settings.json, and holds everything worth
# carrying between machines: statusLine, permission allowlist, all hooks.
# settings.json stays a real file - Claude Code rewrites it from /config.
rm -f "$CLAUDE/settings.local.json"
ln -s "$DOTFILES/settings.local.json" "$CLAUDE/settings.local.json"

# --- Shared skills for Codex ---
# Every skill in ai/skills goes to Codex too, so adding a directory there is the
# only step; re-run this script and both agents pick it up.
#
# Codex cannot take a whole-directory symlink the way ~/.claude/skills does: it
# owns ~/.codex/skills/.system and rewrites it on upgrade, so replacing the
# directory would either hide its six built-in skills or make Codex recreate
# them inside this git repo. Link per skill instead. A bare SKILL.md is all
# Codex needs; the optional agents/openai.yaml only sets display name, icon and
# invocation policy.
if [ -d "$HOME/.codex" ]; then
  mkdir -p "$HOME/.codex/skills"

  # Drop links from skills that have since been deleted or renamed. Only ones
  # pointing into ai/skills, so anything Codex or another tool put here stays.
  for link in "$HOME"/.codex/skills/*; do
    [ -L "$link" ] || continue
    case "$(readlink "$link")" in
      "$SKILLS"/*) [ -e "$link" ] || rm -f "$link" ;;
    esac
  done

  for skill in "$SKILLS"/*/; do
    [ -d "$skill" ] || continue
    name=$(basename "$skill")
    target="$HOME/.codex/skills/$name"
    # Never clobber a real directory - that would be a Codex-installed skill of
    # the same name, and deleting it is not this script's call.
    if [ -e "$target" ] && [ ! -L "$target" ]; then
      echo "skipping $name: real directory already in ~/.codex/skills" >&2
      continue
    fi
    rm -f "$target"
    ln -s "${skill%/}" "$target"
  done
fi

# --- Shared custom plugins ---
# Install manually with:
#   /plugins install /Users/subin/.dotfiles-macos/.claude/plugins/code-review

echo "Claude Code config linked into $CLAUDE."
