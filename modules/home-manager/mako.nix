{
  colors,
  font,
  ...
}: {
  services.mako = with colors.withHashPrefix; {
    enable = true;
    borderSize = 1;
    maxVisible = 5;
    defaultTimeout = 15000;
    font = "Symbols Nerd Font ${toString font.size},${font.name} ${toString font.size}";
    # TODO: config

    backgroundColor = bg;
    textColor = text;
    borderColor = primary;
    progressColor = primary;

    extraConfig = ''
      [urgency=high]
      border-color=${urgent}
      [urgency=high]
      background-color=${urgent}
    '';
  };
}