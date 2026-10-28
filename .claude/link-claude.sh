#!/bin/sh

# Symlink the portable Claude Code config into both Claude profiles.
#
# Split of responsibilities:
#   ~/.dotfiles-macos/ai/skills   skills, shared by every agent (Claude, Codex).
#                                 Agent-neutral, so it sits outside .claude.
#   ~/.dotfiles-macos/.claude     Claude-specific config - commands, hooks and
#                                 the shared settings.local.json. Lives in git.
#   ~/.claude                     work profile (`cw`, the desktop app, IDEs).
#   ~/.claude-personal            personal profile (`cc`, plain `claude`,
#                                 everything else; CLAUDE_CONFIG_DIR).
#
# Each profile logs into its own subscription and keeps its own history,
# sessions, projects (so auto-memory too) and .claude.json with MCP servers.
# Only the config below is shared. Keychain credentials are per profile:
# "Claude Code-credentials" for ~/.claude, and a hashed suffix of the path for
# anything set through CLAUDE_CONFIG_DIR.
#
# Work owns the default ~/.claude because the desktop app only reads that
# folder: it has no setting for another config dir, and its "Import CLI
# sessions" ignores CLAUDE_CONFIG_DIR. Until 2026-10-27 the split was the other
# way round (personal in ~/.claude, work in ~/.claude-work);
# swap-claude-profiles.sh moved the data over.

# Skills used to be symlinks into a ~/.agents/skills store managed by the
# `skills` CLI, which meant the dotfiles pointed at content that was not in
# git. They are real directories under ai/skills now. Project-specific skills
# (the Celigo set) live in their own repo instead of loading everywhere.

ROOT="$HOME/.dotfiles-macos"
DOTFILES="$ROOT/.claude"
SKILLS="$ROOT/ai/skills"
WORK="$HOME/.claude"
PERSONAL="$HOME/.claude-personal"

for CLAUDE in "$WORK" "$PERSONAL"; do
  mkdir -p "$CLAUDE"

  # rm -rf, not rm -f: on a second run the target is a symlink, but on the
  # first it may be a real directory Claude Code created.
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
done

# The personal profile starts from a copy of the work settings.json (model,
# effort, AWS deny rules, notification hooks, enabled plugins). After that the
# two drift on their own, since /config writes to whichever profile is running.
[ -e "$PERSONAL/settings.json" ] || cp -p "$WORK/settings.json" "$PERSONAL/settings.json"

# Plugins are installed once, in ~/.claude, and the personal profile reads the
# same directory. installed_plugins.json stores absolute paths into
# ~/.claude/plugins, so a copy would point back there anyway. A real directory
# is left alone: that is plugin state the personal profile made itself.
if [ ! -e "$PERSONAL/plugins" ] || [ -L "$PERSONAL/plugins" ]; then
  rm -f "$PERSONAL/plugins"
  ln -s "$WORK/plugins" "$PERSONAL/plugins"
fi

# Work repos keep one auto-memory, in the work profile, so a personal (`cc`)
# session in ComplyPilot remembers the same things a `cw` one does. Claude Code
# names the folder after the cwd with "/" turned into "-". Same rule as
# plugins: a real directory is the personal profile's own and stays.
for project in "-Users-subin-projects-ComplyPilot"; do
  mkdir -p "$WORK/projects/$project/memory" "$PERSONAL/projects/$project"
  link="$PERSONAL/projects/$project/memory"
  if [ ! -e "$link" ] || [ -L "$link" ]; then
    rm -f "$link"
    ln -s "$WORK/projects/$project/memory" "$link"
  fi
done

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

echo "Claude Code config linked into $WORK and $PERSONAL."
