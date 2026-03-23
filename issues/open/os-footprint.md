# Huge OS Footprint

**Labels**: nix

Every `nixpkgs` update requires ~32GB of downloads from the cache.
Installations on disk even with a minimal configuration take many GB, which is
problematic as one of my current deployments goes to a 16GB disk.

In general, I want to remain space-conscious (or at least
space-debugging-conscious).
