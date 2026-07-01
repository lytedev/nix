{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.k3s;

  psa = cfg.podSecurity;

  # PodSecurity admission is compiled into kube-apiserver (GA since k8s 1.25).
  # By default its cluster-wide policy is `privileged` (a no-op). We hand the
  # apiserver an AdmissionConfiguration file that sets a stricter *default* for
  # every namespace that doesn't carry its own pod-security.kubernetes.io/* label.
  # This is a plain config file (NOT a k8s resource / auto-deploy manifest), so it
  # lives in the nix store and is referenced by path — the apiserver runs
  # in-process as root and reads it directly. `enforce-version: latest` pins the
  # checks to the running kube-apiserver's version.
  #   docs: https://kubernetes.io/docs/tasks/configure-pod-container/enforce-standards-admission-controller/
  psaConfigFile = pkgs.writeText "psa-admission-config.yaml" ''
    apiVersion: apiserver.config.k8s.io/v1
    kind: AdmissionConfiguration
    plugins:
      - name: PodSecurity
        configuration:
          apiVersion: pod-security.admission.config.k8s.io/v1
          kind: PodSecurityConfiguration
          defaults:
            enforce: "${psa.enforce}"
            enforce-version: "latest"
            audit: "${psa.audit}"
            audit-version: "latest"
            warn: "${psa.warn}"
            warn-version: "latest"
          exemptions:
            usernames: []
            runtimeClasses: []
            namespaces: [${lib.concatStringsSep ", " psa.exemptNamespaces}]
  '';
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

    podSecurity = {
      enable = lib.mkEnableOption ''
        cluster-wide PodSecurity admission defaults. Feeds kube-apiserver an
        AdmissionConfiguration so namespaces without their own
        pod-security.kubernetes.io/* labels inherit the levels below'';

      enforce = lib.mkOption {
        type = lib.types.enum [
          "privileged"
          "baseline"
          "restricted"
        ];
        default = "baseline";
        description = ''
          Pod Security Standard to *enforce* (reject on violation) by default.
          `baseline` blocks the obviously-dangerous (privileged, hostNetwork,
          hostPath, host namespaces, ...) while staying broadly compatible;
          `restricted` additionally demands runAsNonRoot, seccomp, dropped caps
          — stricter but breaks many stock images.
        '';
      };

      warn = lib.mkOption {
        type = lib.types.enum [
          "privileged"
          "baseline"
          "restricted"
        ];
        default = "restricted";
        description = "Standard to warn on (surfaces what would fail a stricter enforce, without rejecting).";
      };

      audit = lib.mkOption {
        type = lib.types.enum [
          "privileged"
          "baseline"
          "restricted"
        ];
        default = "restricted";
        description = "Standard to record in the audit log.";
      };

      exemptNamespaces = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ "kube-system" ];
        description = ''
          Namespaces exempt from the defaults. `kube-system` MUST stay exempt —
          traefik, metrics-server, local-path-provisioner and the helm-install
          jobs run in ways that violate baseline/restricted and would fail to
          admit on restart otherwise.
        '';
      };
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
      ++ lib.optional psa.enable "--kube-apiserver-arg=admission-control-config-file=${psaConfigFile}"
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
