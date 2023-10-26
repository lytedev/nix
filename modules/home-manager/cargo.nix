{config, ...}: {
  home.file."${config.xdg.configHome}/cargo/config.toml" = {
    enable = true;
    text = ''
      [build]
      rustdocflags = ["--default-theme=ayu"];
    '';
  };
}
