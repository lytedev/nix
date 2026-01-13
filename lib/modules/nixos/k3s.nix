{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.k3s;
in
{
  options.k3s = {
    enable = lib.mkEnableOption "k3s lightweight Kubernetes";

    role = lib.mkOption {
      type = lib.types.enum [
        "server"
        "agent"
      ];
      default = "server";
      description = "Run as server (control plane) or agent (worker)";
    };

    clusterInit = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Initialize new cluster (first server only)";
    };

    serverAddr = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Server address to join (for agents/additional servers)";
    };

    tokenFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to cluster token file (use sops)";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/rancher/k3s";
      description = "k3s data directory";
    };

    disableTraefik = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Disable built-in Traefik (use external ingress)";
    };

    extraFlags = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Additional k3s flags";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open firewall for k3s ports (on firewallInterfaces only)";
    };

    firewallInterfaces = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "tailscale0" ];
      description = "Interfaces to open k3s ports on (default: tailscale0 only)";
    };

    multiNode = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open additional ports needed for multi-node clusters (kubelet, flannel VXLAN)";
    };
  };

  config = lib.mkIf cfg.enable {
    services.k3s = {
      enable = true;
      inherit (cfg) role clusterInit;
      serverAddr = lib.mkIf (cfg.serverAddr != null) cfg.serverAddr;
      tokenFile = lib.mkIf (cfg.tokenFile != null) cfg.tokenFile;
      extraFlags = [
        "--data-dir=${cfg.dataDir}"
      ]
      ++ lib.optional cfg.disableTraefik "--disable=traefik"
      ++ cfg.extraFlags;
    };

    # Ensure k3s starts after sops secrets are available
    systemd.services.k3s.after = [ "sops-nix.service" ];

    environment.systemPackages = with pkgs; [
      kubectl
      kubernetes-helm
      k9s
    ];

    networking.firewall = lib.mkIf cfg.openFirewall {
      # Always trust CNI interfaces for pod-to-pod traffic
      trustedInterfaces = [
        "cni0"
        "flannel.1"
      ];

      # Restrict k3s ports to specified interfaces
      interfaces = lib.genAttrs cfg.firewallInterfaces (_: {
        allowedTCPPorts = [
          6443
        ] # Kubernetes API
        ++ lib.optionals cfg.multiNode [ 10250 ]; # Kubelet (multi-node only)
        allowedUDPPorts = lib.optionals cfg.multiNode [ 8472 ]; # Flannel VXLAN (multi-node only)
      });
    };
  };
}
