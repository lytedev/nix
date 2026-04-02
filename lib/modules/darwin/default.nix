inputs: {
  default = import ./default-module.nix inputs;
  shell-defaults-and-applications = import ../shared/shell-config.nix;
  user-env = import ../shared/user-env.nix;
  desktop = import ./desktop.nix;
}
