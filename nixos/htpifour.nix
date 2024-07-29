{
  pkgs,
  lib,
  hardware,
  outputs,
  modulesPath,
  ...
}: {
  nixpkgs.hostPlatform = "aarch64-linux";
  networking.hostName = "htpifour";

  imports = with outputs.nixosModules; [
    (modulesPath + "/installer/scan/not-detected.nix")
    hardware.nixosModules.raspberry-pi-4
    outputs.diskoConfigurations.unencrypted
    desktop-usage
    # gnome
    kde-plasma
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

  home-manager.users.daniel = {
    imports = with outputs.homeManagerModules; [linux-desktop wallpaper-manager];
  };

  environment.systemPackages = with pkgs;
  #with pkgs;
    [
      # libcec
      libraspberrypi
      raspberrypi-eeprom
    ];

  programs.steam.enable = true;
  programs.steam.remotePlay.openFirewall = true;

  services.xserver = {
    displayManager = {
      # lightdm.enable = true;
      autoLogin.enable = true;
      autoLogin.user = "daniel";
    };
    # videoDrivers = ["fbdev"];
  };

  hardware.raspberry-pi."4".fkms-3d.enable = true;
  hardware.raspberry-pi."4".audio.enable = true;

  nixpkgs.overlays = [
    # nixos-22.05
    # (self: super: { libcec = super.libcec.override { inherit (self) libraspberrypi; }; })
    # nixos-22.11
    # (self: super: {libcec = super.libcec.override {withLibraspberrypi = true;};})
  ];

  # Workaround for GNOME autologin: https://github.com/NixOS/nixpkgs/issues/103746#issuecomment-945091229
  # systemd.services."getty@tty1".enable = false;
  # systemd.services."autovt@tty1".enable = false;

  # hardware
  systemd.targets.sleep.enable = false;
  systemd.targets.suspend.enable = false;
  systemd.targets.hibernate.enable = false;
  systemd.targets.hybrid-sleep.enable = false;

  powerManagement.enable = false;

  boot = {
    kernelPackages = pkgs.linuxKernel.packages.linux_rpi4;
    initrd.availableKernelModules = ["xhci_pci" "usbhid" "usb_storage"];
    loader = {
      grub.enable = false;
      generic-extlinux-compatible.enable = true;
    };
  };

  networking = {
    networkmanager.enable = true;
    # useDHCP = true;

    firewall = {
      enable = true;
      allowPing = true;
      allowedTCPPorts = [
        22 # ssh
      ];
      allowedUDPPorts = [];
    };
  };

  # services.udev.extraRules = ''
  #   # allow access to raspi cec device for video group (and optionally register it as a systemd device, used below)
  #   SUBSYSTEM=="vchiq", GROUP="video", MODE="0660", TAG+="systemd", ENV{SYSTEMD_ALIAS}="/dev/vchiq"
  # '';

  # powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";

  # optional: attach a persisted cec-client to `/run/cec.fifo`, to avoid the CEC ~1s startup delay per command
  # scan for devices: `echo 'scan' &gt; /run/cec.fifo ; journalctl -u cec-client.service`
  # set pi as active source: `echo 'as' &gt; /run/cec.fifo`
  # systemd.sockets."cec-client" = {
  #   after = ["dev-vchiq.device"];
  #   bindsTo = ["dev-vchiq.device"];
  #   wantedBy = ["sockets.target"];
  #   socketConfig = {
  #     ListenFIFO = "/run/cec.fifo";
  #     SocketGroup = "video";
  #     SocketMode = "0660";
  #   };
  # };
  # systemd.services."cec-client" = {
  #   after = ["dev-vchiq.device"];
  #   bindsTo = ["dev-vchiq.device"];
  #   wantedBy = ["multi-user.target"];
  #   serviceConfig = {
  #     ExecStart = ''${pkgs.libcec}/bin/cec-client -d 1'';
  #     ExecStop = ''/bin/sh -c "echo q &gt; /run/cec.fifo"'';
  #     StandardInput = "socket";
  #     StandardOutput = "journal";
  #     Restart = "no";
  #   };
  # };

  hardware.graphics.driSupport32Bit = lib.mkForce false;

  system.stateVersion = "24.05";
}
