#!/usr/bin/env zsh

# Fills in the two usage rows for Claude Code (personal and work) and Codex:
#
#     5h  <rail>  <percent used>  <when it resets, Vancouver time>
#     7d  <rail>  <percent used>  <when it resets, Vancouver time>
#
# The 5h/7d column is static and lives in sketchybarrc-laptop; this only draws
# the rail and the numbers.
#
#   claude      -> api.anthropic.com/api/oauth/usage, OAuth token from the login
#                  keychain, personal profile (~/.claude-personal)
#   claude_work -> the same, work profile (~/.claude)
#   codex       -> rate_limits on the newest token_count event in ~/.codex/sessions
#
# Either source can go missing: the Claude token sits expired until Claude Code
# refreshes it, and the codex numbers only move when codex itself runs. So the
# last good reading is cached, and a window whose reset time has passed is
# redrawn as 0 rather than as a stale number.

emulate -L zsh
setopt null_glob
zmodload zsh/datetime

PROVIDER=$1
[[ $PROVIDER == (claude|claude_work|codex) ]] || {
    print -u2 "usage: ai_usage.sh <claude|claude_work|codex>"; exit 1
}
NAME=${NAME:-$PROVIDER}

CACHE_DIR="$HOME/.cache/sketchybar"
CACHE="$CACHE_DIR/ai_usage_$PROVIDER"

CELLS=8           # rail cells per row, so one cell is 12.5%
RAIL="━"          # box drawing: cells butt together into one unbroken rail
RESET_TZ=America/Vancouver
CELL=6            # AI_CELL in sketchybarrc-laptop
PAD=8             # AI_PAD in sketchybarrc-laptop

TRACK=0xff939ab7  # unfilled rail and the percentage text
OK=0xffa6da95
WARN=0xffeed49f
HIGH=0xffed8796
DEAD=0xff6e738d   # no reading at all

# Both readers print "5h_percent 5h_reset_epoch 7d_percent 7d_reset_epoch",
# or nothing when they can't get a number.

# Claude Code keeps one keychain entry per config dir. The default ~/.claude
# gets the bare service name. A dir picked with CLAUDE_CONFIG_DIR gets a suffix
# of the first 8 hex digits of sha256 of its path, cdca6511 for
# ~/.claude-personal.
claude_usage() {
    local suffix
    suffix=$(print -rn -- "$HOME/.claude-personal" | shasum -a 256 | cut -c1-8)
    oauth_usage "Claude Code-credentials-$suffix"
}

claude_work_usage() {
    oauth_usage "Claude Code-credentials"
}

oauth_usage() {
    local token json
    token=$(security find-generic-password -s "$1" -w 2>/dev/null) || return 1
    token=$(print -r -- "$token" | jq -r '.claudeAiOauth.accessToken // empty') || return 1
    [[ -n $token ]] || return 1

    json=$(curl -sf --max-time 5 https://api.anthropic.com/api/oauth/usage \
        -H "Authorization: Bearer $token" \
        -H "anthropic-beta: oauth-2025-04-20") || return 1

    print -r -- "$json" | jq -er '
        def epoch: if . == null then 0 else (.[0:19] + "Z" | fromdateiso8601) end;
        "\((.five_hour.utilization // 0) | round) \(.five_hour.resets_at | epoch) " +
        "\((.seven_day.utilization // 0) | round) \(.seven_day.resets_at | epoch)"'
}

