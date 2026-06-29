# ESP32-S3-Box-3 voice satellite (ESPHome)

Firmware config for the household voice satellite — a [ESP32-S3-Box-3][box] running
ESPHome as a Home Assistant Assist client, with an 18650-battery display dock.
Device IP: `192.168.0.226`.

Moved here from `lytedev/lytebot-alexa` so the firmware config, its secrets, and a
reproducible deploy live in one place.

## Files

- `esp32-s3-box-3.yaml` — the ESPHome config. Wi-Fi credentials are `!secret`
  references, not inline.
- `deploy.nix` — the `nix run .#deploy-esp32` app (defined in `packages/default.nix`).
- Secrets: `secrets/esp32-s3-box-3.yaml` (SOPS-encrypted; keys `wifi_ssid`,
  `wifi_password`).

## Deploy

```bash
# OTA flash the box at 192.168.0.226 (default)
nix run .#deploy-esp32

# First flash over USB (overrides the default --device)
nix run .#deploy-esp32 -- --device /dev/ttyACM0

# Pass through any other esphome run flags
nix run .#deploy-esp32 -- --device 192.168.0.226 --no-logs
```

The app decrypts `secrets/esp32-s3-box-3.yaml` to a throwaway `secrets.yaml`
beside the config in a `mktemp` dir, runs `esphome run`, and deletes the
plaintext on exit. Decryption uses your local age key (`SOPS_AGE_KEY_FILE` or
`~/.config/sops/age/keys.txt`).

## Editing secrets

```bash
sops secrets/esp32-s3-box-3.yaml
```

[box]: https://www.espressif.com/en/products/devkits/esp32-s3-box
