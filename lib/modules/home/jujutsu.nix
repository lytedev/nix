{
  fullName,
  config,
  ...
}:
let
  email = config.accounts.email.accounts.primary.address;

in
{
  config = {
    programs.jujutsu = {
      enable = true;
      settings = {
        user = {
          inherit email;
          name = fullName;
        };
        ui = {
          paginate = "never";
        };
        template-aliases = {
          "format_timestamp(timestamp)" = "timestamp.ago()";
        };
        templates = {
          draft_commit_description = ''
            concat(
              coalesce(description, "\n"),
              surround(
                "\nJJ: This commit contains the following changes:\n", "",
                indent("JJ:     ", diff.stat(72)),
              ),
              "\nJJ: ignore-rest\n",
              diff.git(),
            )
          '';
        };
        aliases = {
          tug = [
            "bookmark"
            "move"
            "--from"
            "heads(::@- & bookmarks())"
            "--to"
            "@-"
          ];
        };
        git = {
          auto-track-bookmarks = true;
          push-new-bookmarks = true;
        };
      };
    };
  };
}
