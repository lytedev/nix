{ config, lib, ... }:
{
  # Note on microphone automatic gain control (AGC):
  # This config does NOT load libpipewire-module-echo-cancel or any AGC/WebRTC
  # processing module, so AGC is never applied at the system/PipeWire level. If a
  # mic sounds like its gain is being auto-adjusted, the culprit is the consuming
  # application: browsers and Electron apps (Firefox, Chromium, Slack, Discord,
  # video-call sites) request `autoGainControl: true` via getUserMedia by default
  # and run the WebRTC Audio Processing Module in software on the captured stream.
  # Disable per-app:
  #   - Firefox: about:config -> media.getusermedia.agc_enabled = false
  #     (also noise_enabled / aec_enabled for noise suppression / echo cancel)
  #   - Chromium/Slack/Electron: chrome://flags WebRTC audio processing, or launch
  #     with --disable-features=WebRtcAllowInputVolumeAdjustment
  config = lib.mkIf config.services.pipewire.enable {
    services.pipewire = {
      # enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      jack.enable = true;
      # wireplumber.enable = true; # this is default now
      wireplumber.extraConfig = {
        "monitor.bluez.properties" = {
          "bluez5.enable-sbc-xq" = true;
          "bluez5.enable-msbc" = true;
          "bluez5.enable-hw-volume" = true;
          "bluez5.codecs" = [
            "ldac"
            "aptx_hd"
            "aptx"
            "aac"
            "sbc_xq"
            "sbc"
          ];
          "bluez5.roles" = [
            "hsp_hs"
            "hsp_ag"
            "hfp_hf"
            "hfp_ag"
          ];
        };
        # Disable automatic profile switching
        "50-disable-autoswitch" = {
          "wireplumber.settings" = {
            "bluetooth.autoswitch-to-headset-profile" = false;
          };
        };
      };
      extraConfig.pipewire."91-null-sinks" = {
        "context.objects" = [
          {
            # A default dummy driver. This handles nodes marked with the "node.always-driver"
            # properyty when no other driver is currently active. JACK clients need this.
            factory = "spa-node-factory";
            args = {
              "factory.name" = "support.node.driver";
              "node.name" = "Dummy-Driver";
              "priority.driver" = 8000;
            };
          }
          {
            factory = "adapter";
            args = {
              "factory.name" = "support.null-audio-sink";
              "node.name" = "Microphone-Proxy";
              "node.description" = "Microphone";
              "media.class" = "Audio/Source/Virtual";
              "audio.position" = "MONO";
            };
          }
          {
            factory = "adapter";
            args = {
              "factory.name" = "support.null-audio-sink";
              "node.name" = "Main-Output-Proxy";
              "node.description" = "Main Output";
              "media.class" = "Audio/Sink";
              "audio.position" = "FL,FR";
            };
          }
        ];
      };
      /*
        extraConfig.pipewire."92-low-latency" = {
        context.properties = {
        default.clock.rate = 48000;
        default.clock.quantum = 32;
        default.clock.min-quantum = 32;
        default.clock.max-quantum = 32;
        };
        };
      */
    };

    # recommended by https://nixos.wiki/wiki/PipeWire
    security.rtkit.enable = true;

    /*
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
          enable = false;
          support32Bit = true;
        };
      };

      security = {
        # I forget why I need these exactly...
        polkit.enable = true;

        rtkit.enable = true;
      };
    */
  };
}
