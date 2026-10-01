#!/usr/bin/env zsh

# Pins the bar to the built-in (laptop) panel, whatever the display arrangement.
#
# sketchybar's `display=N` is an arrangement index, which shifts every time a
# monitor is plugged in or the arrangement is rearranged, so it can't be
# hardcoded. system_profiler's `_spdisplays_displayID` is the same value as
# sketchybar's `DirectDisplayID`, which gives a stable way to go from
# "the internal panel" to "the index sketchybar wants".
#
# Falls back to `main` when the built-in isn't available (clamshell mode).

builtin_display_id() {
    system_profiler SPDisplaysDataType -json 2>/dev/null | jq -r '
        [ .SPDisplaysDataType[].spdisplays_ndrvs[]?
          | select(.spdisplays_connection_type == "spdisplays_internal")
          | ._spdisplays_displayID ] | first // empty'
}

arrangement_for() {
    sketchybar --query displays 2>/dev/null | jq -r --arg id "$1" '
        .[] | select((.DirectDisplayID|tostring) == $id) | ."arrangement-id"'
}

TARGET=main

DISPLAY_ID=$(builtin_display_id)
if [[ -n $DISPLAY_ID ]]; then
    ARRANGEMENT=$(arrangement_for "$DISPLAY_ID")
    [[ -n $ARRANGEMENT ]] && TARGET=$ARRANGEMENT
fi

sketchybar --bar display="$TARGET"
