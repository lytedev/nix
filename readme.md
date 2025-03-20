<div align="center">

<h1>
<img width="100" src="lib/images/Nix_snowflake_lytedev.svg" /> <br>
Nix for <code>lytedev</code>
</h1>

[![pre-merge status](https://git.lyte.dev/lytedev/nix/badges/workflows/pre-merge.yaml/badge.svg)](https://git.lyte.dev/lytedev/nix/actions?workflow=pre-merge.yaml)

[NixOS Modules](./lib/modules/nixos/default.nix) - [Home Manager Modules](./lib/modules/home/default.nix) - [Desktop](./packages/hosts/dragon.nix) - [Laptop](./packages/hosts/foxtrot.nix) - [Server](./packages/hosts/beefcake.nix) - [Router](./packages/hosts/router.nix) - [Packages](./packages/default.nix) - [Templates](./lib/templates/default.nix) - [Docs](./lib/doc)

</div>

# Details

I aim for declaring everything where possible, but I definitely break the rules
if it's convenient enough and try to write it down when I do so. I also don't
like repeating myself in configuration. I am mostly focused on being pragmatic
and getting things done and doing so in a way that makes it easy to keep doing
so (maintainability), but I also occasionally fall into experimenting with big
refactors of the code for no real gain.

## Layers

- Common defaults (machines that I might not interact with at all or only
  rarely, such as backup targets)
- Machines that I interact with only remotely (`shell` class)
- Machines that I interact with directly, such as a laptop or my desktop
  workstation (`desktop` class)
