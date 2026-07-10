# COPY of lib/modules/nixos/validation.nix (production source of truth) —
# vendored so the standalone prototype flake stays self-contained.
# lyte.validation — a per-service smoke-check registry + runner. Turns blue/green
# "the candidate BOOTED and is reachable" into "every service passed its own
# health check" before a cutover is allowed (design §3, the lyte.validation.checks
# idiom). Service modules register a check; `lyte-validation-run` executes them
# all in the running system and exits non-zero if any fail. The blue/green
# cutover tool runs it INSIDE the validation slot (via the qemu guest agent) and
# gates on the result — and it doubles as a post-cutover health probe.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.lyte.validation;
  checks = lib.filterAttrs (_: c: c.enable) cfg.checks;
  runner = pkgs.writeShellApplication {
    name = "lyte-validation-run";
    # The check COMMAND strings call systemctl/findmnt/grep/awk/curl; the qemu
    # guest agent's guest-exec runs with a minimal PATH, so the runner must
    # supply these (checks run via `bash -c` and inherit this PATH). Service-
    # specific tools (kdig, pg_isready) are absolute-store-path'd by the checks.
    runtimeInputs = [
      pkgs.coreutils
      pkgs.bash
      pkgs.systemd # systemctl
      pkgs.util-linux # findmnt
      pkgs.gnugrep
      pkgs.gawk
      pkgs.curl
    ];
    text = ''
      set -uo pipefail
      fail=0
      total=0
      ${lib.concatStringsSep "\n" (
        lib.mapAttrsToList (name: c: ''
          total=$((total+1))
          printf '  %-28s ' ${lib.escapeShellArg (name + ":")}
          if timeout ${toString c.timeout} bash -c ${lib.escapeShellArg c.command} >/dev/null 2>&1; then
            echo "PASS  (${c.description})"
          else
            echo "FAIL  (${c.description})"; fail=$((fail+1))
          fi
        '') checks
      )}
      echo "---"
      if [ "$fail" = 0 ]; then
        echo "lyte-validation: ALL $total checks PASSED"
      else
        echo "lyte-validation: $fail/$total checks FAILED"; exit 1
      fi
    '';
  };
in
{
  options.lyte.validation = {
    checks = lib.mkOption {
      description = "Per-service smoke checks for blue/green validation + health probing.";
      default = { };
      type = lib.types.attrsOf (
        lib.types.submodule (
          { name, ... }:
          {
            options = {
              enable = lib.mkOption {
                type = lib.types.bool;
                default = true;
                description = "Whether to run this check.";
              };
              description = lib.mkOption {
                type = lib.types.str;
                description = "One-line human description of what a pass means.";
              };
              command = lib.mkOption {
                type = lib.types.str;
                description = "Shell snippet run in the live system; exit 0 = healthy.";
              };
              timeout = lib.mkOption {
                type = lib.types.int;
                default = 20;
                description = "Per-check timeout (seconds).";
              };
            };
          }
        )
      );
    };
    package = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      default = runner;
      description = "The generated lyte-validation-run script.";
    };
  };

  config = lib.mkIf (checks != { }) {
    environment.systemPackages = [ runner ];
  };
}
