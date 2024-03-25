{
  # pkgs,
  # outputs,
  ...
}: {
  programs.gitui = {
    enable = true;
    theme = ''
      (
          selected_tab: Some(Reset),
          command_fg: Some(Rgb(205, 214, 244)),
          selection_bg: Some(Rgb(88, 91, 112)),
          selection_fg: Some(Rgb(205, 214, 244)),
          cmdbar_bg: Some(Rgb(24, 24, 37)),
          cmdbar_extra_lines_bg: Some(Rgb(24, 24, 37)),
          disabled_fg: Some(Rgb(127, 132, 156)),
          diff_line_add: Some(Rgb(166, 227, 161)),
          diff_line_delete: Some(Rgb(243, 139, 168)),
          diff_file_added: Some(Rgb(249, 226, 175)),
          diff_file_removed: Some(Rgb(235, 160, 172)),
          diff_file_moved: Some(Rgb(203, 166, 247)),
          diff_file_modified: Some(Rgb(250, 179, 135)),
          commit_hash: Some(Rgb(180, 190, 254)),
          commit_time: Some(Rgb(186, 194, 222)),
          commit_author: Some(Rgb(116, 199, 236)),
          danger_fg: Some(Rgb(243, 139, 168)),
          push_gauge_bg: Some(Rgb(137, 180, 250)),
          push_gauge_fg: Some(Rgb(30, 30, 46)),
          tag_fg: Some(Rgb(245, 224, 220)),
          branch_fg: Some(Rgb(148, 226, 213))
      )
    '';
    # package = pkgs.gitui.overrideAttrs {
    #   version = "5b3e2c9ae3913855f5dbe463c5ae1c04430e7532";

    #   src = pkgs.fetchFromGitHub {
    #     owner = "extrawurst";
    #     repo = "gitui";
    #     rev = "5b3e2c9ae3913855f5dbe463c5ae1c04430e7532";
    #     hash = "sha256-Uf1hGvau6tdZGBHmmNnTd3p/Wlw5Eb3ASI2xaETWnF0=";
    #   };

    #   cargoSha256 = "";
    # };
  };
}
