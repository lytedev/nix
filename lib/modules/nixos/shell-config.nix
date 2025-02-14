{
  lib,
  pkgs,
  config,
  ...
}: let
  cfg = config.lyte.shell;
in {
  options = {
    lyte = {
      shell = {
        enable = lib.mkEnableOption "Enable my default shell configuration and applications";
      };
    };
  };
  config = lib.mkIf cfg.enable {
    nix-index = {
      enable = true;
      enableBashIntegration = true;
      enableFishIntegration = true;
      enableZshIntegration = true;
    };
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
    programs.btop = {
      enable = true;
      package = pkgs.btop.override {
        rocmSupport = true;
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
        zellij
        helix
        aria2
        bat
        curl
        dua
        eza
        fd
        file
        inetutils
        iputils
        iputils
        killall
        nettools
        ripgrep
        rsync
        sd
        xh
      ];
    };
  };
}
