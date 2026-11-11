# Client Mode Manager

Install this complete folder at `/root/payloads/user/general/client_wifi_manager/` and launch it from **Payloads → User → General**. It manages the current client-mode configuration and saved networks without requiring a selected Recon AP or client.

The script's existing `BASE_DIR` is `/mmc/root/payloads/user/general/client_wifi_manager`. It creates `saved_networks.db` there at runtime, with `SSID|ENC|KEY` entries. This data file is not supplied by the checkout.

Confirm that this storage path is available on your Pager and whether `/root` resolves to `/mmc/root`. The repository layout change preserves `BASE_DIR` and does not move an existing saved-network database.
