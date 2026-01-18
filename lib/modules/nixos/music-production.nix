# Music Production NixOS Module
#
# USAGE TIPS:
# ===========
# 1. Use Carla as a plugin host to load VST/LV2 plugins and route them together
# 2. Use Helvum or qpwgraph as a PipeWire patchbay to connect audio sources/sinks
# 3. For guitar:
#    - Start with Guitarix for quick amp tones and effects
#    - Explore Neural Amp Modeler (NAM) for realistic amp models
#    - Download NAM models from https://tonehunt.org
# 4. For Windows VSTs:
#    - Install VSTs in Wine (e.g., ~/.wine/drive_c/Program Files/VSTPlugins/)
#    - Run `yabridgectl add ~/.wine/drive_c/Program\ Files/VSTPlugins/`
#    - Run `yabridgectl sync` to create Linux bridges
# 5. Reaper is recommended as the main DAW - lightweight, professional, highly customizable
# 6. For low latency: ensure your user is in the 'audio' group
# 7. Use JACK (enabled via PipeWire) for professional audio routing between apps
#
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.lyte.desktop.music-production;
in
{
  options.lyte.desktop.music-production = {
    enable = lib.mkEnableOption "music production tools and configuration";
    users = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Users to add to the audio group for realtime scheduling";
    };
  };

  config = lib.mkIf cfg.enable {
    # Add specified users to audio group for realtime scheduling
    users.users = lib.genAttrs cfg.users (user: {
      extraGroups = [ "audio" ];
    });
    # Ensure pipewire with JACK is enabled (required for pro audio)
    services.pipewire = {
      enable = true;
      jack.enable = true;
    };

    # Low-latency audio configuration
    security.rtkit.enable = true;

    # Allow users in audio group to use realtime scheduling
    security.pam.loginLimits = [
      {
        domain = "@audio";
        item = "memlock";
        type = "-";
        value = "unlimited";
      }
      {
        domain = "@audio";
        item = "rtprio";
        type = "-";
        value = "99";
      }
      {
        domain = "@audio";
        item = "nofile";
        type = "soft";
        value = "99999";
      }
      {
        domain = "@audio";
        item = "nofile";
        type = "hard";
        value = "99999";
      }
    ];

    environment.systemPackages = with pkgs; [
      # === DAWs ===
      reaper # Professional DAW (user mentioned)
      ardour # Open source DAW alternative
      lmms # Lighter weight, good for electronic music

      # === Synthesizers & Instruments ===
      helm # Polyphonic synth (user mentioned)
      surge-XT # Powerful open source hybrid synth
      vital # Wavetable synth
      zynaddsubfx # Classic software synth
      bristol # Vintage keyboard emulator
      yoshimi # Fork of ZynAddSubFX

      # === Effects & Plugins (LV2) ===
      lsp-plugins # Comprehensive plugin suite
      calf # Another great plugin suite
      x42-plugins # Professional meters, EQ, etc.
      dragonfly-reverb # Quality reverb plugins
      chow-tape-model # Tape emulation
      aether-lv2 # Algorithmic reverb
      distrho-ports # Collection of plugins (DISTRHO Ports)
      eq10q # Parametric EQ
      noise-repellent # Noise reduction
      zam-plugins # Dynamics and EQ plugins

      # === Guitar-specific ===
      guitarix # Amp simulation and effects
      gxplugins-lv2 # More guitarix plugins as LV2
      neural-amp-modeler-lv2 # NAM - neural network amp models

      # === Plugin Hosts & Routing ===
      carla # Versatile plugin host (VST, LV2, etc.)
      helvum # Patchbay for PipeWire
      qpwgraph # Another PipeWire patchbay (Qt-based)

      # === Audio Utilities ===
      audacity # Quick audio editing
      sonic-visualiser # Audio analysis and visualization
      ardour # Also useful for editing/mixing

      # === MIDI Tools ===
      qsynth # FluidSynth GUI (for SoundFonts)
      fluidsynth # SoundFont synthesizer
      vmpk # Virtual MIDI piano keyboard

      # === Windows VST Support ===
      yabridge # Run Windows VSTs via Wine
      yabridgectl # yabridge configuration tool
    ];

    # Ensure user is in audio group for realtime scheduling
    # Note: You may need to add your user to the audio group manually or via your user config
  };
}
