inputs:
let
  inherit (inputs.self.flakeLib)
    host
    stableHost
    steamdeckHost
    mobileHost
    baseHost
    stable
    ;
in
{
  beefcake = stableHost ./beefcake.nix { };
  dragon = host ./dragon.nix { };
  foxtrot = host ./foxtrot.nix { };
  thinker = host ./thinker.nix { };
  # htpc = host ./htpc.nix { }; # broken: rtl8812au marked broken upstream
  # htpc2 = stableHost ./htpc2.nix { };
  router = stableHost ./router.nix { };
  bigtower = host ./bigtower.nix { };
  rascal = stableHost ./rascal.nix { };
  pebble = stableHost ./pebble.nix { };
  flipflop = host ./flipflop.nix { };
  flipflop2 = host ./flipflop2.nix { };
  babyflip = host ./babyflip { };
  flab = host ./flab.nix { };
  sanctuary = host ./sanctuary.nix { };

  steamdeck = steamdeckHost ./steamdeck.nix { };
  steamdeckoled = steamdeckHost ./steamdeckoled.nix { };
  # pinephone = mobileHost "pine64-pinephone" ./pinephone.nix { }; # temporarily disabled

  pv23 = baseHost (
    stable
    // {
      extraModules = [
        (inputs.self.diskoConfigurations.unencrypted {
          disk = "/dev/sda";
          rootDatasetEncrypt = false;
        })
      ];
    }
  ) ./generic.nix;

  vmTestbed =
    let
      nixpkgs = inputs.nixpkgs-unstable;
    in
    baseHost {
      inherit nixpkgs;
      extraModules = [
        (inputs.self.diskoConfigurations.zfsEncryptedUser {
          fullDiskDevicePath = "/dev/vda";
          diskName = "vmtestbed";
          espSize = "256M";
          rootDatasetKeyText = "yoyoyoyo";
          rootDatasetKeyLocation = "file:///tmp/secret.key";
        })
        {
          users.users.root.password = "root";
          system.stateVersion = "25.05";
          networking.hostName = "lytevmtestbed";
          networking.networkmanager.enable = false;

          boot = {
            loader = {
              efi.canTouchEfiVariables = true;
              systemd-boot.enable = true;
            };
          };

          # head -c4 /dev/urandom | od -A none -t x4
          networking.hostId = "5c4fc42c";

          lyte.shell.enable = false;
          lyte.desktop.enable = false;
          # shell and desktop already disabled above
        }
      ];
    } ./empty.nix { };

  liveImage = baseHost rec {
    nixpkgs = inputs.nixpkgs-unstable;
    extraModules = [
      (nixpkgs + "/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix")
      {
        system.stateVersion = "25.05";
        networking.hostName = "live-nixos-lyte";
        networking.networkmanager.enable = nixpkgs.lib.mkForce true;

        lyte.shell.enable = true;
        lyte.desktop.enable = true;
        # shell and desktop already enabled above
      }
    ];
  } ./live.nix { };

  # Installer ISO with a target host's closure pre-cached in the nix store.
  # Build: nix build .#nixosConfigurations.foxtrotInstaller.config.system.build.isoImage
  foxtrotInstaller =
    let
      foxtrotToplevel = inputs.self.nixosConfigurations.foxtrot.config.system.build.toplevel;
      nixpkgs = inputs.nixpkgs-unstable;
      installScript = nixpkgs.legacyPackages.x86_64-linux.writeShellScriptBin "install-foxtrot" ''
        set -euo pipefail
        echo "=== Foxtrot NixOS Installer ==="
        echo "Foxtrot closure: ${foxtrotToplevel}"
        echo ""

        read -s -r -p "Enter LUKS passphrase: " pass1; echo
        read -s -r -p "Confirm passphrase: " pass2; echo
        if [ "$pass1" != "$pass2" ]; then
          echo "error: passphrases do not match"
          exit 1
        fi
        echo -n "$pass1" > /tmp/secret.key

        echo ""
        echo "WARNING: This will WIPE /dev/nvme0n1 and install NixOS."
        read -r -p "Type YES to proceed: " confirm
        if [ "$confirm" != "YES" ]; then
          echo "Aborted."
          exit 1
        fi

        echo ""
        echo ">>> Running disko (partitioning /dev/nvme0n1)..."
        disko --flake '${inputs.self}#standardWithHibernateSwap' \
          --arg disk '"/dev/nvme0n1"' --arg swapSize '"32G"' --mode disko

        echo ""
        echo ">>> Running nixos-install (fully offline from local store)..."
        nixos-install --flake '${inputs.self}#foxtrot' \
          --no-write-lock-file \
          --option substituters ""

        echo ""
        echo ">>> Setting daniel's password..."
        nixos-enter --root /mnt -c 'passwd daniel'

        echo ""
        echo "=== Done! ==="
        echo "Reboot and remove the USB drive."
        echo ""
        echo "After first boot, rotate sops keys:"
        echo "  ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub"
        echo "  # Update &ssh-foxtrot in .sops.yaml"
        echo "  # sops updatekeys secrets/foxtrot/secrets.yml secrets/workstations/secrets.yml"
      '';
    in
    baseHost rec {
      inherit nixpkgs;
      extraModules = [
        (nixpkgs + "/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix")
        {
          system.stateVersion = "25.05";
          networking.hostName = "foxtrot-installer";
          networking.networkmanager.enable = nixpkgs.lib.mkForce true;

          # Include the foxtrot system closure in the ISO's nix store
          system.extraDependencies = [ foxtrotToplevel ];

          environment.systemPackages = [
            installScript
            nixpkgs.legacyPackages.x86_64-linux.disko
            nixpkgs.legacyPackages.x86_64-linux.jq
            nixpkgs.legacyPackages.x86_64-linux.git
          ];

          # Show instructions on login
          users.users.root.initialPassword = "root";
          environment.etc."motd".text = ''

            ╔══════════════════════════════════════════════════╗
            ║         Foxtrot NixOS Installer                  ║
            ║                                                  ║
            ║  Run:  sudo install-foxtrot                      ║
            ║                                                  ║
            ║  The full foxtrot closure is pre-cached.         ║
            ║  No network required.                            ║
            ╚══════════════════════════════════════════════════╝

          '';

          lyte.shell.enable = true;
          lyte.desktop.enable = false;
        }
      ];
    } ./live.nix { };

  # arm-dragon = host ./dragon.nix { system = "aarch64-linux"; };
}
