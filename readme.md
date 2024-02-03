# Nix

My grand, declarative, and unified application, service, environment, and
machine configuration, secret, and package management in a single flake. ❤️ ❄️

**NOTE**: Everything in here is highly specific to my personal preference. I
can't recommend you actually use this in any way, but hopefully some stuff in
here is useful inspiration.

# Quick Start

```shell_session
$ nixos-rebuild switch --flake git+https://git.lyte.dev/lytedev/nix#${FLAKE_ATTR}
```

You don't have even have to clone this crap yourself. How cool is that! But if you do, it looks like this:

```shell_session
$ nixos-rebuild switch --flake ./repo/dir/for/nix#${FLAKE_ATTR}
```

## Setup

If you're gonna change stuff you had better setup the pre-commit hook:

```shell_session
$ ln -s $PWD/pre-commit.bash .git/hooks/pre-commit
```

## Secrets

If you're deploying anything secrets-related, you will need the proper keys:

```shell_session
$ mkdir -p ${XDG_CONFIG_HOME:-~/.config}/sops/age
$ pass age-key >> ${XDG_CONFIG_HOME:-~/.config}/sops/age/keys.txt
```

## NixOS

```shell_session
$ nixos-rebuild switch --flake 
```

## Not NixOS

**NOTE**: I pretty much solely use Home Manager as a NixOS module presently, so this is not fully supported.

```shell_session
$ curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
$ nix profile install github:nix-community/home-manager
$ FLAKE_ATTR=base-x86_64-linux
$ home-manager switch --flake git+https://git.lyte.dev/lytedev/nix#$FLAKE_ATTR
```

# Internal/Advanced Usage

See [lib/internal.md](./lib/internal.md).

# To Do

## Short Term

- more-easily manage gitea repo mirroring to github?
- router https://github.com/breakds/nixos-routers/blob/main/machines/welderhelper/router.nix
- a.lyte.dev for web analytics
- grafana and stuff for monitoring
- alerts?
- Broot config?

## Long Term

- nix-darwin for work profile(s)
  - https://medium.com/@zmre/nix-darwin-quick-tip-activate-your-preferences-f69942a93236
