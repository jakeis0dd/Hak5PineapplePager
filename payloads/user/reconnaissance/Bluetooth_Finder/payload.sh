#!/bin/bash
# Title: Bluetooth Finder
# Description: List nearby Bluetooth signals and follow a selected device by RSSI.
# Version: 0.1.0
# Category: reconnaissance

export LC_ALL=C
export PATH="$PATH:/mmc/usr/bin:/mmc/usr/sbin"
payload_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)" || exit 1

if ! command -v LOG >/dev/null || ! command -v WAIT_FOR_INPUT >/dev/null; then
    printf '%s\n' "Start Bluetooth Finder from the Pager's Payloads menu." >&2
    exit 1
fi

umask 077
work="$(mktemp -d /tmp/bluetooth-finder.XXXXXX)" || exit 1
scan_pid=
scan_transport=
monitor_pid=
parser_pid=
timer_pid=

stop_le_scan() {
    local deadline=$((SECONDS + 12))
    kill -INT "$scan_pid" 2>/dev/null
    while kill -0 "$scan_pid" 2>/dev/null && (( SECONDS < deadline )); do
        sleep 0.1
    done
    kill -TERM "$scan_pid" 2>/dev/null
    wait "$scan_pid" 2>/dev/null
}

cleanup() {
    if [[ -n "$timer_pid" ]]; then
        kill "$timer_pid" 2>/dev/null
        wait "$timer_pid" 2>/dev/null
    fi
    if [[ -n "$scan_pid" ]]; then
        if [[ "$scan_transport" == LE ]]; then
            stop_le_scan
        else
            kill -TERM "$scan_pid" 2>/dev/null
            wait "$scan_pid" 2>/dev/null
        fi
    fi
    if [[ -n "$monitor_pid" ]]; then
        kill -TERM "$monitor_pid" 2>/dev/null
        wait "$monitor_pid" 2>/dev/null
    fi
    if [[ -n "$parser_pid" ]]; then
        kill "$parser_pid" 2>/dev/null
        wait "$parser_pid" 2>/dev/null
    fi
    rm -rf -- "$work"
}

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM HUP

wait_seconds() {
    sleep "$1" &
    timer_pid=$!
    wait "$timer_pid"
    timer_pid=
}

list_adapters() {
    if command -v hcitool >/dev/null; then
        hcitool dev 2>/dev/null | awk '$1 ~ /^hci[0-9]+$/ {print $1}'
    elif command -v btmgmt >/dev/null; then
        btmgmt --timeout 4 info 2>/dev/null |
            awk -F: '/^hci[0-9]+:/ {print $1}'
    fi
}

scan_le() {
    local seconds="$1" target="$2" scan_status monitor_status parser_status
    # The FIFO feeds only a per-device summary into RAM.
    rm -f "$work/events"
    mkfifo "$work/events" || return 1
    awk -v transport=LE -v target="$target" -f "$payload_dir/scan.awk" \
        < "$work/events" > "$work/summary" &
    parser_pid=$!
    btmon -P -i "${controller#hci}" > "$work/events" 2> "$work/monitor-error" &
    monitor_pid=$!

    wait_seconds 1
    if ! kill -0 "$monitor_pid" 2>/dev/null; then
        wait "$monitor_pid" 2>/dev/null
        monitor_pid=
        wait "$parser_pid"
        parser_pid=
        scan_error="$(head -n 1 "$work/monitor-error")"
        return 1
    fi

    scan_transport=LE
    hcitool -i "$controller" lescan --duplicates > /dev/null 2> "$work/scan-error" &
    scan_pid=$!
    wait_seconds "$seconds"
    # hcitool uses SIGINT to stop LE scanning cleanly on the controller.
    stop_le_scan
    scan_status=$?
    scan_pid=

    kill -TERM "$monitor_pid" 2>/dev/null
    wait "$monitor_pid"
    monitor_status=$?
    monitor_pid=
    wait "$parser_pid"
    parser_status=$?
    parser_pid=

    if (( scan_status != 0 || monitor_status != 0 || parser_status != 0 )); then
        scan_error="$(awk 'NF {print; exit}' "$work/scan-error" "$work/monitor-error")"
        return 1
    fi
}

scan_classic() {
    local target="$1" scan_status
    scan_transport=BT
    btmgmt --index "${controller#hci}" --timeout 22 find -b \
        > "$work/classic-results" 2>&1 &
    scan_pid=$!
    wait "$scan_pid"
    scan_pid=

    if ! grep -q 'Discovery started' "$work/classic-results"; then
        scan_error="$(awk '/Unable|failed|Failed|Error/ {print; exit}' "$work/classic-results" | tr -cd ' -~')"
        return 1
    fi

    awk -v transport=BT -v controller="$controller" -v target="$target" \
        -f "$payload_dir/scan.awk" "$work/classic-results" > "$work/summary"
    scan_status=$?
    rm -f "$work/classic-results"
    return "$scan_status"
}

