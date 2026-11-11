# Summarize a scan window from btmon (LE) or btmgmt (Classic).
function valid_address(value,    pieces, part) {
    if (split(value, pieces, ":") != 6)
        return 0
    for (part = 1; part <= 6; part++)
        if (pieces[part] !~ /^[[:xdigit:]][[:xdigit:]]$/)
            return 0
    return value != "00:00:00:00:00:00"
}

function clean_name(value) {
    gsub(/[^ -~]/, "?", value)
    gsub(/[|]/, "/", value)
    sub(/^ +/, "", value)
    sub(/ +$/, "", value)
    return substr(value, 1, 64)
}

function remember(mac, reading, label, quality, apple) {
    if (!valid_address(mac) || (target != "" && mac != target))
        return
    seen[mac] = 1
    label = clean_name(label)
    if (label != "" && quality >= name_quality[mac]) {
        names[mac] = label
        name_quality[mac] = quality
    }
    if (apple > apple_hint[mac])
        apple_hint[mac] = apple
    # 127 is the HCI sentinel for unavailable RSSI.
    if (reading ~ /^-?[0-9]+$/ && reading >= -127 && reading <= 20) {
        if (count[mac] == 0)
            rssi[mac] = reading + 0
        else
            rssi[mac] += (reading - rssi[mac]) * 0.25
        count[mac]++
    }
}

function finish_report() {
    if (address != "")
        remember(address, signal, name, name_kind, apple_report)
    address = signal = name = ""
    name_kind = apple_report = apple_company = 0
}

transport == "LE" {
    if ($0 ~ /^[[:space:]]*[<>@*=]/) {
        finish_report()
        advertising = 0
    } else if ($0 ~ /^[[:space:]]*LE (Extended )?Advertising Report[[:space:]]*\(/) {
        finish_report()
        advertising = 1
    } else if (advertising && $1 == "Address:") {
        finish_report()
        if (valid_address($2))
            address = toupper($2)
    } else if (advertising && address != "") {
        if ($1 == "RSSI:")
            signal = $2
        else if ($0 ~ /^[[:space:]]*Name \((complete|short|shortened)\):/) {
            name_kind = ($2 == "(complete):" ? 2 : 1)
            name = $0
            sub(/^[^:]*:[[:space:]]*/, "", name)
        } else if ($1 == "Company:") {
            apple_company = ($0 ~ /Apple.*\((76|0x004c)\)/)
            if (apple_company && apple_report == 0)
                apple_report = 1
        } else if (apple_company && $1 == "Type:" &&
                   $0 ~ /(Unknown|[Pp]roximity [Pp]airing) \(7\)/) {
            # Apple Continuity type 7 is a proximity-pairing message.
            apple_report = 2
        }
    }
    next
}

transport == "BT" && $2 == "dev_found:" {
    classic_address = ""
    if ($1 != controller || !valid_address($3) || $5 != "BR/EDR" || $6 != "rssi")
        next
    classic_address = toupper($3)
    classic_name = $0
    if (!sub(/^[^[:space:]]+[[:space:]]+dev_found:.* flags 0x[[:xdigit:]]+[[:space:]]+name[[:space:]]+/, "", classic_name))
        classic_name = ""
    remember(classic_address, $7, classic_name, 2, 0)
    next
}

transport == "BT" && classic_address != "" {
    if ($1 == "name" || $1 == "name:") {
        classic_name = $0
        sub(/^[[:space:]]*name:?[[:space:]]+/, "", classic_name)
        remember(classic_address, "", classic_name, 2, 0)
    }
    classic_address = ""
}

END {
    if (transport == "LE")
        finish_report()
    for (mac in seen) {
        label = names[mac]
        if (label == "") {
            if (apple_hint[mac] == 2)
                label = "AirPods/Beats?"
            else
                label = (apple_hint[mac] ? "Apple advertiser" : "Unnamed device")
        }
        samples = count[mac] + 0
        strength = (samples ? sprintf("%.0f", rssi[mac]) : "NA")
        # A separate sort key keeps unavailable readings below real RSSI.
        printf "%s|%s|%s|%d|%s\n", (samples ? strength : -999), mac, strength, samples, label
    }
}
