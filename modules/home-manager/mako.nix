{style, ...}: {
  services.mako = with style.colors.withHashPrefix; {
    enable = false;

    anchor = "top-right";

    extraConfig = ''
      border-size=1
      max-visible=5
      default-timeout=15000
      font=Symbols Nerd Font ${toString font.size},${font.name} ${toString font.size}
      anchor=top-right

      background-color=${colors.bg}
      text-color=${colors.text}
      border-color=${colors.primary}
      progress-color=${colors.primary}

      [urgency=high]
      border-color=${urgent}

      [urgency=high]
      background-color=${urgent}
      border-color=${urgent}
      text-color=${bg}
    '';
  };
}
