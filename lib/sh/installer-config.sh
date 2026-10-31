# shellcheck shell=bash
# Nusku - the NixOS installer's boot and encryption settings, carried into hosts/NAME/installer.nix.
# The NixOS installer writes some settings to /etc/nixos/configuration.nix, not to
# hardware-configuration.nix: GRUB's disk, os-prober and cryptodisk, the initrd key file
# (boot.initrd.secrets), LUKS devices beyond the root (encrypted swap, key files) and an ESP
# mounted elsewhere than /boot. The flake never reads /etc/nixos, so without them the first build
# can't unlock the disk (BIOS + LUKS) or waits for a swap device that never opens.
#
# The values are evaluated, not grepped: `nix eval --impure` evaluates configuration.nix with the
# running system's own nixpkgs (the nixpkgs= entry of NIX_PATH: on NixOS the root channel the
# NixOS installer copied in, offline), else with the flake's pinned nixpkgs (never Nix's flake
# registry, which a bare <nixpkgs> falls back to); lib/installer-config.nix picks the settings out
# as JSON; installer_nix writes them as a small Nix file. lib/hosts.nix imports it when it is there.
#
#   installer_probe            NUSKU_INSTALLER_JSON from this machine ("" without configuration.nix)
#   installer_nix              that JSON as installer.nix (nothing when there is nothing to carry)
#   host_write_installer NAME  write hosts/NAME/installer.nix, or remove it when nothing to carry
#   installer_state_version    the release NixOS was installed with (settings.json "stateVersion"):
#                              system.stateVersion from the same evaluation, else nixos-version
#
# Sourced, not executed. Needs lib/sh/log.sh; uses nix and jq. Test hook: NUSKU_NIXOS_CONFIG
# (default /etc/nixos/configuration.nix).

NUSKU_INSTALLER_JSON=""

# The system's nixpkgs/nixos from NIX_PATH's nixpkgs= entry; throws without one.
_INSTALLER_CHANNEL='(let c = builtins.filter (e: e.prefix == "nixpkgs" && builtins.pathExists e.path) builtins.nixPath; in if c == [ ] then throw "no nixpkgs channel on NIX_PATH" else (builtins.head c).path + "/nixos")'

_installer_conf() {
    printf '%s\n' "${NUSKU_NIXOS_CONFIG:-/etc/nixos/configuration.nix}"
}

# _installer_eval NIXOS: lib/installer-config.nix (as JSON) of configuration.nix evaluated with
# NIXOS, a Nix expression for nixpkgs' nixos/ directory.
_installer_eval() {
    nix eval --impure --json --expr \
        "import (/. + \"$NUSKU_ROOT/lib/installer-config.nix\") (import $1 { configuration = /. + \"$(_installer_conf)\"; }).config"
}

installer_probe() {
    local conf out err
    conf="$(_installer_conf)"
    NUSKU_INSTALLER_JSON=""
    if [ ! -r "$conf" ]; then
        log_warn "No $conf: no boot or encryption settings from the NixOS installer to carry over."
        return 0
    fi
    log_info "Reading the boot and encryption settings the NixOS installer wrote to $conf"
    err="$(mktemp)"
    if ! out="$(_installer_eval "$_INSTALLER_CHANNEL" 2>"$err")"; then
        log_info "This system's nixpkgs channel is not available; evaluating with the flake's nixpkgs"
        if ! out="$(_installer_eval "((builtins.getFlake \"git+file://$NUSKU_ROOT\").inputs.nixpkgs + \"/nixos\")" 2>>"$err")"; then
            cat "$err" >>"$NUSKU_LOG"
            die "Could not evaluate $conf, so its boot and encryption settings (LUKS, GRUB) can't be carried over and the build could leave this machine unbootable:
$(tail -n 5 "$err")
Fix $conf (check it with: sudo nixos-rebuild dry-build), then run ./install.sh again."
        fi
    fi
    rm -f "$err"
    NUSKU_INSTALLER_JSON="$out"
}

# installer_nix: NUSKU_INSTALLER_JSON as installer.nix: only what differs from what Nusku sets
# anyway. Prints nothing when there is nothing to carry.
installer_nix() {
    local body
    body="$(jq -r '
        del(.stateVersion)
        | def q: if type == "string" and test("^[A-Za-z0-9_./:+@=,-]+$") then "\"\(.)\""
               else error("unexpected value in the NixOS installer settings: \(tojson)") end;
        def val: if type == "string" then q elif type == "boolean" or type == "number" then tostring
                 elif . == null then "null" else error("unexpected value: \(tojson)") end;
        # A LUKS option at its default is left out.
        def luksDefaults: { keyFile: null, keyFileSize: null, keyFileOffset: null, header: null,
                            allowDiscards: false, bypassWorkqueues: false };
        (.grub // {}) as $g
        | ($g.device // "" | startswith("/dev/")) as $disk
        | (if $disk then "  boot.loader.grub.device = \($g.device | q);" else empty end),
          (if $g.useOSProber == true then "  boot.loader.grub.useOSProber = true;" else empty end),
          (if $g.enableCryptodisk == true then "  boot.loader.grub.enableCryptodisk = true;" else empty end),
          (if (.efiSysMountPoint // "/boot") != "/boot"
           then "  boot.loader.efi.efiSysMountPoint = \(.efiSysMountPoint | q);" else empty end),
          (if (.secrets // {}) != {} then
             "  boot.initrd.secrets = {",
             (.secrets | to_entries[] | "    \(.key | q) = \(.value | val);"),
             "  };"
           else empty end),
          (if (.luks // {}) != {} then
             "  boot.initrd.luks.devices = {",
             (.luks | to_entries[] |
               "    \(.key | q) = {",
               "      device = \(.value.device | q);",
               (.value | to_entries[] | select(.key != "device")
                 | select(.key as $k | luksDefaults | has($k))
                 | select(.key as $k | .value != luksDefaults[$k])
                 | "      \(.key) = \(.value | val);"),
               "    };"),
             "  };"
           else empty end)
        ' <<<"$NUSKU_INSTALLER_JSON")" || die "Could not read the NixOS installer's boot settings: $NUSKU_INSTALLER_JSON"
    [ -n "$body" ] || return 0
    cat <<EOF
# Written by install.sh: the boot and encryption settings the NixOS installer put in
# /etc/nixos/configuration.nix (hardware-configuration.nix has the rest), as evaluated there
# (lib/installer-config.nix). ./install.sh --host NAME writes it again.
{ ... }:
{
$body
}
EOF
}

host_write_installer() {
    local file="$NUSKU_ROOT/hosts/$1/installer.nix" text
    # Not probed, or no configuration.nix: nothing known, so keep what is there.
    [ -n "$NUSKU_INSTALLER_JSON" ] || return 0
    text="$(installer_nix)"
    if [ -z "$text" ]; then
        rm -f "$file"
        return 0
    fi
    mkdir -p "$(dirname "$file")"
    printf '%s\n' "$text" >"$file"
    log_info "hosts/$1/installer.nix: the NixOS installer's boot and encryption settings"
}

installer_state_version() {
    local v=""
    [ -z "$NUSKU_INSTALLER_JSON" ] || v="$(jq -r '.stateVersion // ""' <<<"$NUSKU_INSTALLER_JSON")"
    [ -n "$v" ] || v="$(nixos-version 2>/dev/null || true)"
    v="${v:0:5}"
    [[ "$v" =~ ^[0-9][0-9]\.[0-9][0-9]$ ]] || v=""
    printf '%s\n' "$v"
}
