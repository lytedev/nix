{
  pkgs,
  # colors,
  ...
}: {
  programs.bat = {
    enable = true;
    config = {
      theme = "ansi";
    };
    # themes = {
    #   "Catppuccin-mocha" = builtins.readFile (pkgs.fetchFromGitHub
    #     {
    #       owner = "catppuccin";
    #       repo = "bat";
    #       rev = "477622171ec0529505b0ca3cada68fc9433648c6";
    #       sha256 = "6WVKQErGdaqb++oaXnY3i6/GuH2FhTgK0v4TN4Y0Wbw=";
    #     }
    #     + "/Catppuccin-mocha.tmTheme");
    # };
  };

  home.shellAliases = {
    cat = "bat";
  };
}
