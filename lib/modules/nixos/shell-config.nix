{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.lyte.shell;
in
{
  options = {
    lyte = {
      shell = {
        enable = lib.mkEnableOption "Enable my default shell configuration and applications";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.daniel = { };

    programs.nix-index.enable = true;
    programs.command-not-found.enable = false;
    users = {
      defaultUserShell = pkgs.fish;
    };
    programs = {
      fish.enable = true;
      traceroute.enable = true;
      git = {
        enable = true;
        package = pkgs.gitFull;
        lfs.enable = true;
      };
    };
    environment = {
      variables = {
        EDITOR = "hx";
        SYSTEMD_EDITOR = "hx";
        VISUAL = "hx";
        PAGER = "bat --style=plain";
        MANPAGER = "bat --style=plain";
      };
      systemPackages = with pkgs; [
        aria2
        bat
        bottom
        btop
        comma
        curl
        dnsutils
        dogdns
        dua
        eza
        fd
        file
        helix
        hexyl
        htop
        iftop
        inetutils
        iputils
        killall
        nettools
        nmap
        pciutils
        unixtools.xxd
        ripgrep
        rsync
        sd
        usbutils
        xh
        zellij
      ];
    };

  };
}
