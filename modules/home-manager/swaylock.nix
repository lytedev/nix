{
  font,
  # colors,
  ...
}: {
  programs.swaylock = {
    enable = true;
    settings = {
      color = "ffffffff";
      image = "~/.wallpaper";
      font = font.name;
      show-failed-attempts = true;
      ignore-empty-password = true;

      indicator-radius = "150";
      indicator-thickness = "30";

      inside-color = "11111100";
      inside-clear-color = "11111100";
      inside-ver-color = "11111100";
      inside-wrong-color = "11111100";

      key-hl-color = "a1efe4";
      separator-color = "11111100";

      line-color = "111111cc";
      line-uses-ring = true;

      ring-color = "111111cc";
      ring-clear-color = "f4bf75";
      ring-ver-color = "66d9ef";
      ring-wrong-color = "f92672";
    };
  };
}
