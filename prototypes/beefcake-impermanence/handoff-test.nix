# P2 — blue/green disk-set handoff.
#
# Two guests ("blue" = running generation, "green" = candidate) sequentially
# own a shared raw disk carrying a ZFS pool — the stand-in for handing
# beefcake's 12 zstorage disks between VM slots via virtio-blk. Proves:
#   - clean cutover: blue exports the pool + powers off, green imports it and
#     serves the same postgres data (state continuity)
#   - green can also boot with NO pool attached (the "validation boot" mode)
#   - rollback: green exports, blue boots again and sees green's writes
#
# Both guests share hostId (as blue/green beefcake slots would), so plain
# `zpool import` works after a clean export on either side.
{ pkgs }:
let
  poolDisk = "../shared0.img"; # resolved against qemu's cwd = vm-state-<name>

  common =
    { lib, ... }:
    {
      boot.supportedFilesystems = [ "zfs" ];
      networking.hostId = "541ede55";

      virtualisation.qemu.options = [
        "-drive if=virtio,format=raw,werror=report,file=${poolDisk}"
      ];

      # postgres lives ON the handed-off pool; started manually once the pool
      # is imported (production: the cutover tool orders this). The condition
      # makes boot-time auto-start (via postgresql.target) skip harmlessly
      # while the pool is absent instead of crash-looping into the start
      # limit — mount namespacing fails hard on a missing ReadWritePaths dir.
      services.postgresql = {
        enable = true;
        dataDir = "/tank/pg";
      };
      systemd.services.postgresql.unitConfig.ConditionPathExists = "/tank/pg";
    };
in
pkgs.testers.runNixOSTest {
  name = "beefcake-blue-green-handoff";

  nodes = {
    blue =
      { ... }:
      {
        imports = [ common ];
        environment.etc."slot".text = "blue";
      };
    green =
      { ... }:
      {
        imports = [ common ];
        environment.etc."slot".text = "green";
      };
  };

  testScript = ''
    import subprocess

    # The shared "physical" disk set (zstorage stand-in), created before any
    # guest starts. 2 GiB sparse raw file in the driver tmpdir.
    shared = blue.state_dir.parent / "shared0.img"
    subprocess.run(
        ["${pkgs.qemu_test}/bin/qemu-img", "create", "-f", "raw", str(shared), "2G"],
        check=True,
    )

    # ---- green validation boot: candidate boots fine with NO pool ----
    # (green sees the disk device but no pool on it yet — close enough to the
    # production validation slot, which gets no service disks at all)
    green.start()
    green.wait_for_unit("multi-user.target")
    assert green.succeed("cat /etc/slot").strip() == "green"
    green.fail("zpool list tank")
    green.shutdown()

    # ---- blue owns the pool and accumulates state ----
    blue.start()
    blue.wait_for_unit("multi-user.target")
    blue.succeed("zpool create tank /dev/vdb")
    blue.succeed("zfs create tank/pg")
    blue.succeed("mkdir -p /tank/pg && chown -R postgres:postgres /tank/pg && chmod 700 /tank/pg")
    blue.succeed("systemctl start postgresql.service")
    blue.wait_for_unit("postgresql.service")
    blue.succeed(
        "sudo -u postgres psql -c \"CREATE TABLE cutover (writer text); INSERT INTO cutover VALUES ('blue');\""
    )

    # ---- cutover: blue releases cleanly, green takes over ----
    blue.succeed("systemctl stop postgresql.service")
    blue.succeed("zpool export tank")
    blue.shutdown()

    green.start()
    green.wait_for_unit("multi-user.target")
    green.succeed("zpool import tank")
    green.succeed("systemctl start postgresql.service")
    green.wait_for_unit("postgresql.service")
    writers = green.succeed("sudo -u postgres psql -tAc 'SELECT writer FROM cutover;'")
    assert "blue" in writers, f"green lost blue's state: {writers!r}"
    green.succeed(
        "sudo -u postgres psql -c \"INSERT INTO cutover VALUES ('green');\""
    )

    # ---- rollback: green releases, blue resumes with ALL state ----
    green.succeed("systemctl stop postgresql.service")
    green.succeed("zpool export tank")
    green.shutdown()

    blue.start()
    blue.wait_for_unit("multi-user.target")
    blue.succeed("zpool import tank")
    blue.succeed("systemctl start postgresql.service")
    blue.wait_for_unit("postgresql.service")
    writers = blue.succeed("sudo -u postgres psql -tAc 'SELECT writer FROM cutover;'")
    assert "blue" in writers and "green" in writers, (
        f"rollback lost state: {writers!r}"
    )

    print("PASS: pool handoff blue -> green -> blue with state continuity")
  '';
}
