#!/bin/bash
#Title: Privacy Mode Toggle
#Description: Enables and disables privacy mode by edit the degub.json       
#Author: Rootjunky (Updated on github by jakeis0dd)
#Version: 2

FILE=/usr/debug.json

# create file if missing
[ -f "$FILE" ] || echo '{}' > "$FILE"

if grep -q '"censor"[[:space:]]*:[[:space:]]*true' "$FILE"; then
    echo '{ "censor": false }' > "$FILE"
LOG "Rebooting server for privacy mode to turn off"
else
    echo '{ "censor": true }' > "$FILE"
LOG "Rebooting server for privacy mode to take effect"
fi
# Refresh Pager UI so Client Mode SSID display updates
service pineapplepager restart >/dev/null 2>&1 || true
