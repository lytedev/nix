{pkgs, ...}: {
  imports = [
    ./sway.nix
    # ./hyprland.nix
    ./kde-plasma.nix
    ./fonts.nix
    ./user-installed-applications.nix
    ./kde-connect.nix
    ./troubleshooting-tools.nix
    ./development-tools.nix
  ];

  environment = {
    variables = {
      GTK_THEME = "Catppuccin-Mocha-Compact-Sapphire-Dark";
      GTK_USE_PORTAL = "1";
    };

    systemPackages = with pkgs; [
      marksman
      markdown-oxide
      gnupg
      pinentry-tty
      pinentry-curses
    ];
  };

  hardware = {
    opengl = {
      enable = true;
      driSupport32Bit = true;
      driSupport = true;
    };
  };
}
