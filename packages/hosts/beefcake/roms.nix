{
  # Miyoo Mini Plus ROM and save sync via rsync over SSH.
  # ROMs go in /storage/daniel/miyoo-mini/roms/<SYSTEM>/
  # using OnionOS folder names (GBA, SFC, GB, GBC, MD, etc.)
  lyte.roms = {
    enable = true;
    romSyncPubKeys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIRNP/N+892JNg7uFNS9fserl6/6OnpkG63izptF1Os9 miyoo-mini-rom-sync"
    ];
    saveSyncPubKeys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIATbpRZ6R1zWP6443Xlo3EM3tKquavrXwVXxq8wRqIe8 miyoo-mini-save-sync"
    ];
  };
}
