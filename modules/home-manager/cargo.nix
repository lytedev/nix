{config, ...}: {
  home.file."${config.home.homeDirectory}/.cargo/config.toml" = {
    enable = true;
    text = ''
      [build]
      rustdocflags = ["--default-theme=ayu"]
    '';
  };

  # home.sessionVariables = {
  #   RUSTDOCFLAGS = "--default-theme=ayu";
  # };
}
