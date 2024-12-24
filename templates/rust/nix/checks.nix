{
  pkgs,
  git-hooks,
  ...
}: {
  git-hooks = git-hooks.lib.${pkgs.system}.run {
    src = ./..;
    hooks = {
      alejandra.enable = true;
      cargo-check.enable = true;
      convco.enable = true;
      cargo-test = {
        enable = true;
        name = "cargo-test";
        entry = "cargo test";
        # types = ["rust"];
        # language = "rust";
        pass_filenames = false;
        stages = ["pre-commit"];
      };
      clippy.enable = true;
      rustfmt.enable = true;
    };
  };
}
