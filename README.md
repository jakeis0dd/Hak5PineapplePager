# Hak5 Pineapple Pager 🍍📟

## Repository layout

The deployable folders at this repository's root map directly to the Pager's `/root/`:

```text
payloads/
  user/
    general/
      client_wifi_manager/
      privacy-mode/
    games/
      zelda_gbc/
    reconnaissance/
      Bluetooth_Finder/           # payload.sh, scan.awk, README.md
  recon/
    access_point/
      client-mode-set-ssid/
themes/
  <theme>/                       # theme.json, assets/, components/, etc.
ringtones/
  *.rtttl
```

Standalone tools belong in `payloads/user/<category>/<payload>/` and launch from the **Payloads** menu. Wi-Fi Recon actions belong in `payloads/recon/access_point/<payload>/` or `payloads/recon/client/<payload>/`, according to the selected target. Event handlers belong in `payloads/alerts/<event>/<payload>/`. This checkout currently has no client Recon actions or alert payloads, so those directories are absent. Calling the `ALERT` command alone does not make a script an event handler.

These paths follow [Hak5's payload library](https://github.com/hak5/wifipineapplepager-payloads/tree/master/library), including its [Recon directories](https://github.com/hak5/wifipineapplepager-payloads/tree/master/library/recon), [theme installation guidance](https://github.com/hak5/wifipineapplepager-themes#installing-pager-themes), and [ringtone documentation](https://documentation.hak5.org/wifi-pineapple-pager/ringtones).

### Payload placement review

| Before | After | Launch context |
| --- | --- | --- |
| `payloads/recon/client-mode-set-ssid/` | [`payloads/recon/access_point/client-mode-set-ssid/`](payloads/recon/access_point/client-mode-set-ssid/) | Selected AP: reads `_RECON_SELECTED_AP_SSID`; launch from that AP's Recon actions. |
| `payloads/user/reconnaissance/Bluetooth_Finder/` | [Same path](payloads/user/reconnaissance/Bluetooth_Finder/) | Payloads menu; runs its own Bluetooth discovery and keeps its parser beside `payload.sh`. |
| `payloads/user/general/client_wifi_manager/` | [Same path](payloads/user/general/client_wifi_manager/) | Payloads menu; manages the current client configuration and saved networks without a Recon selection. |
| `payloads/user/general/privacy-mode/` | [Same path](payloads/user/general/privacy-mode/) | Payloads menu; toggles the device's privacy setting. |
| `payloads/user/games/zelda_gbc/` | [Same path](payloads/user/games/zelda_gbc/) | Payloads menu; starts the emulator server. |
| `themes/<theme>/` | [Same paths](themes/) | Each of the 14 themes keeps its definition and assets together. |
| `ringtones/*.rtttl` | [Same paths](ringtones/) | All 11 deployable ringtones stay directly under `ringtones/`. |

No payload has an unresolved launch context after source inspection. Payload contents and existing file permissions are preserved.

### Install from this checkout

Run commands from the repository root. For example, to copy the selected-AP action or Bluetooth Finder, including its supporting files:

```sh
ssh root@172.16.52.1 'mkdir -p /root/payloads/recon/access_point /root/payloads/user/reconnaissance'
scp -O -p -r payloads/recon/access_point/client-mode-set-ssid root@172.16.52.1:/root/payloads/recon/access_point/
scp -O -p -r payloads/user/reconnaissance/Bluetooth_Finder root@172.16.52.1:/root/payloads/user/reconnaissance/
```

For a theme, copy its entire folder; for ringtones, copy the `.rtttl` files:

```sh
ssh root@172.16.52.1 'mkdir -p /root/themes /root/ringtones'
scp -O -p -r themes/neon-biker root@172.16.52.1:/root/themes/
scp -O -p ringtones/*.rtttl root@172.16.52.1:/root/ringtones/
```

These are manual deployment examples; the reorganization did not upload anything. `-p` preserves local modes. Bluetooth Finder's `payload.sh` is executable (`0755`); the other four payload scripts currently have mode `0644`, retained as found. If your firmware requires executable scripts, set that permission on the chosen script when deploying.

### On-device confirmation still needed

On November 11, 2026, read-only SSH to `root@172.16.52.1` reached the Pager but authentication was denied (`publickey,password,keyboard-interactive`). Directory contents could not be listed. Confirm `/root/payloads/user/`, `/root/payloads/recon/access_point/`, `/root/payloads/recon/client/`, `/root/payloads/alerts/`, `/root/themes/`, and `/root/ringtones/` against your installed firmware before deployment. Missing optional directories can be created when installing a matching payload.

Client WiFi Manager retains its existing data path, `/mmc/root/payloads/user/general/client_wifi_manager/saved_networks.db`. Confirm whether `/root` resolves to `/mmc/root` on your Pager and that this storage path is available; the reorganization does not migrate saved networks or change that behavior.

---

## About the WiFi Pineapple Pager

A WiFi Pineapple built for hackers who don’t stay put.

The **WiFi Pineapple Pager** combines Hak5’s PineAP engine with a fast, highly optimized embedded UI.  
Ringtones provide audible feedback for alerts, recon activity, payload events, and system notifications — even when the device isn’t being actively watched.

---

## About Pager Ringtones

Pager ringtones are **short audible sequences** used by the device to communicate state, alerts, and activity.

They are:

- Authored in **RTTTL**
- Parsed and played directly by the Pager
- Used for alerts, notifications, and event feedback
- Lightweight and efficient for embedded hardware

Ringtones in this repository are the **source definitions** used directly by the device — **no compilation required**.

---

## About RTTTL

RTTTL (Ring Tone Text Transfer Language) is a simple text-based format originally designed for early mobile phones.

A typical RTTTL ringtone looks like:

---

### File Format

- Ringtones must be written in **RTTTL**
- Files should contain **only** the RTTTL definition
- No binary or encoded audio formats are allowed

---

### Design Best Practices

- Keep ringtones short and distinct
- Avoid extremely high or low frequencies
- Ensure tones are clearly audible on the Pager speaker
- Avoid excessive repetition or long melodies
- Test at multiple volume levels

Ringtones that are excessively long, annoying, or disruptive may be rejected.

---
