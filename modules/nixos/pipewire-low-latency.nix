{...}: {
  environment.etc = {
    "pipewire/pipewire.conf.d/92-low-latency.conf".text = ''
      context.properties = {
        default.clock.rate = 48000
        default.clock.quantum = 128
        default.clock.min-quantum = 128
        default.clock.max-quantum = 128
      }

      jack.properties = {
        node.latency = 128/48000
      }
    '';
  };
}
