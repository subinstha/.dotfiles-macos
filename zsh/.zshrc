# History
HISTSIZE=10000
SAVEHIST=10000
HISTFILE=~/.zsh_history
setopt HIST_IGNORE_DUPS SHARE_HISTORY APPEND_HISTORY

# Claude Code uses one profile: ~/.claude. Credentials are stored per config
# dir (keychain service "Claude Code-credentials-<sha256 of the path>"), so a
# stale CLAUDE_CONFIG_DIR inherited from a pre-merge parent process sends
# Claude Code to a second, unauthenticated profile and it asks you to log in
# again. Unset it here so every shell lands on the default.
unset CLAUDE_CONFIG_DIR

# Completion (cached - regenerates once per day)
autoload -Uz compinit
compinit -C
zstyle ':completion:*' menu select

eval "$(zoxide init zsh)"
eval "$(starship init zsh)"

bindkey "^X\\x7f" backward-kill-line

source ~/.zsh_aliases
source ~/.zsh_install


# Google Cloud SDK (disabled - slow)
# if [ -f '/Users/subin/clones/google-cloud-sdk/path.zsh.inc' ]; then . '/Users/subin/clones/google-cloud-sdk/path.zsh.inc'; fi
# if [ -f '/Users/subin/clones/google-cloud-sdk/completion.zsh.inc' ]; then . '/Users/subin/clones/google-cloud-sdk/completion.zsh.inc'; fi

export R_HOME=/usr/local/bin/R

export R_HOME=/Library/Frameworks/R.framework/Resources
export PATH="$HOME/.local/bin:$PATH"

# Added by Antigravity
export PATH="/Users/subin/.antigravity/antigravity/bin:$PATH"

# Added by Antigravity
export PATH="/Users/subin/.antigravity/antigravity/bin:$PATH"

# bun completions
[ -s "/Users/subin/.bun/_bun" ] && source "/Users/subin/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# opencode
export PATH=/Users/subin/.opencode/bin:$PATH

# AWS Profile
# export AWS_PROFILE=applypilot  # disabled: use the [default] profile (account 787085304398, us-east-1)
eval "$(rbenv init - zsh)"

export PATH="/opt/homebrew/opt/libpq/bin:$PATH"

# Added by Antigravity IDE
export PATH="/Users/subin/.antigravity-ide/antigravity-ide/bin:$PATH"
. "/Users/subin/.deno/env"

# ── Headroom: context-compression proxy for coding agents ────────────────────
# CLI installed with: uv tool install --python 3.13 "headroom-ai[proxy,mcp,code]"
# (deliberately NOT the desktop app, and never the [all] extra — it drags in
# torch/CUDA). Binary lands in ~/.local/bin, already on PATH above.
#
# `headroom wrap claude` starts the proxy on :8787, points ANTHROPIC_BASE_URL at
# it, and registers Headroom's MCP retrieve tool for the launched session.
# Run it from a project dir — Claude Code picks up that project's .mcp.json and
# local-scope MCP servers from the cwd, so `cchr` in ComplyPilot gets the repo's
# aws-billing / aws-pricing / aws-cloudwatch servers plus Headroom's.
#
#   --1m  Claude Code drops the context-1m beta header behind a custom
#         ANTHROPIC_BASE_URL and silently caps at 200k; this restores the 1M
#         window by forcing ANTHROPIC_MODEL=<model>[1m].
#
# ANTHROPIC_MODEL is pinned per-function because --1m's own fallback is a
# hardcoded claude-opus-4-8 (headroom 0.34.0, _DEFAULT_1M_MODEL in cli/wrap.py)
# — without it you get silently downgraded. Headroom only appends the [1m]
# suffix to whatever is already set, so pinning picks the model.
#
#   cchr    Opus 5,   1M window  — Headroom-wrapped equivalent of `cc`
#   cchrs   Sonnet 5, 1M window
#   cxhr    Codex CLI (OpenAI; needs OPENAI_API_KEY or a ChatGPT login)
#
# The permission mode mirrors the `cc` alias in ~/.zsh_aliases. These used to
# pin CLAUDE_CONFIG_DIR too, back when there were separate work and personal
# profiles; that split was merged into ~/.claude on 2026-08-19. The unset at
# the top of this file keeps every shell on the default config dir.
#
# Switching model mid-session with /model drops the [1m] suffix and falls back
# to 200k — relaunch with the other function instead.
cchr()  { ANTHROPIC_MODEL="${ANTHROPIC_MODEL:-claude-opus-5}"   headroom wrap claude --1m --permission-mode auto "$@"; }
cchrs() { ANTHROPIC_MODEL="${ANTHROPIC_MODEL:-claude-sonnet-5}" headroom wrap claude --1m --permission-mode auto "$@"; }
cxhr()  { headroom wrap codex "$@"; }
