{ config, ... }:
{
  k3s = {
    enable = true;
    role = "server";
    clusterInit = true;
    dataDir = "/storage/k3s";

    # Traefik IS our in-cluster ingress controller — but it is constrained to a
    # loopback-only NodePort (see services.k3s.manifests below), NEVER a
    # LoadBalancer. caddy remains the sole edge on :80/:443; it reverse-proxies
    # *.k.lyte.dev → traefik. New cluster apps then need only an Ingress resource.
    disableTraefik = false;

    tokenFile = config.sops.secrets.k3s-token.path;
    openFirewall = true;
    extraFlags = [
      "--tls-san=beefcake"
      "--tls-san=beefcake.lan"

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

  # Force the bundled traefik to a loopback NodePort instead of its default
  # LoadBalancer:
  #   - service.type NodePort (with ServiceLB gone, a LoadBalancer would be inert
  #     anyway, but we make NodePort explicit so the intent lives in our repo);
  #   - the web (:80) entrypoint maps to NodePort 30080 — caddy proxies *.k here;
  #   - the websecure (:443) entrypoint is NOT exposed, because caddy terminates
  #     TLS at the edge and forwards plain HTTP to traefik.
  # services.k3s.manifests writes this HelmChartConfig to k3s's auto-deploy
  # manifests dir; the helm-controller applies it to the bundled traefik chart.
  services.k3s.manifests.traefik-nodeport.content = [
    {
      apiVersion = "helm.cattle.io/v1";
      kind = "HelmChartConfig";
      metadata = {
        name = "traefik";
        namespace = "kube-system";
      };
      spec.valuesContent = ''
        service:
          type: NodePort
        ports:
          web:
            nodePort: 30080
          websecure:
            expose:
              default: false
      '';
    }
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
