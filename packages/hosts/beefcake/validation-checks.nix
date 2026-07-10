# beefcake's per-service smoke checks (lyte.validation.checks). Run inside a
# blue/green VALIDATION slot (against cloned state, egress-cut) to gate a
# cutover — and as a post-cutover health probe. Each check is gated on its
# service actually being enabled, so this file is safe on bare-metal beefcake
# too (harmless: it only adds the runner; the cutover tool invokes it).
#
# Philosophy: cheap FUNCTIONAL probes where they exist (DNS resolves, HTTPS
# answers), is-active elsewhere. A red check BLOCKS the cutover — better a
# candidate rejected than a bad generation taking the service IP.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  svc = n: config.services.${n}.enable or false;
  active = unit: "systemctl is-active --quiet ${unit}";
in
{
  lyte.validation.checks = lib.mkMerge [
    # --- infra invariants: the guest-shape must actually be intact ---
    {
      system-running = {
        description = "systemd reached running/degraded (not still starting/failed-hard)";
        command = "systemctl is-system-running | grep -qE 'running|degraded'";
      };
      persist-shared-pool = {
        description = "/persist is the shared bpersist pool (identity+state present)";
        command = "findmnt -n -o SOURCE /persist | grep -qx bpersist/persist";
      };
      storage-virtiofs = {
        description = "/storage mounted via virtiofs + readable (Model B share)";
        command = "findmnt -n -o FSTYPE /storage | grep -qx virtiofs && ls /storage >/dev/null";
      };
      nix-overlay = {
        description = "/nix/store is the overlay (base + slot upper)";
        command = "findmnt -n -o FSTYPE /nix/store | tail -n1 | grep -qx overlay";
      };
    }
    # --- functional service probes (gated on the service existing) ---
    (lib.mkIf (svc "knot") {
      dns = {
        description = "knot answers the lyte.dev SOA locally";
        command = "${pkgs.knot-dns}/bin/kdig +short +timeout=3 @127.0.0.1 lyte.dev SOA | grep -q .";
      };
    })
    (lib.mkIf (svc "caddy") {
      web-edge = {
        description = "caddy TLS edge answers on :443";
        command = "curl -skf -o /dev/null --max-time 8 --resolve git.lyte.dev:443:127.0.0.1 https://git.lyte.dev/ || curl -skf -o /dev/null --max-time 8 https://127.0.0.1/";
      };
    })
    (lib.mkIf (svc "forgejo") {
      forgejo = {
        description = "forgejo git service active";
        command = active "forgejo.service";
      };
    })
    (lib.mkIf (svc "vaultwarden") {
      vaultwarden = {
        description = "vaultwarden active";
        command = active "vaultwarden.service";
      };
    })
    (lib.mkIf (svc "postgresql") {
      postgres = {
        description = "postgres accepting connections";
        command = "${lib.getExe' config.services.postgresql.package "pg_isready"} -q";
      };
    })
    (lib.mkIf (svc "stalwart-mail") {
      mail = {
        description = "stalwart mail server active";
        command = active "stalwart-mail.service";
      };
    })
    (lib.mkIf (svc "headscale") {
      vpn = {
        description = "headscale coordinator active";
        command = active "headscale.service";
      };
    })
    (lib.mkIf (svc "k3s") {
      k3s = {
        description = "k3s node active";
        command = active "k3s.service";
      };
    })
  ];
}
