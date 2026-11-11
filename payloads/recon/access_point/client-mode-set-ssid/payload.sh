#!/bin/sh
# TITLE Client Mode Set SSID
# AUTHOR jakeis0dd
# DESCRIPTION: Set the Client Mode SSID to the selected AP from Recon.

set -eu

SSID="${_RECON_SELECTED_AP_SSID:-}"

if [ -z "$SSID" ]; then
    ALERT "No SSID selected from Recon."
    exit 1
fi

uci set wireless.wlan0cli.ssid="$SSID"
uci commit wireless
wifi reload
LOG "Client Mode SSID set to:\n$SSID"
sleep 5
LOG "Rebooting Server..."
service pineapplepager restart >/dev/null 2>&1 || true
exit 0