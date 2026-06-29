# Reproducible OTA deploy for the ESP32-S3-Box-3 household voice satellite.
#
#   nix run .#deploy-esp32              # OTA flash 192.168.0.226 (the box)
#   nix run .#deploy-esp32 -- --device /dev/ttyACM0   # first flash over USB
#   nix run .#deploy-esp32 -- logs      # any esphome subcommand passes through
#
# The Wi-Fi credentials live SOPS-encrypted in secrets/esp32-s3-box-3.yaml and
# are decrypted to a throwaway secrets.yaml beside the config at run time, then
# deleted. Decryption uses your local age key (SOPS_AGE_KEY_FILE, or the default
# ~/.config/sops/age/keys.txt) — the same key that encrypts everything else in
# secrets/.
#
# Both the firmware config and the *encrypted* secrets file are baked into the
# store derivation, so this runs from a clean checkout without needing the repo
# as cwd. The plaintext only ever exists in a per-run mktemp dir.
{ pkgs, ... }:
let
  configFile = ./esp32-s3-box-3.yaml;
  encryptedSecrets = ../../../secrets/esp32-s3-box-3.yaml;
  defaultDevice = "192.168.0.226";
in
pkgs.writeShellApplication {
  name = "deploy-esp32";
  runtimeInputs = with pkgs; [
    esphome
    sops
    coreutils
  ];
  text = ''
    workdir="$(mktemp -d)"
    trap 'rm -rf "$workdir"' EXIT

    cp ${configFile} "$workdir/esp32-s3-box-3.yaml"
    # esphome resolves !secret from secrets.yaml beside the config.
    sops -d ${encryptedSecrets} > "$workdir/secrets.yaml"

    # `esphome run` OTAs to --device by default; the box at ${defaultDevice}.
    # Any extra args pass through (e.g. `-- --device /dev/ttyACM0` for the
    # first USB flash, which overrides the default below).
    if printf '%s\0' "$@" | grep -qz -- '--device'; then
      esphome run "$workdir/esp32-s3-box-3.yaml" "$@"
    else
      esphome run "$workdir/esp32-s3-box-3.yaml" --device ${defaultDevice} "$@"
    fi
  '';
}
