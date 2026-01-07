# Per-system package overrides
# These packages require system-specific configuration or come from flake inputs
# that don't go through the normal overlay mechanism
{ inputs }:
{
  x86_64-linux = {
    # Expose the "real" iosevka build from the flake input for manual building
    # Usage: nix build .#iosevka-lyte-build
    # Then upload result to files.lyte.dev/projects/iosevka-lyte/
    iosevka-lyte-build = inputs.iosevka-lyte.outputs.packages.x86_64-linux.default;
  };

  aarch64-linux = {
    # PinePhone disk image for flashing
    pinephone-disk-image =
      inputs.self.nixosConfigurations.pinephone.config.mobile.outputs.generatedDiskImages.disk-image;
  };
}
