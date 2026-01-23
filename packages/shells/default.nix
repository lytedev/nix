{ self, ... }:
{ pkgs, ... }:
let
  unfreePkgs = import pkgs.path {
    system = pkgs.stdenv.hostPlatform.system;
    config.allowUnfree = true;
  };

  # Thin wrappers around npx for agent tools
  # These always run the latest version via npx instead of packaging
  claude-code = pkgs.writeShellApplication {
    name = "claude";
    runtimeInputs = [ pkgs.nodejs ];
    text = ''
      exec npx -y @anthropic-ai/claude-code "$@"
    '';
  };

  happy-coder = pkgs.writeShellApplication {
    name = "happy";
    runtimeInputs = [ pkgs.nodejs ];
    text = ''
      exec npx -y happy-coder "$@"
    '';
  };

  codex = pkgs.writeShellApplication {
    name = "codex";
    runtimeInputs = [ pkgs.nodejs ];
    text = ''
      exec npx -y @openai/codex "$@"
    '';
  };
in
{
  default = pkgs.mkShell {
    inherit (self.outputs.checks.${pkgs.stdenv.hostPlatform.system}.git-hooks) shellHook;
    packages = with pkgs; [
      deploy-rs
      sops
      nil
      nixd
      nixfmt-rfc-style
      lua-language-server
      nodePackages.bash-language-server
      markdown-oxide
      tea
    ];
  };

  agent = pkgs.mkShell {
    packages = [
      claude-code
      happy-coder
      codex
      pkgs.opencode
    ];
    shellHook = ''
      # happy-coder looks for claude at ~/.local/bin/claude (not in PATH)
      mkdir -p ~/.local/bin
      ln -sf "$(which claude)" ~/.local/bin/claude

      # Use self-hosted happy server
      export HAPPY_SERVER_URL="https://happy.h.lyte.dev"
    '';
  };

  # Music Production Development Shell
  #
  # Enter with: nix develop .#music-production
  #
  # This provides all music production tools without system-wide installation.
  # For permanent installation, use the NixOS module (d.music-production.enable)
  # or home-manager module (lyte.music-production.enable).
  #
  # Deno Deploy Development Shell
  #
  # Enter with: nix develop .#deno-deploy
  #
  # For working on Deno Deploy services (e.g., netlify-ddns)
  deno-deploy = pkgs.mkShell {
    shellHook = ''
      command -v deployctl || deno install -gArf jsr:@deno/deployctl
      export PATH="$HOME/.deno/bin:$PATH"
    '';

    DENO_FUTURE = "1";

    packages = with pkgs; [
      deno
      cue
      sops
      curl
      xh
    ];
  };

  music-production = pkgs.mkShell {
    packages = with unfreePkgs; [
      # === DAWs ===
      reaper # Professional DAW - lightweight, extremely capable, highly customizable
      ardour # Open source alternative - great for recording and mixing
      lmms # Good for electronic music and beats

      # === Synthesizers ===
      helm # Polyphonic synth - great starting point
      surge-XT # Powerful hybrid synth - lots of presets
      vital # Modern wavetable synth
      zynaddsubfx # Classic software synth

      # === Effects & Plugins (LV2) ===
      lsp-plugins # Comprehensive suite (EQ, compressors, etc.)
      calf # Another great suite
      x42-plugins # Professional meters and EQ
      dragonfly-reverb # Quality algorithmic reverbs
      chow-tape-model # Tape saturation emulation
      zam-plugins # Dynamics and EQ

      # === Guitar ===
      guitarix # Amp simulation - quick tones and effects
      gxplugins-lv2 # More guitarix plugins as LV2
      neural-amp-modeler-lv2 # NAM - neural network amp models (realistic tones)

      # === Plugin Hosts & Routing ===
      carla # Versatile plugin host - load VST/LV2 and chain effects
      helvum # PipeWire patchbay (GTK) - connect audio sources/sinks
      qpwgraph # PipeWire patchbay (Qt) - alternative to helvum

      # === Utilities ===
      audacity # Quick audio editing and recording
      sonic-visualiser # Audio analysis and visualization
      qsynth # FluidSynth GUI for SoundFonts
      fluidsynth # SoundFont synthesizer
      vmpk # Virtual MIDI piano keyboard

      # === Windows VST Support ===
      yabridge # Bridge to run Windows VSTs
      yabridgectl # yabridge configuration tool
    ];

    shellHook = ''
      echo "╔═══════════════════════════════════════════════════════════════════╗"
      echo "║              Music Production Environment                         ║"
      echo "╚═══════════════════════════════════════════════════════════════════╝"
      echo ""
      echo "QUICK START:"
      echo "  reaper          - Main DAW (recommended)"
      echo "  carla           - Plugin host (load VST/LV2, chain effects)"
      echo "  helvum          - Audio routing (connect apps together)"
      echo ""
      echo "INSTRUMENTS:"
      echo "  helm            - Polyphonic synth"
      echo "  surge-xt        - Hybrid synth with tons of presets"
      echo "  vital           - Wavetable synth"
      echo ""
      echo "GUITAR:"
      echo "  guitarix        - Amp simulation (quick tones)"
      echo "  NAM models      - Download from https://tonehunt.org"
      echo ""
      echo "WINDOWS VSTs:"
      echo "  1. Install VSTs in Wine (~/.wine/drive_c/Program Files/VSTPlugins/)"
      echo "  2. yabridgectl add <path-to-vst-folder>"
      echo "  3. yabridgectl sync"
      echo ""
      echo "TIP: Use Carla to host plugins, route with helvum/qpwgraph"
      echo ""
    '';
  };
}
