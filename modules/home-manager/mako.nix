{
  colors,
  font,
  ...
}: {
  services.mako = with colors.withHashPrefix; {
    enable = false; # mako is launched alongside the wm/de instead
    borderSize = 1;
    maxVisible = 5;
    defaultTimeout = 15000;
    font = "Symbols Nerd Font ${toString font.size},${font.name} ${toString font.size}";
    # TODO: config

    backgroundColor = bg;
    textColor = text;
    borderColor = primary;
    progressColor = primary;
    anchor = "top-right";

    extraConfig = ''
      [urgency=high]
      border-color=${urgent}
      [urgency=high]
      background-color=${urgent}
      border-color=${urgent}
      text-color=${bg}
    '';
  };
}
