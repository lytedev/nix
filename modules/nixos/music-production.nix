{pkgs, ...}: {
  # TODO: may want to force nixpkgs-stable for a more-stable music production
  # environment?
  imports = [
    {
      # DAW
      environment.systemPackages = with pkgs; [
        ardour
      ];
    }
    {
      # synths/VSTs
      environment.systemPackages = with pkgs; [
        helm
      ];
    }
  ];

  # TODO: things to look into for music production:
  # - https://linuxmusicians.com/viewtopic.php?t=27016
  # - KXStudio?
  # - falktx (https://github.com/DISTRHO/Cardinal)
  # -
}
