# Written by install.sh: the boot and encryption settings the NixOS installer put in
# /etc/nixos/configuration.nix (hardware-configuration.nix has the rest), as evaluated there
# (lib/installer-config.nix). ./install.sh --host NAME writes it again.
{ ... }:
{
  boot.loader.efi.efiSysMountPoint = "/boot/efi";
  boot.initrd.luks.devices = {
    "luks-c1d2e3f4-a5b6-4c7d-8e9f-0a1b2c3d4e5f" = {
      device = "/dev/disk/by-uuid/c1d2e3f4-a5b6-4c7d-8e9f-0a1b2c3d4e5f";
    };
    "luks-e6f7a8b9-c0d1-4e2f-8a3b-4c5d6e7f8a9b" = {
      device = "/dev/disk/by-uuid/e6f7a8b9-c0d1-4e2f-8a3b-4c5d6e7f8a9b";
    };
  };
}
