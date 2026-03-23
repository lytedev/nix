# Forgejo using CPU doing nothing

**Labels**: service, beefcake

Forgejo sits at 50% CPU when idle.

Seems like 16 runners just hitting the server causes CPU to hover around 50% (of
one thread). Is this just password/token hashing algos cranking?
