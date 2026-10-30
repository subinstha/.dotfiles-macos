#!/bin/zsh

# Status line for both Claude profiles: the account email, then ccusage.
#
#   subin@ypilot.ai · <ccusage statusline>
#
# The email comes from the running profile's .claude.json. CLAUDE_CONFIG_DIR is
# set for personal (~/.claude-personal, file inside the dir) and unset for
# work (the default ~/.claude, file at ~/.claude.json). Colors match the
# sketchybar meters: purple for personal, blue for work.

input=$(cat)

if [[ -n $CLAUDE_CONFIG_DIR ]]; then
  config="$CLAUDE_CONFIG_DIR/.claude.json"
else
  config="$HOME/.claude.json"
fi

email=$(jq -r '.oauthAccount.emailAddress // empty' "$config" 2>/dev/null)
[[ -n $email ]] || email="not logged in"

if [[ $CLAUDE_CONFIG_DIR == "$HOME/.claude-personal" ]]; then
  color=$'\e[38;2;198;160;246m'
else
  color=$'\e[38;2;138;173;244m'
fi

usage=$(print -r -- "$input" | /Users/subin/.bun/bin/bunx -q ccusage statusline 2>/dev/null)

print -rn -- "${color}${email}"$'\e[0m'"${usage:+ · $usage}"
