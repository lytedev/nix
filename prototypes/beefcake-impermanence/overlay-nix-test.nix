# P-overlay (Phase 3) — prove the guest /nix OVERLAY HYBRID mechanism.
#
# The blue/green guest gets /nix as an OverlayFS: a read-only LOWER = the host's
# store (shared once via virtiofs), plus a small per-slot writable UPPER for the
# delta. The bulk is shared/deduped; each slot writes only the paths its
# generation adds. The crux is NOT the files — it's Nix's store validity DB:
# a naive overlayfs on the store dir alone desyncs it. Nix's `local-overlay://`
# store composes a lower store's DB (authoritative, read-only) with an upper
# almost-store, and VERIFIES (does not create) the OverlayFS mount.
#
# This milestone proves, in a VM, the DB layering + delta isolation:
#   - a path that exists only in the LOWER is valid in the merged store
#   - adding a NEW path to the merged store lands it in the UPPER, never touching
#     the lower, and it too is valid + readable through the merged store dir
# (Milestone 2 — booting a system whose real /nix IS this overlay — builds on a
# green mechanism here.)
{ pkgs }:
let
  # Goes into the RO lower store (stands in for the shared host store).
  lowerPkg = pkgs.hello;
  # A zero-dependency path (its closure is just itself) copied into the merged
  # store AFTER the overlay is up — must materialise in the UPPER only.
  deltaPath = pkgs.writeText "overlay-delta-marker" "this store object lives in the per-slot UPPER layer";
in
pkgs.testers.runNixOSTest {
  name = "beefcake-overlay-nix";

  nodes.machine =
    { lib, ... }:
    {
      # Room for /lower (hello's closure) + upper + the merged mount.
      virtualisation.diskSize = 6144;
      # Guarantee both paths (and their closures) exist in the VM's own store so
      # the test can copy them without any network.
      virtualisation.additionalPaths = [
        lowerPkg
        deltaPath
      ];
      nix.settings.experimental-features = [
        "nix-command"
        "flakes"
        "local-overlay-store"
      ];
      boot.kernelModules = [ "overlay" ];
    };

  testScript = ''
    import os

    machine.wait_for_unit("multi-user.target")

    lower_pkg = "${lowerPkg}"          # e.g. /nix/store/<hash>-hello
    delta     = "${deltaPath}"         # e.g. /nix/store/<hash>-overlay-delta-marker
    lower_bn  = os.path.basename(lower_pkg)
    delta_bn  = os.path.basename(delta)

    EF = "--extra-experimental-features 'nix-command local-overlay-store'"
    overlay = "local-overlay://?root=/merged&lower-store=/lower&upper-layer=/upper&check-mount=true"

    machine.succeed("mkdir -p /lower /upper /work /merged/nix/store")

    # 1. Build the read-only LOWER store: copy hello (+ closure) into /lower.
    machine.succeed(f"nix --extra-experimental-features nix-command copy --no-check-sigs --to 'local?root=/lower' {lower_pkg}")
    machine.succeed(f"test -e /lower{lower_pkg}")
    # The delta is deliberately NOT in the lower yet.
    machine.succeed(f"test ! -e /lower{delta}")

    # 2. Mount the OverlayFS at the merged store dir (Nix verifies, never mounts).
    machine.succeed(
        "mount -t overlay overlay "
        "-o lowerdir=/lower/nix/store,upperdir=/upper,workdir=/work "
        "/merged/nix/store"
    )
    # The lower object is visible through the merged store dir.
    machine.succeed(f"test -e /merged/nix/store/{lower_bn}")

    # 3. THE CRUX (DB layering): the merged store's DB resolves a LOWER-only path.
    machine.succeed(f"nix {EF} path-info --store '{overlay}' {lower_pkg}")

    # 4. Add a NEW object to the merged store -> must land in the UPPER.
    machine.succeed(f"nix {EF} copy --no-check-sigs --to '{overlay}' {delta}")
    machine.succeed(f"nix {EF} path-info --store '{overlay}' {delta}")

    # 5. Delta isolation: new object is in UPPER, absent from LOWER; lower untouched.
    machine.succeed(f"test -e /upper/{delta_bn}")
    machine.succeed(f"test ! -e /lower/nix/store/{delta_bn}")
    # And it reads back correctly through the merged store dir.
    content = machine.succeed(f"cat /merged/nix/store/{delta_bn}").strip()
    assert "per-slot UPPER layer" in content, f"delta content wrong through overlay: {content!r}"

    print("PASS: local-overlay store — lower path valid via merged DB, new path isolated to upper, lower untouched")
  '';
}
