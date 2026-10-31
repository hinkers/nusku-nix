# The boot and encryption settings the NixOS installer (Calamares) writes to
# /etc/nixos/configuration.nix rather than hardware-configuration.nix: GRUB's disk, os-prober and
# cryptodisk, the initrd key file (boot.initrd.secrets), LUKS devices beyond the root (encrypted
# swap, key files), and the ESP's mount point. The flake never reads /etc/nixos, so install.sh
# (lib/sh/installer-config.sh) evaluates that configuration, passes its `config` to this function
# and writes what it returns into hosts/NAME/installer.nix.
#
# The result is plain JSON data. Paths are kept as strings: a path value would be copied into the
# Nix store by builtins.toJSON, and a key file must never land there.
config:
let
  boot = config.boot;
  grub = boot.loader.grub;
  str = v: if v == null then null else toString v;
  # An option a release has removed throws when read: count it as unset.
  get = d: name: default:
    let r = builtins.tryEval (d.${name} or default); in if r.success then r.value else default;
  # The LUKS options a systemd stage 1 (Nusku's nixpkgs) still has. preLVM and
  # fallbackToPassword were scripted stage 1 only; the NixOS installer never sets them.
  luksDevice = d: {
    device = d.device;
    keyFile = str (get d "keyFile" null);
    keyFileSize = get d "keyFileSize" null;
    keyFileOffset = get d "keyFileOffset" null;
    header = str (get d "header" null);
    allowDiscards = get d "allowDiscards" false;
    bypassWorkqueues = get d "bypassWorkqueues" false;
  };
in
{
  # Only when the installed system boots with GRUB (BIOS); a UEFI install uses systemd-boot.
  grub = if grub.enable then {
    device = grub.device;
    useOSProber = grub.useOSProber;
    enableCryptodisk = grub.enableCryptodisk;
  } else null;
  efiSysMountPoint = boot.loader.efi.efiSysMountPoint;
  secrets = builtins.mapAttrs (_: str) boot.initrd.secrets;
  luks = builtins.mapAttrs (_: luksDevice) boot.initrd.luks.devices;
  # Not a boot setting: the release NixOS was installed with, for settings.json "stateVersion".
  stateVersion = config.system.stateVersion;
}
