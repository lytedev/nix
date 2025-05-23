{
  pkgs,
  ...
}:
pkgs.writeShellApplication {
  name = "installer";
  runtimeInputs = with pkgs; [
    fzf
    jq
    gawk
  ];
  text = ''
    repo='https://git.lyte.dev/lytedev/nix'
    if ! [[ -f flake.nix ]]; then
      dir="$(mktemp -d)"
      echo "No flake detected. Cloning '$repo' to '$dir/nix'"
      cd "$dir"
      git clone "$repo"
      cd nix
    fi

    read -s -r -p 'Disk Encryption Password:' pass1
    echo
    read -s -r -p 'Disk Encryption Password (Again):' pass2
    echo
    if ! [[ $pass1 = "$pass2" ]]; then
      echo "error: disk encryption passwords did not match!"
      exit 1
    fi
    nixos_host="$(nix --extra-experimental-features 'nix-command flakes' eval --accept-flake-config --json .#nixosConfigurations --apply 'builtins.attrNames' | jq -r .[] | fzf --prompt 'Select NixOS configuration')"
    partition_scheme="$(nix --extra-experimental-features 'nix-command flakes' eval --accept-flake-config --json .#diskoConfigurations --apply 'builtins.attrNames' | jq -r .[] | fzf --prompt 'Select disk partition scheme (must match NixOS configuration!)')"
    disk_path="/dev/$(lsblk -d --raw | tail -n +2 | fzf --prompt 'Select local disk device' | awk '{print $1}')"

    echo "$pass1" | tr -d "\n" > /tmp/secret.key

    echo "This will install the host configuration for '$nixos_host' to '$disk_path' using partition scheme '$partition_scheme'. All data on the disk will be lost."
    echo "Press enter to proceed. Press Ctrl-C to cancel."
    read -r
    echo "Starting..."

    nix-shell --packages git --run "sudo nix run \
      --extra-experimental-features nix-command \
      --extra-experimental-features flakes \
      github:nix-community/disko -- \
        --flake '.#$partition_scheme' \
        --mode disko"

    nix-shell --packages git \
      --run "sudo nixos-install \
        --no-write-lock-file \
        --flake '.#$nixos_host' \
        --option trusted-substituters 'https://cache.nixos.org https://nix.h.lyte.dev' \
        --option trusted-public-keys 'cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= h.lyte.dev-2:te9xK/GcWPA/5aXav8+e5RHImKYMug8hIIbhHsKPN0M='"
  '';
}
