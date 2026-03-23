inputs: {
  default = import ./default-module.nix inputs;
  shell-defaults-and-applications = import ./shell-config.nix;
  user-env = import ./user-env.nix;
}
