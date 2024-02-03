{
  pkgs,
  lib,
  inputs,
  outputs,
  modulesPath,
  ...
}: {
  nixpkgs.hostPlatform = "x86_64-linux";
  networking.hostName = "htpc";

  imports = with outputs.nixosModules; [
    (modulesPath + "/installer/scan/not-detected.nix")
    inputs.hardware.nixosModules.raspberry-pi-4
    # inputs.hardware.nixosModules.common-cpu-intel-kaby-lake
    # inputs.hardware.nixosModules.common-pc-ssd
    # inputs.hardware.nixosModules.common-pc
    desktop-usage
    gnome
    wifi
    flanfam
    flanfamkiosk
  ];

  hardware = {
    raspberry-pi."4".apply-overlays-dtmerge.enable = true;
    deviceTree = {
      enable = true;
      filter = "*rpi-4-*.dtb";
    };
  };
  console.enable = false;

  services.gnome.gnome-remote-desktop.enable = true;

  networking.networkmanager.enable = true;
  nix.settings.experimental-features = ["nix-command" "flakes"];

  home-manager.users.daniel = {
    imports = with outputs.homeManagerModules; [linux-desktop];
  };

  environment.systemPackages = with pkgs;
  #with pkgs;
    [
      libcec
      variety
      libraspberrypi
      raspberrypi-eeprom
    ];

  programs.steam.enable = true;
  programs.steam.remotePlay.openFirewall = true;

  services.xserver = {
    enable = true;
    displayManager = {
      # lightdm.enable = true;
      autoLogin.enable = true;
      autoLogin.user = "daniel";
    };
    desktopManager.gnome.enable = true;
    videoDrivers = ["fbdev"];
  };

  hardware.raspberry-pi."4".fkms-3d.enable = true;
  hardware.raspberry-pi."4".audio.enable = true;

  nixpkgs.overlays = [
    # nixos-22.05
    # (self: super: { libcec = super.libcec.override { inherit (self) libraspberrypi; }; })
    # nixos-22.11
    (self: super: {libcec = super.libcec.override {withLibraspberrypi = true;};})
  ];

  # Workaround for GNOME autologin: https://github.com/NixOS/nixpkgs/issues/103746#issuecomment-945091229
  systemd.services."getty@tty1".enable = false;
  systemd.services."autovt@tty1".enable = false;

  # hardware
  systemd.targets.sleep.enable = false;
  systemd.targets.suspend.enable = false;
  systemd.targets.hibernate.enable = false;
  systemd.targets.hybrid-sleep.enable = false;

  powerManagement.enable = false;

  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda";

  boot.initrd.availableKernelModules = ["xhci_pci" "ahci" "usbhid" "usb_storage" "sd_mod" "sdhci_pci"];
  boot.initrd.kernelModules = [];
  boot.kernelModules = [
    # "kvm-intel"
  ];
  boot.extraModulePackages = [];

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/0f4e5814-0002-43f0-bfab-8368e3fe5b8a";
    fsType = "ext4";
  };

  networking = {
    # useDHCP = true;

    firewall = {
      enable = true;
      allowPing = true;
      allowedTCPPorts = [22 5900];
      allowedUDPPorts = [5900];
    };
  };

  services.udev.extraRules = ''
    # allow access to raspi cec device for video group (and optionally register it as a systemd device, used below)
    SUBSYSTEM=="vchiq", GROUP="video", MODE="0660", TAG+="systemd", ENV{SYSTEMD_ALIAS}="/dev/vchiq"
  '';

  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";

  # optional: attach a persisted cec-client to `/run/cec.fifo`, to avoid the CEC ~1s startup delay per command
  # scan for devices: `echo 'scan' &gt; /run/cec.fifo ; journalctl -u cec-client.service`
  # set pi as active source: `echo 'as' &gt; /run/cec.fifo`
  systemd.sockets."cec-client" = {
    after = ["dev-vchiq.device"];
    bindsTo = ["dev-vchiq.device"];
    wantedBy = ["sockets.target"];
    socketConfig = {
      ListenFIFO = "/run/cec.fifo";
      SocketGroup = "video";
      SocketMode = "0660";
    };
  };
  systemd.services."cec-client" = {
    after = ["dev-vchiq.device"];
    bindsTo = ["dev-vchiq.device"];
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      ExecStart = ''${pkgs.libcec}/bin/cec-client -d 1'';
      ExecStop = ''/bin/sh -c "echo q &gt; /run/cec.fifo"'';
      StandardInput = "socket";
      StandardOutput = "journal";
      Restart = "no";
    };
  };

  system.stateVersion = "23.11";
}
