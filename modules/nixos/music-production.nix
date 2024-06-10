{pkgs, ...}: {
  # TODO: may want to force nixpkgs-stable for a more-stable music production
  # environment?
  imports = [
    {
      environment.systemPackages = with pkgs; [
        helvum # pipewire graph/patchbay GUI
        ardour # DAW
        helm # synth
      ];
    }
  ];

  # TODO: things to look into for music production:
  # - https://linuxmusicians.com/viewtopic.php?t=27016
  # - KXStudio?
  # - falktx (https://github.com/DISTRHO/Cardinal)
  # -
}
