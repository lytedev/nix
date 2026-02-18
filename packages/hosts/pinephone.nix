# PinePhone configuration
# Uses lyte.mobile module for common mobile/phosh and mobile-nixos settings
{
  pkgs,
  lib,
  ...
}:
{
  system.stateVersion = "25.11";

  # Enable the mobile module for phosh, apps, fonts, mobile-nixos settings, etc.
  lyte.mobile = {
    enable = true;
    user = "daniel";
    scale = 2.0;
    useStevia = true; # Use Stevia keyboard with word completion
    cellBroadcast = true; # Enable cell broadcast for emergency alerts
    fbkeyboard = false; # Disable - was eating CPU and not needed with Phosh

    # MMS support via mmsd-tng (integrates with Chatty)
    # Settings below are for T-Mobile US - adjust for your carrier
    mms = {
      enable = true;
      carrierMMSC = "http://mms.msg.eng.t-mobile.com/mms/wapenc";
      mmsAPN = "fast.t-mobile.com";
      # carrierMMSProxy = ""; # T-Mobile doesn't use a proxy
    };
  };

  # GPU/display
  hardware.graphics.enable = true;
  hardware.bluetooth.enable = true;

  # dconf required for squeekboard/phosh settings
  programs.dconf.enable = true;

  # Additional packages specific to this host
  environment.systemPackages = with pkgs; [
    gnome-clocks # clock/alarm app
    pure-maps # offline/online maps and navigation
    snapshot # GNOME camera app
  ];

  # Shell tools on the NixOS side
  lyte.shell.enable = true;

  # Disable desktop features that don't apply to mobile
  lyte.desktop.enable = false;

  # pinephone-specific user group additions
  users.users.daniel.extraGroups = lib.mkAfter [
    "feedbackd"
    "dialout" # for ModemManager access without polkit prompts
  ];

  networking.hostName = "pinephone";
  networking.networkmanager.enable = true;

  # pinephone kernel doesn't support rpfilter, but we still want a firewall
  # mkForce needed to override tailscale's "loose" setting
  networking.firewall = {
    enable = true;
    checkReversePath = lib.mkForce false;
  };

  # tailscale for remote access
  services.tailscale.enable = true;

  # SD card storage doesn't need SMART monitoring
  services.smartd.enable = lib.mkForce false;

  # slippi's gamecube adapter requires kernel modules - disable on mobile
  gamecube-controller-adapter = {
    enable = lib.mkForce false;
    overclocking-kernel-module.enable = lib.mkForce false;
  };

  # no man cache on pinephone
  documentation.man.generateCaches = false;

  # Memory pressure tuning for low-RAM device
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 60;
  };

  swapDevices = [
    {
      device = "/swapfile";
      size = 1024;
      priority = 5;
    }
  ];

  # Disable kexec boot (stage-0) - kexec breaks CMA allocation which prevents
  # camera (megapixels) and hardware video playback (cedrus/livi/clapper) from working.
  # See: https://github.com/mobile-nixos/mobile-nixos/issues/660
  mobile.quirks.supportsStage-0 = lib.mkForce false;

  # Enable geoclue demo agent for GPS (needed for pure-maps and gnome-maps)
  # Without this, no geoclue agent is running and location services don't work.
  services.geoclue2.enableDemoAgent = lib.mkForce true;

  # geoclue needs networkmanager group to query wifi/cell for location
  users.users.geoclue.extraGroups = [ "networkmanager" ];

  boot.kernel.sysctl = {
    "vm.swappiness" = 100;
  };

  systemd.oomd = {
    enable = true;
    settings = {
      OOM = {
        DefaultMemoryPressureDurationSec = "30s";
        DefaultMemoryPressureLimit = "60%";
        DefaultSwapUsedLimit = "90%";
      };
    };
  };
}
