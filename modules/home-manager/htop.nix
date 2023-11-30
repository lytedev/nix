{
  programs.htop = {
    enable = true;
    settings = {
      hide_kernel_threads = 1;
      hide_userland_threads = 1;
      show_program_path = 0;
      header_margin = 0;
      show_cpu_frequency = 1;
      highlight_base_name = 1;
      tree_view = 0;
    };
  };
}
