# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running `nixos-help`).

{ modulesPath, pkgs, lib, inputs, ... }:

{
  imports =
    [
      ../modules/intel.net
      ../modules/desktop-usage.nix

      (modulesPath + "/installer/scan/not-detected.nix")
    ];

  # hardware
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot.enable = true;
  boot.initrd.availableKernelModules = [ "xhci_pci" "nvme" "usb_storage" "sd_mod" ];
  services.pcscd.enable = true; # why do I need this? SD card slot?

  # wifi
  networking.networkmanager.enable = true;

  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";

  # TODO: hibernation? I've been using [deep] in /sys/power/mem_sleep alright
  # with this machine so it may not be necessary?
  # need to measure percentage lost per day, but I think it's around 10%/day

  # TODO: fonts? right now, I'm just installing to ~/.local/share/fonts

  hardware.bluetooth.enable = true;

  networking.hostName = "thinker";

  # I own a printer in the year of our Lord 2023
  services.printing.enable = true;

  environment.systemPackages = with pkgs; [
    age
    bat
    bind
    bottom
    brightnessctl
    clang
    curl
    delta
    dog
    dtach
    dua
    exa
    fd
    feh
    file
    fwupd
    gcc
    gimp
    git
    git-lfs
    grim
    inputs.helix.packages."x86_64-linux".helix
    inputs.rtx.packages."x86_64-linux".rtx
    hexyl
    htop
    inkscape
    inotify-tools
    iputils
    killall
    kitty
    krita
    libinput
    libinput-gestures
    libnotify
    lutris
    gnumake
    mako
    mosh
    nmap
    nnn
    nil
    nixpkgs-fmt
    noto-fonts
    openssl
    pamixer
    pavucontrol
    pciutils
    pgcli
    playerctl
    podman-compose
    pulseaudio
    pulsemixer
    rclone
    restic
    ripgrep
    rsync
    sd
    slurp
    sops
    steam
    swaybg
    swayidle
    swaylock
    tmux
    traceroute
    unzip
    vlc
    vulkan-tools
    watchexec
    waybar
    wget
    wireplumber
    wine
    wl-clipboard
    wofi
    xh
    zathura
    zellij
    zstd
  ];

  programs.thunar.enable = true;

  services.tailscale = {
    enable = true;
    useRoutingFeatures = "client";
  };

  environment.variables = {
    EDITOR = "hx";
  };

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
    };
    listenAddresses = [
      { addr = "0.0.0.0"; port = 22; }
    ];
  };

  services.postgresql = {
    enable = true;
    ensureDatabases = [ "daniel" ];
    ensureUsers = [
      {
        name = "daniel";
        ensurePermissions = {
          "DATABASE daniel" = "ALL PRIVILEGES";
        };
      }
    ];
    enableTCPIP = true;

    package = pkgs.postgresql_15;

    authentication = pkgs.lib.mkOverride 10 ''
      #type database  DBuser    auth-method
      local all       postgres  peer map=superuser_map
      local all       daniel    peer map=superuser_map
      local sameuser  all       peer map=superuser_map

      # lan ipv4
      host  all       all     10.0.0.0/24   trust
      host  all       all     127.0.0.1/32  trust

      # tailnet ipv4
      host       all       all     100.64.0.0/10 trust
    '';

    identMap = ''
      # ArbitraryMapName systemUser DBUser
        superuser_map    root       postgres
        superuser_map    postgres   postgres
        superuser_map    daniel     postgres
        # Let other names login as themselves
        superuser_map   /^(.*)$    \1
    '';
  };


  virtualisation = {
    podman = {
      enable = true;

      # Create a `docker` alias for podman, to use it as a drop-in replacement
      dockerCompat = true;

      # Required for containers under podman-compose to be able to talk to each other.
      defaultNetwork.settings.dns_enabled = true;
    };

    oci-containers = {
      backend = "podman";
    };
  };

  networking.firewall = {
    enable = true;
    allowPing = true;
    allowedTCPPorts = [ ];
    allowedUDPPorts = [ ];
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.05"; # Did you read the comment?

}

