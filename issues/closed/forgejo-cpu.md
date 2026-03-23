# Forgejo using CPU doing nothing

**Labels**: service, beefcake
**Related**: packages/hosts/beefcake/forgejo.nix

Forgejo sits at 50% CPU when idle.

Seems like 16 runners just hitting the server causes CPU to hover around 50% (of
one thread). Is this just password/token hashing algos cranking?

## Mitigations applied

- Database moved to SQLite on SSD (zroot) for better performance
- Anubis bot protection layer deployed (Proof-of-Work challenge)
- Runner count reduced to 1 instance

CPU issue itself has not been conclusively diagnosed or resolved.
