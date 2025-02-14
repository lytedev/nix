{
  hardware,
  self,
  nixpkgs,
  sops-nix,
  disko,
  slippi,
  home-manager,
  nixpkgs-unstable,
  home-manager-unstable,
  ...
}:
let
  baseHost =
    {
      nixpkgs,
      home-manager,
      ...
    }:
    (
      path:
      (
        {
          system ? "x86_64-linux",
        }:
        (nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            hardware = hardware.outputs.nixosModules;
            diskoConfigurations = self.outputs.diskoConfigurations;
          };
          modules = [
            (
              {
                config,
                lib,
                pkgs,
                modulesPath,
                ...
              }:
              {
                imports = [
                  (modulesPath + "/installer/scan/not-detected.nix")
                  home-manager.nixosModules.home-manager
                  sops-nix.nixosModules.sops
                  disko.nixosModules.disko
                  slippi.nixosModules.default
                  self.outputs.nixosModules.common
                ];

                config = {
                  lyte.shell.enable = lib.mkDefault true;
                  lyte.desktop.enable = lib.mkDefault false;

                  nixpkgs = {
                    config.allowUnfree = lib.mkDefault true;
                    overlays = [ self.flakeLib.forSelfOverlay ];
                  };

                  sops = {
                    age = {
                      sshKeyPaths = lib.mkDefault [ "/etc/ssh/ssh_host_ed25519_key" ];
                      keyFile = lib.mkDefault "/var/lib/sops-nix/key.txt";
                      generateKey = lib.mkDefault true;
                    };
                  };

                  # TODO: for each non-system user on the machine?
                  home-manager = {
                    extraSpecialArgs = {
                      config.lyte = config.lyte;
                    };

                    users = {
                      # root = {
                      #   home.stateVersion = lib.mkDefault config.system.stateVersion;
                      #   imports = with self.outputs.homeManagerModules; [
                      #     common
                      #     linux
                      #   ];
                      # };
                      # daniel = {
                      #   home.stateVersion = lib.mkDefault config.system.stateVersion;
                      #   imports = with self.outputs.homeManagerModules; [
                      #     common
                      #     linux
                      #     daniel
                      #   ];
                      # };
                    };
                  };

                  nix = {
                    nixPath = lib.mapAttrsToList (key: value: "${key}=${value.to.path}") config.nix.registry;
                    # registry = lib.mapAttrs (_: value: { flake = value; }) self.inputs;

                    settings = {
                      trusted-users = lib.mkDefault [ "@wheel" ];
                      extra-experimental-features = lib.mkDefault [
                        "nix-command"
                        "flakes"
                      ];
                      auto-optimise-store = lib.mkDefault true;
                    };
                  };

                  systemd.services.nix-daemon.environment.TMPDIR = lib.mkDefault "/var/tmp"; # TODO: why did I do this again?
                  boot.tmp.cleanOnBoot = lib.mkDefault true;
                  programs.gnupg.agent.enable = lib.mkDefault true;
                  time.timeZone = lib.mkDefault "America/Chicago";
                  i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";
                  hardware.enableRedistributableFirmware = lib.mkDefault true;

                  home-manager.useGlobalPkgs = lib.mkDefault true;
                  home-manager.backupFileExtension = lib.mkDefault "hm-backup";

                  users.users.root = {
                    openssh.authorizedKeys.keys = lib.mkDefault [ self.outputs.pubkey ];
                  };

                  services = {
                    openssh = {
                      enable = lib.mkDefault true;

                      settings = {
                        PasswordAuthentication = lib.mkDefault false;
                        KbdInteractiveAuthentication = lib.mkDefault false;
                        PermitRootLogin = lib.mkForce "prohibit-password";
                      };

                      openFirewall = lib.mkDefault true;

                      /*
                        listenAddresses = [
                          { addr = "0.0.0.0"; port = 22; }
                        ];
                      */
                    };
                    avahi = {
                      enable = lib.mkDefault true;
                      reflector = lib.mkDefault true;
                      openFirewall = lib.mkDefault true;
                      nssmdns4 = lib.mkDefault true;
                    };
                    tailscale = {
                      enable = lib.mkDefault true;
                      useRoutingFeatures = lib.mkDefault "client";
                    };
                    journald.extraConfig = lib.mkDefault "SystemMaxUse=1G";
                    xserver.xkb = {
                      layout = lib.mkDefault "us";

                      # have the caps-lock key instead be a ctrl key
                      options = lib.mkDefault "ctrl:nocaps";
                    };
                    smartd.enable = lib.mkDefault true;
                    fwupd.enable = lib.mkDefault true;
                  };

                  console = {
                    useXkbConfig = lib.mkDefault true;
                    earlySetup = lib.mkDefault true;

                    colors =
                      with self.outputs.style.colors;
                      lib.mkDefault [
                        bg
                        red
                        green
                        orange
                        blue
                        purple
                        yellow
                        fg3
                        fgdim
                        red
                        green
                        orange
                        blue
                        purple
                        yellow
                        fg
                      ];
                  };

                  networking = {
                    hostName = lib.mkDefault "set-a-hostname-dingus";

                    useDHCP = lib.mkDefault true;
                    firewall = {
                      enable = lib.mkDefault true;
                      allowPing = lib.mkDefault true;
                    };
                  };
                };
              }
            )

            (import path)
          ];
        })
      )
    );
  stableHost = baseHost { inherit nixpkgs home-manager; };
  host = baseHost {
    nixpkgs = nixpkgs-unstable;
    home-manager = home-manager-unstable;
  };
in
{
  # beefcake = stableHost ./beefcake.nix { };
  dragon = host ./dragon.nix { };
  # arm-dragon = host ./dragon.nix { system = "aarch64-linux"; };
}
