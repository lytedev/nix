{
  pkgs,
  lib,
  config,
  options,
  ...
}:
let
  cfg = config.lyte.desktop;
in
{
  options = {
    lyte = {
      desktop = {
        enable = lib.mkEnableOption "Enable my default desktop configuration and applications";
      };
    };
  };
  config = lib.mkIf cfg.enable {
    services.xserver.desktopManager.gnome.enable = true;
    environment.systemPackages = [ pkgs.wl-clipboard ];

    fonts.packages = [
      (
        # allow nixpkgs 24.11 and unstable to both work
        if builtins.hasAttr "nerd-fonts" pkgs then
          (pkgs.nerd-fonts.symbols-only)
        else
          (pkgs.nerdfonts.override { fonts = [ "NerdFontsSymbolsOnly" ]; })
      )
      pkgs.iosevkaLyteTerm
    ];

    xdg.portal.enable = true;

    hardware =
      if builtins.hasAttr "graphics" options.hardware then
        {
          graphics = {
            enable = true;
            # enable32Bit = true;
            /*
              driSupport32Bit = true;
              driSupport = true;
            */
          };
        }
      else
        {
          opengl = {
            enable = true;
            # driSupport32Bit = true;
            driSupport = true;
          };
        };

    services.flatpak.enable = true;
    programs.appimage.binfmt = true;
    services.printing.enable = true;
    programs.virt-manager.enable = config.virtualisation.libvirtd.enable;
  };
}
