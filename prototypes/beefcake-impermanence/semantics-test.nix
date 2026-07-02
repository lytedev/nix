# P1a — impermanence semantics on an ephemeral root.
#
# The VM has NO root disk image (tmpfs root), so every boot is a "wiped root"
# by construction — a stand-in for the ZFS blank-snapshot rollback whose real
# initrd mechanics are proven separately by rollback-demo. What this test
# proves is the part that actually bites in production:
#   - /persist (separate disk, neededForBoot) carries everything durable
#   - sops-nix decrypts on a fresh root with NO manual intervention, because
#     its age identity lives under /persist (beefcake analogue: the persisted
#     ssh host key)
#   - ssh host identity is stable across wipes
#   - postgres survives (dataDir under a persisted directory)
#   - DynamicUser/StateDirectory state under /var/lib/private survives (the
#     June relocation's clientele)
#   - /etc/machine-id is stable
#   - and root really IS ephemeral (a marker file vanishes)
{
  pkgs,
  impermanence,
  sops-nix,
}:
pkgs.testers.runNixOSTest {
  name = "beefcake-impermanence-semantics";

  nodes.machine =
    { config, lib, ... }:
    {
      imports = [
        impermanence.nixosModules.impermanence
        sops-nix.nixosModules.sops
      ];

      boot.initrd.systemd.enable = true;

      # No root disk image → tmpfs root, fresh every boot.
      virtualisation.diskImage = null;

      # One extra disk plays zstorage/state.
      virtualisation.emptyDiskImages = [ 1024 ];
      virtualisation.fileSystems."/persist" = {
        device = "/dev/vda";
        fsType = "ext4";
        autoFormat = true;
        neededForBoot = true;
      };

      environment.persistence."/persist" = {
        hideMounts = true;
        directories = [
          "/var/lib/nixos"
          "/var/lib/postgresql"
          {
            directory = "/var/lib/private";
            mode = "0700";
          }
          "/var/log"
        ];
        files = [ "/etc/machine-id" ];
      };

      services.openssh = {
        enable = true;
        # Not a bind of /etc/ssh — the keys live at their persisted path and
        # sshd generates them there on first boot (beefcake keeps its existing
        # keys by copying them in once).
        hostKeys = [
          {
            path = "/persist/etc/ssh/ssh_host_ed25519_key";
            type = "ed25519";
          }
        ];
      };

      sops = {
        defaultSopsFile = ./keys/secrets.test.yml;
        age.keyFile = "/persist/age/keys.txt";
        secrets.test-secret = { };
      };

      services.postgresql.enable = true;

      # Guinea pig for /var/lib/private (DynamicUser) state.
      systemd.services.proto-state = {
        description = "DynamicUser StateDirectory guinea pig";
        serviceConfig = {
          Type = "oneshot";
          DynamicUser = true;
          StateDirectory = "proto-state";
        };
        script = ''
          echo "tick" >> "$STATE_DIRECTORY/log"
        '';
      };
    };

  testScript = ''
    machine.start()
    machine.wait_for_unit("multi-user.target")

    # ---- first boot: seed identity + state ----
    # Seed the age key into /persist (production analogue: the ssh host key
    # already lives there). sops-nix already ran without it, so re-run
    # activation to decrypt.
    machine.succeed("mkdir -p /persist/age")
    machine.succeed(
        "cp ${./keys/age-test-key.txt} /persist/age/keys.txt"
    )
    machine.succeed("/run/current-system/activate")
    machine.succeed("grep -q hello-from-sops /run/secrets/test-secret")

    machine.wait_for_unit("postgresql.service")
    machine.succeed(
        "sudo -u postgres psql -c 'CREATE TABLE t (x int); INSERT INTO t VALUES (42);'"
    )

    machine.succeed("systemctl start proto-state.service")
    machine.succeed("test -f /var/lib/private/proto-state/log")

    machine.succeed("touch /root/ephemeral-marker")

    machine_id_1 = machine.succeed("cat /etc/machine-id").strip()
    hostkey_1 = machine.succeed(
        "ssh-keygen -lf /persist/etc/ssh/ssh_host_ed25519_key.pub"
    ).strip()

    machine.shutdown()

    # ---- second boot: root is a fresh tmpfs ----
    machine.start()
    machine.wait_for_unit("multi-user.target")

    # Root really was wiped.
    machine.fail("test -e /root/ephemeral-marker")

    # sops decrypted with NO manual step → ordering (persist mount before
    # secret setup) holds on a wiped root.
    machine.wait_for_file("/run/secrets/test-secret")
    machine.succeed("grep -q hello-from-sops /run/secrets/test-secret")

    # postgres state survived.
    machine.wait_for_unit("postgresql.service")
    out = machine.succeed("sudo -u postgres psql -tAc 'SELECT x FROM t;'").strip()
    assert out == "42", f"postgres state lost: {out!r}"

    # DynamicUser state survived and appends.
    machine.succeed("systemctl start proto-state.service")
    lines = int(machine.succeed("wc -l < /var/lib/private/proto-state/log").strip())
    assert lines == 2, f"expected 2 ticks in DynamicUser state, got {lines}"

    # Identity stable.
    machine_id_2 = machine.succeed("cat /etc/machine-id").strip()
    assert machine_id_1 == machine_id_2, (
        f"machine-id changed: {machine_id_1} -> {machine_id_2}"
    )
    hostkey_2 = machine.succeed(
        "ssh-keygen -lf /persist/etc/ssh/ssh_host_ed25519_key.pub"
    ).strip()
    assert hostkey_1 == hostkey_2, "ssh host key changed across wipe"

    print("PASS: impermanence semantics hold across a root wipe")
  '';
}
