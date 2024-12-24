{
  git-hooks,
  pkgs,
  ...
}: let
  hook = {
    command,
    stages ? ["pre-commit"],
    ...
  }: {
    inherit stages;
    enable = true;
    name = command;
    entry = command;
    pass_filenames = false;
  };
in {
  git-hooks = git-hooks.lib.${pkgs.system}.run {
    src = ./..;
    hooks = {
      alejandra.enable = true;
      convco.enable = true;
      credo = hook {command = "mix credo --strict";};
      formatting = hook {command = "mix format --check-formatted";};
      dialyzer = hook {command = "mix dialyzer";};
      test = hook {command = "mix test";};
    };
  };
}
