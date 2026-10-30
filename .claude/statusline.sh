#!/bin/zsh

# Status line for both Claude profiles: the account email, then ccusage.
#
#   subin@ypilot.ai · <ccusage statusline>
#
# The email comes from the running profile's .claude.json. CLAUDE_CONFIG_DIR is
# set for personal (~/.claude-personal, file inside the dir) and unset for
# work (the default ~/.claude, file at ~/.claude.json). Colors match the
# sketchybar meters: purple for personal, blue for work.
#
# ccusage takes 1-5s because it re-reads every transcript, and Claude Code
# drops a status line run that is still going when the next update fires. So
# the ccusage part comes from a per-session cache, refreshed in the background
# at most every REFRESH seconds, and the line itself prints right away.

REFRESH=20
CACHE_DIR="$HOME/.cache/claude-statusline"

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

session=$(print -r -- "$input" | jq -r '.session_id // "none"' 2>/dev/null)
mkdir -p "$CACHE_DIR"
cache="$CACHE_DIR/$session"
lock="$cache.lock"

# zsh/stat-free age check: find prints the file only if it is fresh.
if [[ -z $(find "$cache" -newermt "-${REFRESH} seconds" 2>/dev/null) ]] \
  && mkdir "$lock" 2>/dev/null; then
  # Detached and with stdout closed, so Claude Code doesn't wait on it.
  {
    out=$(print -r -- "$input" | /Users/subin/.bun/bin/bunx -q ccusage statusline 2>/dev/null)
    [[ -n $out ]] && print -r -- "$out" >| "$cache.tmp" && mv "$cache.tmp" "$cache"
    rmdir "$lock"
  } >/dev/null 2>&1 </dev/null &!
fi

# A lock older than a minute is from a refresh that died; clear it.
find "$lock" -maxdepth 0 -not -newermt "-60 seconds" -exec rmdir {} \; 2>/dev/null

# One cache file per session, so drop the ones nobody has touched in a day.
find "$CACHE_DIR" -type f -mtime +1 -delete 2>/dev/null

usage=$(<"$cache" 2>/dev/null)

print -rn -- "${color}${email}"$'\e[0m'"${usage:+ · $usage}"
