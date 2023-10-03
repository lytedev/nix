{...}: {
  services.pipewire = {
    enable = true;

    wireplumber.enable = true;
    pulse.enable = true;
    jack.enable = true;

    alsa = {
      enable = true;
      support32Bit = true;
    };
  };

  hardware = {
    pulseaudio = {
      support32Bit = true;
    };
  };

  security = {
    # I forget why I need these...
    polkit.enable = true;
    rtkit.enable = true;
  };
}