# Collects, from each of the newest rollout files, its last rate_limits event
# and its last one that carries window numbers, then reads the newest of each
# by timestamp. File mtime is not enough to order them: parallel sessions
# interleave, and a session keeps logging tool output after its last reading.
#
# The two differ once a limit is hit. Codex then logs an event with a
# rate_limit_reached_type and null windows, so the numbers come from the last
# event that had them, and the fuller window is pinned to 100 for as long as
# that event stays the newest one.
codex_usage() {
    local -a days files
    local day file

    days=( $HOME/.codex/sessions/*/*/*(/Nom) )
    (( $#days )) || return 1

    for day in ${days[1,3]}; do
        files+=( $day/*.jsonl(.Nom) )
    done

    for file in ${files[1,8]}; do
        tail -r "$file" 2>/dev/null | grep -m1 '"rate_limits":{'
        tail -r "$file" 2>/dev/null | grep -m1 '"primary":{"used_percent"'
    done | jq -ers '
        map({t: .timestamp, r: ([.. | objects | .rate_limits? | select(. != null)] | last)})
        | sort_by(.t)
        | (last.r.rate_limit_reached_type != null) as $blocked
        | map(.r | select(.primary != null)) | last | select(. != null)
        | [(.primary.used_percent // 0), (.secondary.used_percent // 0)] as [$p, $s]
        | "\(if $blocked and $p >= $s then 100 else $p | round end) \(.primary.resets_at // 0) " +
          "\(if $blocked and $s > $p then 100 else $s | round end) \(.secondary.resets_at // 0)"'
}

# "Thu 16:19", or a placeholder of the same width when the reset time is
# unknown. Nine cells either way.
reset_label() {
    local -i ts=$1
    if (( ts > 0 )); then
        TZ=$RESET_TZ date -r $ts '+%a %H:%M'
    else
        print -r -- "    --:--"
    fi
}

rail_color() {
    if   (( $1 >= 80 )); then print -r -- $HIGH
    elif (( $1 >= 50 )); then print -r -- $WARN
    else                      print -r -- $OK
    fi
}

repeat_char() {
    local -i n=$1
    local out=""
    while (( n-- > 0 )); do out+=$2; done
    print -r -- "$out"
}

# icon holds the filled part of the rail and label the rest of it plus the
# numbers, which is how one item gets two colors. Every row is 23 cells
# whatever the fill level, and that is what lets the weekly row be pulled
# underneath the session row by a fixed negative padding. The icon keeps one
# cell even at nothing used, because an empty text run costs a pixel of
# sketchybar's per-run padding and would shift the row.
#
# A full rail leaves the label starting with the separator space, and
# sketchybar drops leading whitespace from a run along with 2px of its width.
# That row writes the space as left padding instead and gives the 2px back on
# the right.
draw_row() {
    local item=$1 pct=$2 reset=$3
    local fill text_color=$TRACK percent rest
    local -i filled=1 pad_left=0 pad_right=PAD

    if [[ -z $pct ]]; then
        fill=$DEAD
        text_color=$DEAD
        percent="  --"
        reset=0
    elif (( pct == 0 )); then
        fill=$TRACK
        percent="  0%"
    else
        fill=$(rail_color $pct)
        percent=$(printf '%3d%%' $pct)
        filled=$(( pct * CELLS / 100 ))
        (( filled < 1 )) && filled=1
        (( filled > CELLS )) && filled=CELLS
    fi

    rest="$percent $(reset_label $reset)"
    if (( filled == CELLS )); then
        pad_left=CELL
        pad_right=$(( PAD + 2 ))
    else
        rest="$(repeat_char $(( CELLS - filled )) $RAIL) $rest"
    fi

    sketchybar --set "$item" \
        icon="$(repeat_char $filled $RAIL)" \
        icon.color=$fill \
        label="$rest" \
        label.color=$text_color \
        label.padding_left=$pad_left \
        label.padding_right=$pad_right
}

reading=$(${PROVIDER}_usage)

if [[ -n $reading ]]; then
    mkdir -p "$CACHE_DIR"
    print -r -- "$reading" >| "$CACHE"
elif [[ -r $CACHE ]]; then
    reading=$(<"$CACHE")
fi

if [[ -n $reading ]]; then
    read -A w <<< "$reading"
    # A window whose reset time has gone by has already rolled over, so show it
    # empty rather than parroting a stale number. The next reset time is not
    # knowable until the source reports again.
    if (( w[2] > 0 && w[2] < EPOCHSECONDS )); then w[1]=0; w[2]=0; fi
    if (( w[4] > 0 && w[4] < EPOCHSECONDS )); then w[3]=0; w[4]=0; fi
    draw_row "$NAME.session" $w[1] $w[2]
    draw_row "$NAME.weekly"  $w[3] $w[4]
else
    draw_row "$NAME.session" "" 0
    draw_row "$NAME.weekly"  "" 0
fi
