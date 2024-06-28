{
  overlays,
  config,
  lib,
  pkgs,
  colors,
  sops-nix,
  home-manager,
  disko,
  modulesPath,
  ...
}: let
  inherit (pkgs) system;
in {
  users.groups.valerie = {};
  users.groups.daniel = {};

  users.users = {
    daniel = {
      isNormalUser = true;
      home = "/home/daniel/.home";
      createHome = true;
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAPLXOjupz3ScYjgrF+ehrbp9OvGAWQLI6fplX6w9Ijb daniel@lyte.dev"
      ];
      group = "daniel";
      extraGroups = ["users" "wheel" "video" "dialout" "uucp"];
      packages = [];
    };

    valerie = {
      isNormalUser = true;
      home = "/home/valerie";
      createHome = true;
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAPLXOjupz3ScYjgrF+ehrbp9OvGAWQLI6fplX6w9Ijb daniel@lyte.dev"
      ];
      group = "valerie";
      extraGroups = ["users" "video"];
      packages = [];
    };
  };

  programs = {
    fish = {
      enable = true;
    };

    tmux = {
      enable = true;
      clock24 = true;
    };

    traceroute.enable = true;

    git = {
      enable = true;
      package = pkgs.gitFull;

      lfs = {
        enable = true;
      };
    };

    # https://github.com/nix-community/home-manager/issues/3113
    dconf.enable = true;
  };

  time = {
    timeZone = "America/Chicago";
  };

  users = {
    defaultUserShell = pkgs.fish;
  };

  # TODO: should not be in common?
  # services.udev.extraRules = ''
  #   # https://betaflight.com/docs/wiki/archive/Installing-Betaflight#step-1
  #   # ACTION=="add", SUBSYSTEM=="usb", ATTRS{idVendor}=="2e3c", ATTRS{idProduct}=="df11", MODE="0664", GROUP="uucp"
  #   # ACTION=="add", SUBSYSTEM=="usb", ATTRS{idVendor}=="0483", ATTRS{idProduct}=="df11", MODE="0664", GROUP="uucp"'
  # '';

  nixpkgs = {
    # You can add overlays here
    overlays = [
      # Add overlays your own flake exports (from overlays and pkgs dir):
      overlays.additions
      overlays.modifications
      overlays.unstable-packages

      # You can also add overlays exported from other flakes:
      # neovim-nightly-overlay.overlays.default

      # Or define it inline, for example:
      # (final: prev: {
      #   hi = final.hello.overrideAttrs (oldAttrs: {
      #     patches = [ ./change-hello-to-hi.patch ];
      #   });
      # })
    ];
    # Configure your nixpkgs instance
    config = {
      # Disable if you don't want unfree packages
      allowUnfree = true;
    };
  };

  nix = {
    # This will additionally add your inputs to the system's legacy channels
    # Making legacy nix commands consistent as well, awesome!
    # Not sure why I would need this...
    # nixPath = lib.mapAttrsToList (key: value: "${key}=${value.to.path}") config.nix.registry;

    # This will add each flake input as a registry
    # To make nix3 commands consistent with your flake
    # registry = lib.mapAttrs (_: value: {flake = value;}) inputs;

    settings = {
      trusted-users = ["root" "daniel"];

      experimental-features = lib.mkDefault ["nix-command" "flakes"];

      substituters = [
        "https://cache.nixos.org/"
        "https://helix.cachix.org"
        "https://nix-community.cachix.org"
        "https://nix.h.lyte.dev"
      ];

      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "helix.cachix.org-1:ejp9KQpR1FBI2onstMQ34yogDm4OgU2ru6lIwPvuCVs="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "h.lyte.dev:HeVWtne31ZG8iMf+c15VY3/Mky/4ufXlfTpT8+4Xbs0="
      ];

      auto-optimise-store = false;
    };
  };

  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="backlight", RUN+="${pkgs.coreutils}/bin/chgrp video /sys/class/backlight/%k/brightness"
    ACTION=="add", SUBSYSTEM=="backlight", RUN+="${pkgs.coreutils}/bin/chmod g+w /sys/class/backlight/%k/brightness"
  '';

  # # TODO: regular cron or something?
  # programs.nix-index = {
  #   enable = true;
  #   # enableFishIntegration = true;
  # };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  system.stateVersion = lib.mkDefault "23.11";
}
