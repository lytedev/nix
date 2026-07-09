{
  # Prototypes for the beefcake impermanence + blue/green design.
  # See ../../lib/doc/beefcake-impermanence-blue-green.md §7.
  #
  # Deliberately a standalone flake (own lock) so the main flake's eval and CI
  # are untouched; nixpkgs is pinned to the same rev the main flake feeds
  # nixosSystem (667d5cf = what beefcake runs) for cache hits.
  description = "beefcake impermanence + blue/green prototypes (run on dragon)";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/667d5cf1c59585031d743c78b394b0a647537c35";
    impermanence.url = "github:nix-community/impermanence";
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # thin-host integration test (P4): same declarative-libvirt module the real
    # beefcake-host uses
    nixvirt = {
      url = "github:AshleyYakeley/NixVirt";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      impermanence,
      sops-nix,
      disko,
      nixvirt,
    }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      checks.${system} = {
        # P1a: impermanence *semantics* — ephemeral root, /persist survives,
        # sops decrypts on a wiped root, postgres + DynamicUser state intact.
        semantics = import ./semantics-test.nix { inherit pkgs impermanence sops-nix; };
        # P2: blue/green *handoff* — two guests sequentially own a shared
        # disk-backed ZFS pool (the zstorage stand-in); cutover + rollback.
        handoff = import ./handoff-test.nix { inherit pkgs; };
        # P3: Model B storage primitives — postgres on ext4-on-zvol, live
        # snapshot+clone opened by a second instance (validation), two-way
        # isolation, clone discard, share-dataset xattr/acl semantics.
        modelb-storage = import ./modelb-storage-test.nix { inherit pkgs; };
        # P-overlay (Phase 3): guest /nix overlay hybrid — local-overlay store
        # composes a RO lower (shared host store) + writable per-slot upper;
        # proves DB layering + delta isolation.
        overlay-nix = import ./overlay-nix-test.nix { inherit pkgs; };
      };

      # rollback = P1b (disko image, initrd @blank rollback — see rollback-demo).
      # slot-*/demo-host = the hands-on demo (nix run .#demo): a persistent
      # "thin host" VM owning a ZFS pool, running blue/green slot VMs (nested
      # KVM) with real services (vaultwarden + caddy + postgres) on Model B
      # storage attachments.
      nixosConfigurations =
        let
          qemuVm = "${nixpkgs}/nixos/modules/virtualisation/qemu-vm.nix";
          mkSlot =
            name: extra:
            nixpkgs.lib.nixosSystem {
              inherit system;
              modules = [
                qemuVm
                (import ./demo/slot-config.nix { slotName = name; })
                extra
              ];
            };
        in
        {
          rollback = nixpkgs.lib.nixosSystem {
            inherit system;
            modules = [
              disko.nixosModules.disko
              impermanence.nixosModules.impermanence
              ./rollback-config.nix
            ];
          };
          # P-overlay M2: boots with /nix/store as an OverlayFS (RO base + RW
          # upper) — the guest /nix strategy proven at boot (see overlay-boot-demo).
          overlay-boot = nixpkgs.lib.nixosSystem {
            inherit system;
            modules = [
              disko.nixosModules.disko
              ./overlay-boot-config.nix
            ];
          };
          # P4-integration: the mini guest (M2 image + guest-hardware mechanisms)
          # and the outer thin host (beefcake-host's stack in miniature). See
          # thinhost-demo.
          mini-guest = nixpkgs.lib.nixosSystem {
            inherit system;
            modules = [
              disko.nixosModules.disko
              ./thinhost-mini-guest.nix
            ];
          };
          thinhost = nixpkgs.lib.nixosSystem {
            inherit system;
            modules = [
              qemuVm
              nixvirt.nixosModules.default
              (import ./thinhost-config.nix { inherit nixvirt; })
            ];
          };
          slot-blue = mkSlot "blue" { };
          slot-green = mkSlot "green" {
            # The candidate generation: visibly different from blue.
            environment.etc."generation-note".text = "green: the CANDIDATE generation (pretend nixpkgs bump)";
          };
          demo-host = nixpkgs.lib.nixosSystem {
            inherit system;
            modules = [
              qemuVm
              (import ./demo/host-config.nix {
                slotVMs = {
                  blue = self.nixosConfigurations.slot-blue.config.system.build.vm;
                  green = self.nixosConfigurations.slot-green.config.system.build.vm;
                };
              })
            ];
          };
        };

      packages.${system} = {
        rollback-demo = import ./rollback-demo.nix {
          inherit pkgs;
          rollbackSystem = self.nixosConfigurations.rollback;
        };
        overlay-boot-demo = import ./overlay-boot-demo.nix {
          inherit pkgs;
          overlaySystem = self.nixosConfigurations.overlay-boot;
        };
        thinhost-demo = import ./thinhost-demo.nix {
          inherit pkgs;
          thinhostSystem = self.nixosConfigurations.thinhost;
          miniGuestSystem = self.nixosConfigurations.mini-guest;
        };
        demo = pkgs.writeShellApplication {
          name = "modelb-demo";
          text = ''
            state="''${DEMO_STATE_DIR:-''${XDG_CACHE_HOME:-$HOME/.cache}/beefcake-modelb-demo}"
            mkdir -p "$state"
            # ssh refuses group/world-readable identity files, and the repo
            # checkout leaves the test key at 0644 — install a 0600 copy.
            install -m 600 ${./keys/demo-ssh-key} "$state/ssh-key"
            cd "$state"
            export NIX_DISK_IMAGE=demo-host.qcow2
            export QEMU_NET_OPTS="hostfwd=tcp::2200-:22,hostfwd=tcp::2201-:12201,hostfwd=tcp::2202-:12202,hostfwd=tcp::8080-:8000,hostfwd=tcp::8081-:13001,hostfwd=tcp::8082-:13002"
            cat <<'BANNER'
            ================== Model B hands-on demo ==================
            demo host : ssh -p 2200 -i ~/.cache/beefcake-modelb-demo/ssh-key root@localhost
            blue slot : ssh -p 2201 ...   green slot: ssh -p 2202 ...
            service   : http://localhost:8080  (the VIP -> active slot)
            blue web  : http://localhost:8081   green web: http://localhost:8082
            suggested tour (on the demo host):
              demo-status; slot-run blue; vip-set blue
              -> create a vaultwarden account/entry at :8080
              slot-run green validate   # green vs CLONES, egress cut
              -> poke :8082, your data is there; writes are throwaway
              cutover green             # the real thing
              -> :8080 now green, your data followed; cutover blue = rollback
            (this terminal becomes the demo host serial console; C-a x quits)
            ============================================================
            BANNER
            exec ${self.nixosConfigurations.demo-host.config.system.build.vm}/bin/run-demo-host-vm
          '';
        };
      };

      apps.${system} = {
        rollback-demo = {
          type = "app";
          program = "${self.packages.${system}.rollback-demo}/bin/rollback-demo";
        };
        overlay-boot-demo = {
          type = "app";
          program = "${self.packages.${system}.overlay-boot-demo}/bin/overlay-boot-demo";
        };
        thinhost-demo = {
          type = "app";
          program = "${self.packages.${system}.thinhost-demo}/bin/thinhost-demo";
        };
        demo = {
          type = "app";
          program = "${self.packages.${system}.demo}/bin/modelb-demo";
        };
      };
    };
}
