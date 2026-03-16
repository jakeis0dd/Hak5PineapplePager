#!/bin/sh
set -eu

BASE_DIR="/mmc/root/payloads/user/general/network_switch"
DB_FILE="$BASE_DIR/saved_networks.db"
LOG_FILE="$BASE_DIR/history.log"
SECTION="wireless.wlan0cli"

mkdir -p "$BASE_DIR"
touch "$DB_FILE" "$LOG_FILE"

now() { date '+%Y-%m-%d %H:%M:%S %z'; }
logit() { printf "%s %s\n" "$(now)" "$*" >> "$LOG_FILE"; }

getv() {
    uci -q get "$1" 2>/dev/null || true
}

show_alert() {
    MSG="$1"
    if command -v ALERT >/dev/null 2>&1; then
        ALERT "$MSG" >/dev/null 2>&1 || true
    else
        echo "$MSG"
    fi
}

pause_message() {
    MSG="$1"
    if command -v PROMPT >/dev/null 2>&1; then
        PROMPT "$MSG" >/dev/null 2>&1 || true
        if command -v WAIT_FOR_BUTTON_PRESS >/dev/null 2>&1; then
            WAIT_FOR_BUTTON_PRESS >/dev/null 2>&1 || true
        fi
    else
        show_alert "$MSG"
    fi
}

confirm_dialog() {
    TITLE="$1"
    MESSAGE="$2"

    RESP="$(CONFIRMATION_DIALOG "$TITLE" "$MESSAGE" || true)"
    RC=$?

    case $RC in
        ${DUCKYSCRIPT_CANCELLED:-255}|${DUCKYSCRIPT_REJECTED:-254})
            return 1
            ;;
        ${DUCKYSCRIPT_ERROR:-253})
            return 2
            ;;
    esac

    case "$RESP" in
        "${DUCKYSCRIPT_USER_CONFIRMED:-CONFIRMED}")
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

save_current_network() {
    SSID="$(getv $SECTION.ssid)"
    ENC="$(getv $SECTION.encryption)"
    ROUTED="$(getv $SECTION.routed)"

    if [ -z "$SSID" ]; then
        show_alert "No current SSID found to save."
        return 1
    fi

    grep -v "^${SSID}|" "$DB_FILE" > "$DB_FILE.tmp" 2>/dev/null || true
    mv -f "$DB_FILE.tmp" "$DB_FILE"

    printf "%s|%s|%s\n" "$SSID" "$ENC" "$ROUTED" >> "$DB_FILE"
    logit "SAVED ssid='$SSID' encryption='$ENC' routed='$ROUTED'"

    show_alert "Saved network:\n$SSID"
    return 0
}

list_saved_networks_text() {
    if [ ! -s "$DB_FILE" ]; then
        echo "No saved networks."
        return 0
    fi

    i=1
    while IFS='|' read -r SSID ENC ROUTED; do
        printf "%s) %s [%s]\n" "$i" "$SSID" "$ENC"
        i=$((i + 1))
    done < "$DB_FILE"
}

switch_saved_network() {
    if [ ! -s "$DB_FILE" ]; then
        show_alert "No saved networks found."
        return 1
    fi

    COUNT=0
    while IFS='|' read -r _SSID _ENC _ROUTED; do
        COUNT=$((COUNT + 1))
    done < "$DB_FILE"

    LIST_TEXT="$(list_saved_networks_text)"
    if [ -n "$LIST_TEXT" ]; then
        pause_message "$LIST_TEXT"
    fi

    PICK="$(NUMBER_PICKER "Enter network number" 1 || true)"
    RC=$?

    case $RC in
        ${DUCKYSCRIPT_CANCELLED:-255}|${DUCKYSCRIPT_REJECTED:-254})
            return 0
            ;;
        ${DUCKYSCRIPT_ERROR:-253})
            show_alert "Number picker error."
            return 1
            ;;
    esac

    PICK="$(printf "%s" "$PICK" | tr -dc '0-9')"

    if [ -z "$PICK" ]; then
        show_alert "Invalid selection."
        return 1
    fi

    if [ "$PICK" -lt 1 ] || [ "$PICK" -gt "$COUNT" ]; then
        show_alert "Selection out of range."
        return 1
    fi

    INDEX=1
    SELECTED=""
    while IFS='|' read -r SSID ENC ROUTED; do
        if [ "$INDEX" -eq "$PICK" ]; then
            SELECTED="$SSID|$ENC|$ROUTED"
            break
        fi
        INDEX=$((INDEX + 1))
    done < "$DB_FILE"

    if [ -z "$SELECTED" ]; then
        show_alert "Could not load selected network."
        return 1
    fi

    IFS='|' read -r SSID ENC ROUTED <<EOF
$SELECTED
EOF

    if ! confirm_dialog "Use saved network?" "SSID: $SSID\nEncryption: $ENC\n\nPress CONFIRM to apply.\nPress CANCEL to abort."; then
        return 0
    fi

    uci set "$SECTION.ssid=$SSID"
    [ -n "$ENC" ] && uci set "$SECTION.encryption=$ENC"
    [ -n "$ROUTED" ] && uci set "$SECTION.routed=$ROUTED"

    # Clear current password so you re-enter it manually
    uci -q delete "$SECTION.key" 2>/dev/null || true

    uci commit wireless
    wifi reload

    logit "SWITCHED ssid='$SSID' encryption='$ENC' routed='$ROUTED'"
    show_alert "Switched to:\n$SSID\n\nEnter the WiFi password manually in Client Mode Setup."
    return 0
}

main_menu() {
    if confirm_dialog "Network Switch" "Press CONFIRM to save the current network.\nPress CANCEL to switch to a saved network."; then
        save_current_network
        return 0
    fi

    switch_saved_network
    return 0
}

while true; do
    main_menu

    if confirm_dialog "Run Again?" "Press CONFIRM to run this payload again.\nPress CANCEL to exit."; then
        :
    else
        break
    fi
done

sleep 2

# Refresh Pager UI so Client Mode SSID display updates
service pineapplepager restart >/dev/null 2>&1 || true

exit 0
