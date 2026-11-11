# Bluetooth Finder for WiFi Pineapple Pager

Bluetooth Finder lists nearby BLE advertisements and discoverable Classic Bluetooth devices on the Pager. Pick a result to see smoothed received signal strength (RSSI) and a warmer/colder indication as you walk.

## Install

Connect the Pager over USB-C or its Management AP. On your Mac, open Terminal at this repository's root and run:

```sh
ssh root@172.16.52.1 'mkdir -p /root/payloads/user/reconnaissance'
scp -O -p -r payloads/user/reconnaissance/Bluetooth_Finder root@172.16.52.1:/root/payloads/user/reconnaissance/
ssh root@172.16.52.1 'chmod +x /root/payloads/user/reconnaissance/Bluetooth_Finder/payload.sh'
```

Run **Payloads → User → Reconnaissance → Bluetooth Finder** on the Pager.

### Bluetooth tools

The payload uses the Pager's Bluetooth controller. It needs `hcitool` and `btmon` for BLE, plus `btmgmt` for Classic. Check what your firmware already provides before installing packages. From the Pager's SSH session:

```sh
export PATH="$PATH:/mmc/usr/bin:/mmc/usr/sbin"
command -v hcitool btmon btmgmt
```

If a command is missing, use the matching package from the Pager's configured feed. Run `opkg update` with the Pager online, then install only the packages for the missing commands:

| Command | OpenWrt package | Needed for |
| --- | --- | --- |
| `hcitool` | `bluez-utils` | BLE |
| `btmon` | `bluez-utils-btmon` | BLE |
| `btmgmt` | `bluez-utils-extra` | Classic |

For example, if both BLE tools are missing, run `opkg install -d mmc bluez-utils bluez-utils-btmon`. The payload checks for tools at launch and does not install packages. See [Hak5's package instructions](https://documentation.hak5.org/wifi-pineapple-pager/external-packages) for the firmware's package-feed setup.

If no controller appears, run `hciconfig -a` in the Pager's SSH session. If it lists `hci0` as down, run `hciconfig hci0 up` and retry. Close other Bluetooth scans first if discovery reports a busy controller. The payload picks the first detected controller. With multiple adapters, you can set `BLE_FINDER_HCI=hci0` near the top of `payload.sh` to choose a specific controller.

## Use

- **A** starts an eight-second BLE scan. **Right** starts a Classic discovery sweep. **B** exits.
- Results are sorted from strongest to weakest. **Up/Down** selects a result. **Left/Right** changes pages. **A** follows the selected address. **B** returns to the scan menu.
- Follow mode takes four short BLE readings per batch, or one Classic sweep per batch. Hold the Pager at the same height and orientation and pause briefly in each spot. An increase from −76 to −55 dBm is a stronger signal. A change of at least 4 dB between fresh readings triggers the warmer/colder label. Use **A** for another batch or **B** for the device list.
- `NA` means the controller reported a device without a usable RSSI. If follow mode loses the signal, try another scan. BLE devices may rotate their advertised address.

## Searching for AirPods

Start with BLE. Look for the AirPods name you used on your iPhone. If no name is advertised, **AirPods/Beats?** indicates an Apple proximity-pairing message when BlueZ decodes the message type. **Apple advertiser** means the packet had Apple's Bluetooth company ID. iPhones and other Apple devices can show up under that generic label. A Classic scan can also find the headphones if they are discoverable.

The printed serial number is not available in standard AirPods discovery broadcasts. The payload cannot match a serial number or wake the AirPods. If the earbuds and case aren't transmitting, a Bluetooth scan can't find them. Model, battery and lid state affect what is visible.

RSSI is relative proximity. Walls, pockets, reflections and differences in transmit power can change the reading. The bars describe signal strength and are not calibrated to feet or meters. Follow one candidate's trend over several readings.

## Source and verification

`payload.sh` is the native Pager UI and scan controller. `scan.awk` summarizes BlueZ discovery output. The app does not pair, connect, or write a scan history. The BLE monitor feeds an in-memory pipe. Temporary summaries are removed when the payload exits.

The parser and menu flow were checked with simulated BlueZ output. A physical Pager is needed to verify the radio and screen on your firmware.