scan() {
    local transport="$1" seconds="$2" target="${3:-}"
    local scan_error=""
    if [[ "$transport" == LE ]]; then
        scan_le "$seconds" "$target"
    else
        scan_classic "$target"
    fi
    if (( $? != 0 )); then
        LOG red "Bluetooth scan failed on $controller."
        [[ -z "$scan_error" ]] || LOG red "${scan_error:0:70}"
        return 1
    fi
    if ! sort -t '|' -k1,1nr -k2,2 "$work/summary" > "$work/results"; then
        LOG red "Could not sort the scan results."
        return 1
    fi
}

signal_bar() {
    local strength="$1" bars
    if (( strength >= -45 )); then bars="#####"
    elif (( strength >= -58 )); then bars="####."
    elif (( strength >= -70 )); then bars="###.."
    elif (( strength >= -82 )); then bars="##..."
    else bars="#...."
    fi
    printf '%s' "$bars"
}

hunt() {
    local transport="$1" address="$2" label="$3"
    local reading step batch=4 previous="" trend color key
    [[ "$transport" != BT ]] || batch=1

    LOG blue "Follow ${label:0:24}"
    LOG "Address $address"
    LOG "Walk slowly. Watch for stronger RSSI."
    while true; do
        for ((step=0; step<batch; step++)); do
            if ! scan "$transport" 3 "$address"; then
                LOG "Press a button for the device list."
                WAIT_FOR_INPUT >/dev/null
                return
            fi
            IFS='|' read -r _ _ reading _ < "$work/results"
            if [[ -z "$reading" || "$reading" == NA ]]; then
                LOG yellow "No fresh RSSI. Hold or move back."
                previous=""
                continue
            fi

            trend="First reading"
            color=blue
            if [[ -n "$previous" ]]; then
                if (( reading - previous >= 4 )); then
                    trend="Warmer"
                    color=green
                elif (( previous - reading >= 4 )); then
                    trend="Colder"
                    color=yellow
                else
                    trend="Steady"
                fi
            fi
            LOG "$color" "$reading dBm  $(signal_bar "$reading")  $trend"
            previous="$reading"
        done

        LOG "A: keep tracking   B: device list"
        while true; do
            key="$(WAIT_FOR_INPUT)" || return
            case "$key" in
                A) break ;;
                B) return ;;
            esac
        done
    done
}

device_list() {
    local transport="$1" index=0 page row key strength marker
    local -a addresses=() signals=() labels=()
    local address reading label
    while IFS='|' read -r _ address reading _ label; do
        addresses+=("$address")
        signals+=("$reading")
        labels+=("$label")
    done < "$work/results"

    local total="${#addresses[@]}"
    if (( total == 0 )); then
        LOG yellow "No $transport devices heard in this scan."
        LOG "Press a button to return."
        WAIT_FOR_INPUT >/dev/null
        return
    fi

    while true; do
        page=$((index / 3 * 3))
        LOG blue "$transport devices  $((index + 1)) of $total"
        for ((row=page; row<page+3 && row<total; row++)); do
            marker=" "
            [[ "$row" != "$index" ]] || marker=">"
            strength="${signals[row]}"
            [[ "$strength" == NA ]] || strength="$strength dBm"
            LOG "$marker ${labels[row]:0:18} ${addresses[row]:12} $strength"
        done
        LOG "Up/Down: select  Left/Right: page"
        LOG "A: track    B: scan menu"
        key="$(WAIT_FOR_INPUT)" || return
        case "$key" in
            UP) index=$(((index + total - 1) % total)) ;;
            DOWN) index=$(((index + 1) % total)) ;;
            LEFT) index=$((page >= 3 ? page - 3 : index)) ;;
            RIGHT) index=$((page + 3 < total ? page + 3 : index)) ;;
            A) hunt "$transport" "${addresses[index]}" "${labels[index]}" ;;
            B) return ;;
        esac
    done
}

main() {
    local adapters transport key
    while true; do
        LOG blue "Bluetooth Finder"
        LOG "A: BLE scan   Right: Classic scan"
        LOG "B: exit"
        key="$(WAIT_FOR_INPUT)" || return
        case "$key" in
            A)
                if ! command -v hcitool >/dev/null || ! command -v btmon >/dev/null; then
                    LOG yellow "BLE needs hcitool and btmon. See README."
                    continue
                fi
                transport=LE
                ;;
            RIGHT)
                if ! command -v btmgmt >/dev/null; then
                    LOG yellow "Classic needs btmgmt. See README."
                    continue
                fi
                transport=BT
                ;;
            B) return ;;
            *) continue ;;
        esac

        adapters="$(list_adapters)"
        controller="${BLE_FINDER_HCI:-${adapters%%$'\n'*}}"
        if [[ ! "$controller" =~ ^hci[0-9]+$ ]] ||
            ! grep -Fxq "$controller" <<< "$adapters"; then
            LOG red "No available Bluetooth adapter."
            LOG "Check the adapter with hcitool dev over SSH."
            continue
        fi

        LOG "Scanning $transport on $controller..."
        if scan "$transport" 8; then
            device_list "$transport"
        fi
    done
}

main
