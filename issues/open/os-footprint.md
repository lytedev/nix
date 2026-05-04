# Huge Operating System Footprint

**Labels**: nix

Every `nixpkgs` update requires ~32 gigabytes of downloads from the cache.
Installations on disk even with a minimal configuration take many gigabytes,
which is problematic as one of my current deployments goes to a 16 gigabytes
disk.

In general, I want to remain space-conscious (or at least
space-debugging-conscious).

Related, each rebuild requires rebuilding certain packages which _should_ be
fully cached:

- `IosevkaLyteTerm`
- Various `vaultwarden` clients?
