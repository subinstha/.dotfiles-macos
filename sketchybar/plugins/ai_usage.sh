#!/usr/bin/env zsh

# Fills in the two usage rows for Claude Code and Codex:
#
#     5h  <rail>  <percent used>  <when it resets, Vancouver time>
#     7d  <rail>  <percent used>  <when it resets, Vancouver time>
#
# The 5h/7d column is static and lives in sketchybarrc-laptop; this only draws
# the rail and the numbers.
#
#   claude -> api.anthropic.com/api/oauth/usage, OAuth token from the login keychain
#   codex  -> rate_limits on the newest token_count event in ~/.codex/sessions
#
# Either source can go missing: the Claude token sits expired until Claude Code
# refreshes it, and the codex numbers only move when codex itself runs. So the
# last good reading is cached, and a window whose reset time has passed is
# redrawn as 0 rather than as a stale number.

emulate -L zsh
setopt null_glob
zmodload zsh/datetime

PROVIDER=$1
[[ $PROVIDER == claude || $PROVIDER == codex ]] || {
    print -u2 "usage: ai_usage.sh <claude|codex>"; exit 1
}
NAME=${NAME:-$PROVIDER}

CACHE_DIR="$HOME/.cache/sketchybar"
CACHE="$CACHE_DIR/ai_usage_$PROVIDER"

CELLS=8           # rail cells per row, so one cell is 12.5%
RAIL="━"          # box drawing: cells butt together into one unbroken rail
RESET_TZ=America/Vancouver

TRACK=0xff939ab7  # unfilled rail and the percentage text
OK=0xffa6da95
WARN=0xffeed49f
HIGH=0xffed8796
DEAD=0xff6e738d   # no reading at all

# Both readers print "5h_percent 5h_reset_epoch 7d_percent 7d_reset_epoch",
# or nothing when they can't get a number.

claude_usage() {
    local token json
    token=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null) || return 1
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

# Walks the newest rollout files until one carries a rate_limits payload. A
# session that just started has none yet, hence the loop rather than only
# looking at the newest file.
codex_usage() {
    local -a days files
    local day file line

    days=( $HOME/.codex/sessions/*/*/*(/Nom) )
    (( $#days )) || return 1

    for day in ${days[1,3]}; do
        files+=( $day/*.jsonl(.Nom) )
    done

    for file in ${files[1,8]}; do
        line=$(tail -r "$file" 2>/dev/null | grep -m1 '"rate_limits":{') || continue
        print -r -- "$line" | jq -er '
            [.. | objects | .rate_limits? | select(. != null)] | last |
            "\((.primary.used_percent // 0) | round) \(.primary.resets_at // 0) " +
            "\((.secondary.used_percent // 0) | round) \(.secondary.resets_at // 0)"' && return 0
    done
    return 1
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
draw_row() {
    local item=$1 pct=$2 reset=$3
    local fill text_color=$TRACK percent
    local -i filled=1

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

    sketchybar --set "$item" \
        icon="$(repeat_char $filled $RAIL)" \
        icon.color=$fill \
        label="$(repeat_char $(( CELLS - filled )) $RAIL) $percent $(reset_label $reset)" \
        label.color=$text_color
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
