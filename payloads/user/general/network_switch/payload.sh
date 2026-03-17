#!/bin/sh

# TITLE: Network Switch (backup & restore client-mode)
# AUTHOR: jakeis0dd
# DESCRIPTION: Backup current client-mode SSID/encryption/(optional)password and
#              choose previously backed-up networks to apply. Uses LOG for
#              notifications and CONFIRMATION_DIALOG/ALERT for decisions.

set -eu

BASE_DIR="/mmc/root/payloads/user/general/network_switch"
DB_FILE="$BASE_DIR/saved_networks.db"
LOG_FILE="$BASE_DIR/history.log"
SECTION="wireless.wlan0cli"

now() { date '+%Y-%m-%d %H:%M:%S %z'; }
logit() { printf "%s %s\n" "$(now)" "$*" >> "$LOG_FILE"; }
LOG() { logit "$*"; }

mkdir -p "$BASE_DIR"
touch "$DB_FILE" "$LOG_FILE"

require_helpers() {
	MISSING=""
	for cmd in CONFIRMATION_DIALOG NUMBER_PICKER; do
		if ! command -v "$cmd" >/dev/null 2>&1; then
			MISSING="$MISSING $cmd"
		fi
	done
	if [ -n "$MISSING" ]; then
		LOG "ERROR missing helper(s):$MISSING"
		if command -v ALERT >/dev/null 2>&1; then
			ALERT "Required helper(s) missing:$MISSING\nCannot run payload." >/dev/null 2>&1 || true
		fi
		exit 1
	fi
}

getv() { uci -q get "$1" 2>/dev/null || true; }

confirm_dialog() {
	TITLE="$1"
	MESSAGE="$2"
	RESP="$(CONFIRMATION_DIALOG "$TITLE" "$MESSAGE" 2>/dev/null || true)"
	RC=$?
	case $RC in
		${DUCKYSCRIPT_CANCELLED:-255}|${DUCKYSCRIPT_REJECTED:-254}) return 1 ;; # cancelled
		${DUCKYSCRIPT_ERROR:-253}) return 2 ;;                          # error
	esac
	case "$RESP" in
		"${DUCKYSCRIPT_USER_CONFIRMED:-CONFIRMED}") return 0 ;;
		*) return 1 ;;
	esac
}

list_saved_networks_text() {
	if [ ! -s "$DB_FILE" ]; then
		echo "No saved networks."
		return 0
	fi
	i=1
	while IFS='|' read -r SSID ENC KEY; do
		PW_MARK=""
		if [ -n "$KEY" ]; then PW_MARK=" [pw]"; fi
		printf "%s) %s [%s]%s\n" "$i" "$SSID" "$ENC" "$PW_MARK"
		i=$((i + 1))
	done < "$DB_FILE"
}

choose_and_apply_saved() {
	COUNT=0
	while IFS='|' read -r _; do COUNT=$((COUNT+1)); done < "$DB_FILE"
	if [ "$COUNT" -eq 0 ]; then
		LOG "No saved networks to choose from."
		return 1
	fi

	LIST="$(list_saved_networks_text)"
	LOG "Saved networks:\n$LIST"

	PICK="$(NUMBER_PICKER "Enter network number" 1 2>/dev/null || true)"
	RC=$?
	case $RC in
		${DUCKYSCRIPT_CANCELLED:-255}|${DUCKYSCRIPT_REJECTED:-254}) LOG "User cancelled number picker"; return 2 ;;
		${DUCKYSCRIPT_ERROR:-253}) LOG "Number picker error"; return 3 ;;
	esac
	PICK="$(printf "%s" "$PICK" | tr -dc '0-9')"
	if [ -z "$PICK" ]; then LOG "Invalid selection from number picker"; return 3; fi
	if [ "$PICK" -lt 1 ] || [ "$PICK" -gt "$COUNT" ]; then LOG "Selection out of range: $PICK"; return 3; fi

	INDEX=1
	while IFS='|' read -r SSID ENC KEY; do
		if [ "$INDEX" -eq "$PICK" ]; then
			LOG "Applying saved network ssid='$SSID' encryption='$ENC' saved_password=$([ -n "$KEY" ] && echo yes || echo no)"
			uci set "$SECTION.ssid=$SSID"
			[ -n "$ENC" ] && uci set "$SECTION.encryption=$ENC"
			if [ -n "$KEY" ]; then
				uci set "$SECTION.key=$KEY"
			else
				uci -q delete "$SECTION.key" 2>/dev/null || true
			fi
			uci commit wireless
			wifi reload
			LOG "Switched to saved SSID: $SSID"
			return 0
		fi
		INDEX=$((INDEX + 1))
	done < "$DB_FILE"
	LOG "Failed to locate selected entry"
	return 3
}

save_current_network() {
	SSID="$(getv $SECTION.ssid)"
	ENC="$(getv $SECTION.encryption)"
	if [ -z "$SSID" ]; then
		LOG "No current SSID found to back up."
		if command -v ALERT >/dev/null 2>&1; then
			ALERT "No current SSID found to save." >/dev/null 2>&1 || true
		fi
		return 1
	fi

	if confirm_dialog "Save WiFi Password?" "Do you want to save the WiFi password for:\n\nSSID: $SSID\n\nPress CONFIRM to save the password.\nPress CANCEL to skip."; then
		KEY="$(getv $SECTION.key || true)"
		KEY="$(printf "%s" "$KEY" | tr '\n' ' ' | tr -d '|')"
	else
		KEY=""
	fi

	# Remove existing same-SSID entries then append
	grep -v "^${SSID}|" "$DB_FILE" > "$DB_FILE.tmp" 2>/dev/null || true
	mv -f "$DB_FILE.tmp" "$DB_FILE"
	if [ -n "$KEY" ]; then
		printf "%s|%s|%s\n" "$SSID" "$ENC" "$KEY" >> "$DB_FILE"
		LOG "SAVED ssid='$SSID' encryption='$ENC' saved_password=yes"
	else
		printf "%s|%s\n" "$SSID" "$ENC" >> "$DB_FILE"
		LOG "SAVED ssid='$SSID' encryption='$ENC' saved_password=no"
	fi
	return 0
}

main() {
	require_helpers

	# If saved networks exist, offer switch first
	if [ -s "$DB_FILE" ]; then
		LOG "Found saved networks; prompting to switch (check saved list in log)."
		if confirm_dialog "Switch to previously backed-up network?" "Press CONFIRM to switch to a previously backed-up SSID/password.\nPress CANCEL to back up the current client configuration."; then
			# Confirmed: choose and apply
			choose_and_apply_saved || LOG "choose_and_apply_saved returned non-zero"
		else
			# Cancelled: ask to back up current config
			if confirm_dialog "Back up current config?" "Press CONFIRM to back up the currently configured Client Mode (SSID & encryption).\nPress CANCEL to exit."; then
				save_current_network || LOG "save_current_network failed"
			else
				LOG "User chose not to back up current config."
			fi
		fi
	else
		# No saved networks: offer to back up
		if confirm_dialog "No saved networks" "No saved networks found. Press CONFIRM to back up the current client configuration.\nPress CANCEL to exit."; then
			save_current_network || LOG "save_current_network failed"
		else
			LOG "User chose not to back up current config."
		fi
	fi

	LOG "Restarting server in 5 seconds to enable privacy mode"
	sleep 5
	/etc/init.d/pineapplepager restart >/dev/null 2>&1 || true
}

main



