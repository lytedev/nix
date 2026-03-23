# Example darwin host configuration
# Copy this and rename for actual machines.
# Uncomment the entry in ./default.nix to enable.
{
  pkgs,
  config,
  ...
}:
{
  # Set this to whatever `scutil --get LocalHostName` returns on the mac,
  # or choose a new name.
  networking.hostName = "example-mac";

  # macOS version for nix-darwin state compatibility
  # Run `sw_vers -productVersion` on the mac to get this
  system.stateVersion = 6;

  lyte = {
    shell.enable = true;
    # editableConfigFiles = true;
    # flakePath = "/Users/daniel/code/nix";
  };

  # Extra packages for this machine
  environment.systemPackages = with pkgs; [
    # work-specific tools go here
  ];
}
