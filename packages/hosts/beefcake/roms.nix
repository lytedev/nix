{
  # Miyoo Mini Plus ROM and save sync via rsync over SSH.
  # ROMs go in /storage/daniel/miyoo-mini/roms/<SYSTEM>/
  # using OnionOS folder names (GBA, SFC, GB, GBC, MD, etc.)
  lyte.roms = {
    enable = true;
    syncPubKeys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMUUxrBAXf2L53CZUJ2yAsk26+gI4UgqNrqw5z0n21e8 miyoo-mini-sync"
    ];
  };
}
