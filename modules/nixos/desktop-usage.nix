{
  pkgs,
  inputs,
  outputs,
  system,
  ...
}: {
  imports = [
    ./sway.nix
    ./hyprland.nix
    # ./plasma.nix
    # ./gnome.nix
    ./user-installed-applications.nix
    ./kde-connect.nix
  ];

  nixpkgs.overlays = [outputs.overlays.modifications];

  # fonts.packages if unstable?
  fonts.packages = with pkgs;
    [
      (nerdfonts.override {fonts = ["NerdFontsSymbolsOnly"];})
    ]
    ++ (with inputs.nixpkgs.legacyPackages.${system}; [
      (iosevka.override {
        set = "lyteterm";
        privateBuildPlan = ''
          [buildPlans.iosevka-lyteterm]
          family = "IosevkaLyteTerm"
          spacing = "fontconfig-mono"
          serifs = "sans"
          export-glyph-names = true

          [buildPlans.iosevka-lyteterm.ligations]
          inherits = "dlig"
          disables = [ "exeqeqeq", "exeqeq", "exeqeq-dl", "exeq", "ineq", "connected-underscore", "connected-tilde-as-wave" ]

          [buildPlans.iosevka-lyteterm.weights.regular]
          shape = 400
          menu  = 400
          css   = 400

          [buildPlans.iosevka-lyteterm.weights.book]
          shape = 450
          menu  = 450
          css   = 450

          [buildPlans.iosevka-lyteterm.weights.bold]
          shape = 700
          menu  = 700
          css   = 700

          [buildPlans.iosevka-lyteterm.weights.black]
          shape = 900
          menu  = 900
          css   = 900

          # [[buildPlans.iosevka-lyteterm.compatibility-ligatures]]
          # unicode = 57600 # 0xE100
          # featureTag = 'calt'
          # kequence = '<*>'

          [buildPlans.iosevka-lyteterm.variants]
          inherits = "ss01"

          [buildPlans.iosevka-lyteterm.variants.design]
          capital-a = 'curly-serifless'
          capital-b = 'standard-interrupted-serifless'
          capital-c = 'unilateral-inward-serifed'
          capital-d = 'standard-serifless'
          capital-g = 'toothless-rounded-inward-serifed-hooked'
          capital-i = 'serifed'
          capital-j = 'serifed'
          capital-k = 'curly-serifless'
          capital-l = 'motion-serifed'
          capital-m = 'hanging-serifless'
          capital-n = 'asymmetric-serifless'
          capital-p = 'open-serifless'
          capital-q = 'crossing'
          capital-r = 'standing-open-serifless'
          capital-s = 'unilateral-inward-serifed'
          capital-t = 'motion-serifed'
          capital-u = 'toothless-corner-serifless'
          capital-v = 'curly-serifless'
          capital-w = 'curly-serifless'
          capital-x = 'curly-serifless'
          capital-y = 'curly-base-serifed'
          capital-z = 'curly-top-serifed-with-crossbar'
          a = 'double-storey-toothless-corner'
          b = 'toothless-corner-serifless'
          c = 'unilateral-inward-serifed'
          d = 'toothless-corner-serifless'
          e = 'flat-crossbar'
          f = 'tailed'
          g = 'double-storey-open'
          # g = 'single-storey-earless-corner-flat-hook'
          h = 'straight-serifless'
          i = 'tailed-serifed'
          j = 'serifed'
          k = 'curly-serifless'
          l = 'tailed-serifed'
          m = 'earless-corner-double-arch-serifless'
          n = 'earless-corner-straight-serifless'
          p = 'earless-corner-serifless'
          q = 'earless-corner-diagonal-tailed-serifless'
          r = 'earless-corner-serifless'
          s = 'unilateral-inward-serifed'
          t = 'bent-hook-asymmetric'
          u = 'toothless-corner-serifless'
          v = 'curly-serifless'
          w = 'curly-serifless'
          x = 'curly-serifless'
          y = 'curly-turn-serifless'
          z = 'curly-top-serifed-with-crossbar'
          # cyrl-capital-ze = 'unilateral-inward-serifed'
          zero = 'reverse-slashed-split'
          one = 'base'
          two = 'curly-neck'
          three = 'two-arcs'
          four = 'semi-open-non-crossing'
          # five = 'vertical-upper-left-bar'
          five = 'upright-flat'
          six = 'straight-bar'
          seven = 'curly-serifed-crossbar'
          eight = 'two-circles'
          nine = 'straight-bar'
          tilde = 'low'
          asterisk = 'penta-low'
          underscore = 'above-baseline'
          pilcrow = 'low'
          caret = 'low'
          paren = 'flat-arc'
          brace = 'curly-flat-boundary'
          number-sign = 'upright-open'
          ampersand = 'upper-open'
          at = 'compact'
          dollar = 'interrupted'
          cent = 'open'
          percent = 'rings-segmented-slash'
          bar = 'force-upright'
          ascii-single-quote = 'raised-comma'
          ascii-grave = 'straight'
          question = 'smooth'
          punctuation-dot = 'round'
        '';
      })
    ]);

  hardware = {
    opengl = {
      enable = true;
      driSupport32Bit = true;
      driSupport = true;
    };
  };
}
