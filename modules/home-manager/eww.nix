{
  programs.eww = {
    enable = true;
  };

  home.file.".config/eww/eww.yuck" = {
    enable = true;
    text = builtins.readFile ./eww/eww.yuck;
  };
}
