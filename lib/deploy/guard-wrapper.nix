# Thin pre-flight wrapper around the deploy-rs `deploy` CLI.
#
# Wired into the devshell as `deploy` (shadowing the raw deploy-rs binary, which
# is reachable only by absolute store path inside this script — so there is no
# recursion). Before handing off to the real deploy-rs, it asks one question per
# target host: "would this deploy move the host BACKWARD?" If so it refuses,
# unless an explicit override is given. Everything is best-effort and FAILS OPEN
# (warn + proceed) whenever a signal cannot be resolved, so a legitimate deploy
# is never blocked by the guard itself.
#
# Motivated by the 2026-06-28 beefcake incident: a deploy from a stale workspace
# silently downgraded nixpkgs (06-23 -> 05-31), wedging the live switch,
# regressing redis below its on-disk RDB format, and dropping a service's
# user/group. Note that `main` can legitimately be BEHIND a host's deployed
# state, so we compare the host's actual running state, not branch position.
#
# Two independent "backward?" signals (refuse if EITHER fires):
#   1. Config-revision ancestry. The running host reports
#      `configurationRevision` (a short git rev, already wired in
#      lib/modules/nixos/default-module.nix) via `nixos-version --json`. If that
#      rev is a strict DESCENDANT of what we're about to deploy (HEAD), the host
#      is ahead and we'd be rolling it back. Divergent/sideways history is
#      treated as INCONCLUSIVE rather than backward, because jj rewrites commit
#      hashes routinely (rebase/squash) and divergence is the normal case, not a
#      rollback — blocking on it would cause chronic false refusals. This is a
#      deliberate softening of "must be a linear ancestor".
#   2. nixpkgs date. Compare the YYYYMMDD baked into the host's running
#      `nixosVersion` against the date of the nixpkgs the deploy would use
#      (stable vs unstable per the host's helper in packages/hosts/default.nix,
#      resolved from flake.lock). Older deploy date => downgrade. This is the
#      signal that reliably catches the incident shape, including when the host's
#      rev is no longer in local history.
#
# Override (intentional rollback): pass `--allow-downgrade` (stripped before
# deploy-rs sees it) or set `LYTE_ALLOW_DOWNGRADE=1`.
# Debug/testing: set `LYTE_DEPLOY_GUARD_DRYRUN=1` to print the decision and the
# command that WOULD run, without invoking deploy-rs.
{
  pkgs,
  realDeploy,
}:
pkgs.writeShellApplication {
  name = "deploy";
  runtimeInputs = [
    pkgs.coreutils
    pkgs.gnugrep
    pkgs.jq
    pkgs.git
    pkgs.openssh
    pkgs.nix
  ];
  text = ''
    real_deploy=${realDeploy}/bin/deploy

    allow_downgrade=0
    if [ "''${LYTE_ALLOW_DOWNGRADE:-}" = "1" ]; then allow_downgrade=1; fi
    dryrun=0
    if [ "''${LYTE_DEPLOY_GUARD_DRYRUN:-}" = "1" ]; then dryrun=1; fi

    # ---- parse args: collect target hosts, strip our own --allow-downgrade ----
    forward_args=()
    targets=()
    all_nodes=0
    for a in "$@"; do
      case "$a" in
        --allow-downgrade)
          allow_downgrade=1
          ;;
        .)
          all_nodes=1
          forward_args+=("$a")
          ;;
        *"#"*)
          targets+=("''${a##*#}")
          forward_args+=("$a")
          ;;
        *)
          forward_args+=("$a")
          ;;
      esac
    done

    run_real() {
      if [ "$dryrun" = "1" ]; then
        echo "deploy-guard: DRY RUN, would exec: $real_deploy ''${forward_args[*]}"
        exit 0
      fi
      exec "$real_deploy" "''${forward_args[@]}"
    }

    # Pull the first 8-digit YYYYMMDD token out of a nixos version label.
    extract_date() { printf '%s\n' "$1" | grep -oE '[0-9]{8}' | head -n1 || true; }

    # Locate the flake root. Prefer the git top-level (the normal deploy location
    # /etc/nixos is a colocated checkout), else walk up for flake.nix (covers jj
    # workspaces, which are not git working trees). The rev-ancestry signal needs
    # git; when it is unavailable we silently fall back to the date signal only.
    find_flake_root() {
      local d="$PWD"
      while [ "$d" != "/" ]; do
        if [ -e "$d/flake.nix" ]; then printf '%s' "$d"; return 0; fi
        d=$(dirname "$d")
      done
      return 1
    }
    repo_root=$(git rev-parse --show-toplevel 2>/dev/null || true)
    if [ -z "$repo_root" ]; then repo_root=$(find_flake_root || true); fi
    if [ -z "$repo_root" ]; then
      echo "deploy-guard: could not find a flake root, skipping pre-flight (fail-open)" >&2
      run_real
    fi
    deploy_rev=$(git -C "$repo_root" rev-parse HEAD 2>/dev/null || true)

    # ---- resolve host list ----
    hosts=()
    if [ "''${#targets[@]}" -gt 0 ]; then
      hosts=("''${targets[@]}")
    elif [ "$all_nodes" = "1" ]; then
      while IFS= read -r n; do
        [ -n "$n" ] && hosts+=("$n")
      done < <(nix eval --json "$repo_root#deploy.nodes" --apply builtins.attrNames 2>/dev/null | jq -r '.[]?' 2>/dev/null || true)
    fi

    if [ "''${#hosts[@]}" -eq 0 ]; then
      echo "deploy-guard: could not determine target host(s), skipping pre-flight (fail-open)" >&2
      run_real
    fi

    # ---- resolve the deploy-side nixpkgs dates once (stable + unstable) ----
    meta=$(nix flake metadata --json "$repo_root" 2>/dev/null || true)
    node_date() {
      local input="$1" node ts
      node=$(printf '%s' "$meta" | jq -r --arg i "$input" '.locks.nodes.root.inputs[$i] // empty' 2>/dev/null || true)
      [ -z "$node" ] && return 0
      ts=$(printf '%s' "$meta" | jq -r --arg n "$node" '.locks.nodes[$n].locked.lastModified // empty' 2>/dev/null || true)
      [ -z "$ts" ] && return 0
      date -u -d "@$ts" +%Y%m%d 2>/dev/null || true
    }
    stable_date=$(node_date nixpkgs)
    unstable_date=$(node_date nixpkgs-unstable)

    blocked=()
    for h in "''${hosts[@]}"; do
      hostname=$(nix eval --raw "$repo_root#deploy.nodes.\"$h\".hostname" 2>/dev/null || true)
      if [ -z "$hostname" ]; then
        echo "deploy-guard: '$h' is not a deploy node, skipping its check (fail-open)" >&2
        continue
      fi
      ssh_opts=()
      while IFS= read -r o; do
        [ -n "$o" ] && ssh_opts+=("$o")
      done < <(nix eval --json "$repo_root#deploy.nodes.\"$h\".sshOpts" 2>/dev/null | jq -r '.[]?' 2>/dev/null || true)

      host_json=$(ssh -o BatchMode=yes -o ConnectTimeout=8 "''${ssh_opts[@]}" "root@$hostname" nixos-version --json 2>/dev/null || true)
      if [ -z "$host_json" ] || ! printf '%s' "$host_json" | jq -e . >/dev/null 2>&1; then
        echo "deploy-guard: could not read state from '$h' ($hostname), skipping its check (fail-open)" >&2
        continue
      fi
      host_rev=$(printf '%s' "$host_json" | jq -r '.configurationRevision // empty')
      host_ver=$(printf '%s' "$host_json" | jq -r '.nixosVersion // empty')
      host_date=$(extract_date "$host_ver")

      # signal 1: revision ancestry
      rev_state=inconclusive
      if [ -n "$deploy_rev" ] && [ -n "$host_rev" ] \
        && git -C "$repo_root" cat-file -e "''${host_rev}^{commit}" 2>/dev/null; then
        host_rev_full=$(git -C "$repo_root" rev-parse "$host_rev" 2>/dev/null || true)
        if [ "$host_rev_full" = "$deploy_rev" ]; then
          rev_state=same
        elif git -C "$repo_root" merge-base --is-ancestor "$host_rev_full" "$deploy_rev" 2>/dev/null; then
          rev_state=forward
        elif git -C "$repo_root" merge-base --is-ancestor "$deploy_rev" "$host_rev_full" 2>/dev/null; then
          rev_state=backward
        else
          rev_state=divergent
        fi
      fi

      # signal 2: nixpkgs date (channel per host helper)
      channel=unstable
      if grep -qE "^[[:space:]]*''${h}[[:space:]]*=[[:space:]]*stableHost" "$repo_root/packages/hosts/default.nix" 2>/dev/null; then
        channel=stable
      fi
      deploy_date=$unstable_date
      [ "$channel" = stable ] && deploy_date=$stable_date
      date_state=inconclusive
      if [ -n "$host_date" ] && [ -n "$deploy_date" ]; then
        if [ "$deploy_date" -lt "$host_date" ]; then date_state=backward; else date_state=ok; fi
      fi

      reasons=""
      if [ "$rev_state" = backward ]; then
        reasons="''${reasons}    - revision: host is AHEAD ($host_rev is a descendant of deploy HEAD $deploy_rev)\n"
      fi
      if [ "$date_state" = backward ]; then
        reasons="''${reasons}    - nixpkgs date: deploying $deploy_date ($channel) is OLDER than host's $host_date\n"
      fi
      if [ -n "$reasons" ]; then
        blocked+=("$h|$reasons")
      else
        echo "deploy-guard: '$h' OK (rev:$rev_state date:$date_state)" >&2
      fi
    done

    if [ "''${#blocked[@]}" -eq 0 ]; then
      run_real
    fi

    {
      echo "============================== DEPLOY BLOCKED =============================="
      echo "deploy-guard refused: the following deploy(s) would move a host BACKWARD."
      echo
      for b in "''${blocked[@]}"; do
        echo "  host: ''${b%%|*}"
        printf '%b' "''${b#*|}"
      done
      echo
      echo "This is almost always a stale-workspace / reverted-bump mistake. ('main'"
      echo "can legitimately be BEHIND a host's deployed state.) Deploying risks data"
      echo "loss and a wedged live switch. No deploy was started."
      echo
      echo "If this rollback is INTENTIONAL, re-run with:  deploy --allow-downgrade ..."
      echo "(or set LYTE_ALLOW_DOWNGRADE=1)."
      echo "==========================================================================="
    } >&2

    if [ "$allow_downgrade" = "1" ]; then
      echo "deploy-guard: --allow-downgrade set, proceeding with the deploy anyway." >&2
      run_real
    fi
    exit 1
  '';
}
