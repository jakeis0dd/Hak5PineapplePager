#!/bin/sh
set -eu

SSID="${_RECON_SELECTED_AP_SSID:-}"

if [ -z "$SSID" ]; then
    ALERT "No SSID selected from Recon."
    exit 1
fi

uci set wireless.wlan0cli.ssid="$SSID"
uci commit wireless
wifi reload
ALERT "Client Mode SSID set to:\n$SSID"
service pineapplepager restart >/dev/null 2>&1 || true
exit 0