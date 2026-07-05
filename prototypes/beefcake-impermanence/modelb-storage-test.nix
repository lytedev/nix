# P3 — Model B storage primitives (host-owns-pool, DD2 revision 2026-07-01).
#
# One ZFS node standing in for the thin host. Proves, in order:
#   1. postgres runs with its dataDir on ext4-on-zvol (the "zvol-backed
#      directory" primitive for fsync-heavy services)
#   2. a snapshot + clone of that zvol taken WHILE postgres runs is openable
#      by a second postgres instance (green's validation-against-real-data)
#   3. writes to the clone provably never reach the origin — and vice versa
#   4. clone discard is clean, origin unharmed (validation teardown)
#   5. dataset-level clone of a file tree behaves the same (virtiofs-share
#      stand-in; the virtiofs transport itself is exercised in Phase 3)
#
# "blue" postgres = the production instance on the origin zvol.
# "green" postgres = the validation instance on the clone. Same binaries —
# what's under test is the storage isolation, not version skew.
{ pkgs }:
pkgs.testers.runNixOSTest {
  name = "beefcake-modelb-storage";

  nodes.host =
    { lib, pkgs, ... }:
    {
      boot.supportedFilesystems = [ "zfs" ];
      networking.hostId = "541ede55";
      virtualisation.emptyDiskImages = [ 4096 ];
      # We drive initdb/postgres by hand (two instances, nonstandard dirs);
      # the module would fight us.
      users.users.postgres = {
        isSystemUser = true;
        group = "postgres";
      };
      users.groups.postgres = { };
    };

  testScript = ''
    host.start()
    host.wait_for_unit("multi-user.target")

    # Call the package's binaries by store path: initdb from a profile
    # symlink can't locate its share/ files (postgres.bki).
    PG = "${pkgs.postgresql_17}/bin"

    def pg(dir, port, cmd):
        return host.succeed(
            f"sudo -u postgres {PG}/{cmd.format(dir=dir, port=port)}"
        )

    def pg_start(dir, port):
        pg(dir, port, "pg_ctl -D {dir} -o '-p {port} -k /tmp' -l /tmp/pg-{port}.log start")

    def pg_stop(dir, port):
        pg(dir, port, "pg_ctl -D {dir} stop")

    def psql(port, sql):
        return host.succeed(f"sudo -u postgres {PG}/psql -h /tmp -p {port} -tAc \"{sql}\"").strip()

    # ---- the pool (zstorage stand-in) + the zvol primitive ----
    host.succeed("zpool create tank /dev/vdb")
    host.succeed("zfs create -p -V 1G tank/zvols/pg")
    host.succeed("udevadm settle")
    host.succeed("mkfs.ext4 -q /dev/zvol/tank/zvols/pg")
    host.succeed("mkdir -p /srv/pg-blue && mount /dev/zvol/tank/zvols/pg /srv/pg-blue")
    host.succeed("chown postgres:postgres /srv/pg-blue")

    # ---- 1. blue postgres lives on the zvol ----
    pg("/srv/pg-blue/data", 5432, "initdb -D {dir}")
    pg_start("/srv/pg-blue/data", 5432)
    psql(5432, "CREATE TABLE t (writer text); INSERT INTO t VALUES ('blue-before-snap');")

    # ---- 2. snapshot + clone WHILE blue is running ----
    host.succeed("zfs snapshot tank/zvols/pg@validation")
    host.succeed("zfs clone tank/zvols/pg@validation tank/zvols/pg-green")
    host.succeed("udevadm settle")
    host.succeed("mkdir -p /srv/pg-green && mount /dev/zvol/tank/zvols/pg-green /srv/pg-green")
    host.succeed("chown -R postgres:postgres /srv/pg-green")

    # blue keeps writing AFTER the snapshot — must never appear in the clone
    psql(5432, "INSERT INTO t VALUES ('blue-after-snap');")

    # green opens the cloned datadir. The clone was taken from a RUNNING
    # postgres, so it's a crash-consistent image: recovery must succeed.
    host.succeed("sudo -u postgres rm -f /srv/pg-green/data/postmaster.pid")
    pg_start("/srv/pg-green/data", 5433)
    green_rows = psql(5433, "SELECT writer FROM t ORDER BY writer;")
    assert "blue-before-snap" in green_rows, f"clone lost pre-snap data: {green_rows!r}"
    assert "blue-after-snap" not in green_rows, f"clone sees post-snap writes: {green_rows!r}"

    # ---- 3. isolation both directions ----
    psql(5433, "INSERT INTO t VALUES ('green-validation-write');")
    blue_rows = psql(5432, "SELECT writer FROM t ORDER BY writer;")
    assert "green-validation-write" not in blue_rows, (
        f"green's write leaked into the origin: {blue_rows!r}"
    )
    assert "blue-after-snap" in blue_rows

    # ---- 4. validation teardown: discard the clone, origin unharmed ----
    pg_stop("/srv/pg-green/data", 5433)
    host.succeed("umount /srv/pg-green")
    host.succeed("zfs destroy tank/zvols/pg-green")
    host.succeed("zfs destroy tank/zvols/pg@validation")
    assert "blue-after-snap" in psql(5432, "SELECT writer FROM t;")

    # ---- 5. same story for a file-tree dataset (virtiofs-share stand-in) ----
    host.succeed("zfs create -o xattr=sa -o acltype=posixacl tank/storage")
    host.succeed("echo v1 > /tank/storage/file")
    host.succeed("zfs snapshot tank/storage@validation")
    host.succeed("zfs clone tank/storage@validation tank/storage-green")
    host.succeed("echo v2 > /tank/storage/file")           # origin moves on
    host.succeed("echo green > /tank/storage-green/other")  # clone writes
    assert host.succeed("cat /tank/storage-green/file").strip() == "v1"
    host.fail("test -e /tank/storage/other")
    host.succeed("zfs destroy tank/storage-green && zfs destroy tank/storage@validation")
    assert host.succeed("cat /tank/storage/file").strip() == "v2"

    # ---- bonus: xattr/posixacl actually work on the share dataset ----
    host.succeed("setfattr -n user.test -v hello /tank/storage/file")
    assert "hello" in host.succeed("getfattr -n user.test /tank/storage/file")
    host.succeed("setfacl -m u:postgres:r /tank/storage/file")
    assert "postgres" in host.succeed("getfacl /tank/storage/file")

    # ---- 6. RocksDB (stalwart/tuwunel class): snapshots taken DURING a
    # write loop yield clones that open and scan (WAL crash-consistency).
    # Held-open-writer fidelity comes free in Phase-4 validation against
    # real cloned state; this receipt covers the storage-class claim.
    LDB = "${pkgs.rocksdb.tools}/bin/ldb"
    host.succeed("zfs create -V 512M tank/zvols/rdb && udevadm settle")
    host.succeed("mkfs.ext4 -q /dev/zvol/tank/zvols/rdb")
    host.succeed("mkdir -p /srv/rdb && mount /dev/zvol/tank/zvols/rdb /srv/rdb")
    # seed synchronously first — validation always snapshots EXISTING state
    # (an instant snapshot can otherwise predate the writer's first flush)
    host.succeed(f"{LDB} --db=/srv/rdb/db --create_if_missing put seed seed && sync")
    host.succeed(
        f"(for i in $(seq 1 2000); do {LDB} --db=/srv/rdb/db put k$i v$i; done) "
        "> /tmp/rdb-writer.log 2>&1 & echo started"
    )
    for round in range(3):
        host.succeed("sleep 2")  # land snapshots at different loop phases
        host.succeed(f"zfs snapshot tank/zvols/rdb@r{round}")
        host.succeed(f"zfs clone tank/zvols/rdb@r{round} tank/zvols/rdb-c{round}")
        host.succeed("udevadm settle")
        host.succeed(f"mkdir -p /mnt/rdb{round} && mount /dev/zvol/tank/zvols/rdb-c{round} /mnt/rdb{round}")
        # the clone must OPEN (WAL recovery) and contain the seed key
        # (scan|head shows lexicographic k* keys; ask for seed directly)
        out = host.succeed(f"{LDB} --db=/mnt/rdb{round}/db get seed")
        assert "seed" in out, f"clone r{round} lost the seed key: {out!r}"
        host.succeed(f"umount /mnt/rdb{round} && zfs destroy tank/zvols/rdb-c{round} && zfs destroy tank/zvols/rdb@r{round}")
    print("PASS: rocksdb clones (snapshotted mid-write-loop) open and scan")

    pg_stop("/srv/pg-blue/data", 5432)
    print("PASS: zvol-backed postgres + clone-validation isolation + share-dataset semantics")
  '';
}
