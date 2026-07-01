{ config, pkgs, ... }:
let
  dataDir = "/storage/k3s";

  # Pin the bundled traefik to a loopback NodePort instead of its default
  # LoadBalancer:
  #   - service.type NodePort (with ServiceLB gone a LoadBalancer would be inert
  #     anyway, but we make NodePort explicit so the intent lives in our repo);
  #   - the web (:80) entrypoint maps to NodePort 30081 — caddy proxies *.k here
  #     (30080 is taken by a pre-existing default/echo-server test service);
  #   - the websecure (:443) entrypoint is NOT exposed, because caddy terminates
  #     TLS at the edge and forwards plain HTTP to traefik.
  traefikNodePortManifest = pkgs.writeText "traefik-nodeport.yaml" ''
    apiVersion: helm.cattle.io/v1
    kind: HelmChartConfig
    metadata:
      name: traefik
      namespace: kube-system
    spec:
      valuesContent: |-
        service:
          type: NodePort
        ports:
          web:
            nodePort: 30081
          websecure:
            expose:
              default: false
  '';
in
{
  k3s = {
    enable = true;
    role = "server";
    clusterInit = true;
    inherit dataDir;

    # Traefik IS our in-cluster ingress controller — but it is constrained to a
    # loopback-only NodePort (see the manifest below), NEVER a LoadBalancer. caddy
    # remains the sole edge on :80/:443; it reverse-proxies *.k.lyte.dev → traefik.
    # New cluster apps then need only an Ingress resource.
    disableTraefik = false;

    # Cluster-wide PodSecurity admission default. `baseline` enforce rejects the
    # obviously-dangerous pod shapes (privileged, hostNetwork, hostPath, host
    # namespaces) on admission for every namespace that doesn't set its own
    # pod-security.kubernetes.io/* labels; warn/audit are `restricted` so a
    # stricter future is visible without rejecting today. kube-system stays
    # exempt (traefik / metrics-server / local-path / helm-install need it).
    # NOTE: PSA only gates *newly admitted* pods — already-running pods (e.g. the
    # stale default/echo-server) are untouched until they restart.
    podSecurity.enable = true;

    tokenFile = config.sops.secrets.k3s-token.path;
    openFirewall = true;
    extraFlags = [
      "--tls-san=beefcake"
      "--tls-san=beefcake.lan"
      # Reachable over the tailnet (where :6443 is firewall-open — the API is NOT
      # exposed on the LAN) so dragon, the admin/workhost, can run kubectl against
      # the cluster. The API server cert's default SANs cover beefcake/beefcake.lan
      # /192.168.0.9 but not the VPN hostname or tailnet IP that dragon connects to.
      "--tls-san=beefcake.internal.vpn.h.lyte.dev"
      "--tls-san=100.64.0.2"

      # --- Strict edge/ingress separation (the 2026-06 outage guard) ---
      # Disabling ServiceLB removes the ONLY mechanism that fulfills LoadBalancer
      # services by binding host ports. Without it, ANY LoadBalancer service (even
      # the bundled traefik's default, or one created by accident) just sits
      # <pending> forever and can never seize :80/:443. This is what structurally
      # prevents a repeat of the traefik-LoadBalancer outage — the capability to
      # bind host ports simply does not exist in the cluster.
      "--disable=servicelb"

      # Bind ALL NodePorts to loopback only, so the in-cluster ingress (and any
      # NodePort service) is reachable EXCLUSIVELY via caddy proxying from the
      # host — never from the LAN.
      "--kube-proxy-arg=nodeport-addresses=127.0.0.0/8"
    ];
  };

  # --- NetworkPolicy ---------------------------------------------------------
  # k3s DOES enforce Kubernetes NetworkPolicy out of the box: it embeds
  # kube-router's netpol controller (only the netpol library — not kube-router's
  # CNI) alongside flannel, active unless --disable-network-policy is passed
  # (we do not pass it). So default-deny netpols are REAL here, not a no-op.
  #   https://docs.k3s.io/networking/networking-services#network-policy-controller
  #
  # A NetworkPolicy is namespaced and there is no cluster-wide "default deny", so
  # the pattern is applied PER app-namespace as workloads migrate in (see
  # lib/doc/k8s-networkpolicy-template.yaml and lib/doc/podman-to-k8s-migration.md).
  # We deliberately do NOT auto-deploy a blanket default-deny here: dropping one
  # into kube-system would sever coredns/traefik, and the `default` namespace's
  # only occupant is the stale echo-server. Each migrated app carries its own
  # default-deny-ingress + explicit allow-from-traefik + allow-DNS, dropped into
  # <dataDir>/server/manifests via the same tmpfiles mechanism used below.
  #
  # k3s reads auto-deploy manifests from <dataDir>/server/manifests. The NixOS
  # services.k3s.manifests option hardcodes /var/lib/rancher/k3s/server/manifests,
  # which our custom --data-dir bypasses — so k3s never saw the override there.
  # Drop it into the REAL dir ourselves. k3s watches this directory, so the
  # HelmChartConfig is applied to the bundled traefik chart whether it lands
  # before or after the chart installs.
  systemd.tmpfiles.rules = [
    "d ${dataDir}/server 0700 root root -"
    "d ${dataDir}/server/manifests 0700 root root -"
    "L+ ${dataDir}/server/manifests/traefik-nodeport.yaml - - - - ${traefikNodePortManifest}"
  ];

  systemd.tmpfiles.settings."10-k3s" = {
    "/storage/k3s" = {
      d = {
        mode = "0700";
        user = "root";
        group = "root";
      };
    };
  };

  sops.secrets.k3s-token.mode = "0400";
}
