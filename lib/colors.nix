{nixpkgs, ...}: {
  schemes = let
    mkColorScheme = scheme @ {
      scheme-name,
      bg,
      bg2,
      bg3,
      bg4,
      bg5,
      fg,
      fg2,
      fg3,
      fgdim,
      # pink,
      purple,
      red,
      orange,
      yellow,
      green,
      # teal,
      blue,
    }: let
      base =
        {
          # aliases?
          text = fg;
          primary = blue;
          urgent = red;

          # blacks
          "0" = bg4;
          "8" = bg5;

          "1" = red;
          "9" = red;
          "2" = green;
          "10" = green;
          "3" = orange;
          "11" = orange;
          "4" = blue;
          "12" = blue;
          "5" = purple;
          "13" = purple;
          "6" = yellow;
          "14" = yellow;

          # whites
          "7" = fg2;
          "15" = fg3;
        }
        // scheme;
    in
      {
        withHashPrefix = nixpkgs.lib.mapAttrs (_: value: "#${value}") base;
      }
      // base;
  in {
    donokai = mkColorScheme {
      scheme-name = "donokai";
      bg = "111111";
      bg2 = "181818";
      bg3 = "222222";
      bg4 = "292929";
      bg5 = "333333";

      fg = "f8f8f8";
      fg2 = "d8d8d8";
      fg3 = "c8c8c8";
      fgdim = "666666";

      red = "f92672";
      green = "a6e22e";
      yellow = "f4bf75";
      blue = "66d9ef";
      purple = "ae81ff";
      # teal = "a1efe4";
      orange = "fab387";
    };
    catppuccin-mocha-sapphire = mkColorScheme {
      scheme-name = "catppuccin-mocha-sapphire";
      bg = "1e1e2e";
      bg2 = "181825";
      bg3 = "313244";
      bg4 = "45475a";
      bg5 = "585b70";

      fg = "cdd6f4";
      fg2 = "bac2de";
      fg3 = "a6adc8";
      fgdim = "6c7086";

      # pink = "f5e0dc";
      purple = "cba6f7";
      red = "f38ba8";
      orange = "fab387";
      yellow = "f9e2af";
      green = "a6e3a1";
      # teal = "94e2d5";
      blue = "74c7ec";
    };
  };
}
