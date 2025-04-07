inputs: {
  # boot.tmp.useTmpfs = true;
  # boot.uki.tries = 3;
  # services.irqbalance.enable = true;

  nix-config = (import ../../../flake.nix).nixConfig;

  default = import ./default-module.nix inputs;
  shell-defaults-and-applications = import ./shell-config.nix;
  deno-netlify-ddns-client = import ./deno-netlify-ddns-client.nix;
  gnome = import ./gnome.nix;
  laptop = import ./laptop.nix;
  plasma6 = import ./plasma.nix;
  gaming = import ./gaming.nix;
  pipewire = import ./pipewire.nix;
  podman = import ./podman.nix;
  virtual-machines = import ./virtual-machines.nix;
  postgres = import ./postgres.nix;
  desktop = import ./desktop.nix;
  printing = import ./printing.nix;
  wifi = import ./wifi.nix;
  restic = import ./restic.nix;
  router = import ./router.nix;
  kanidm = import ./kanidm.nix;

  remote-disk-key-entry-on-boot =
    {
      # lib,
      # pkgs,
      ...
    }:
    {
      /*
        https://nixos.wiki/wiki/Remote_disk_unlocking
        "When using DHCP, make sure your computer is always attached to the network and is able to get an IP adress, or the boot process will hang."
        ^ seems less than ideal
      */
      boot.kernelParams = [ "ip=dhcp" ];
      boot.initrd = {
        # availableKernelModules = ["r8169"]; # ethernet drivers
        systemd.users.root.shell = "/bin/cryptsetup-askpass";
        network = {
          enable = true;
          ssh = {
            enable = true;
            port = 22;
            authorizedKeys = [ inputs.self.outputs.pubkey ];
            hostKeys = [ "/etc/secrets/initrd/ssh_host_rsa_key" ];
          };
        };
      };
    };
}
