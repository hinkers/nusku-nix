# Written by install.sh: the boot and encryption settings the NixOS installer put in
# /etc/nixos/configuration.nix (hardware-configuration.nix has the rest), as evaluated there
# (lib/installer-config.nix). ./install.sh --host NAME writes it again.
{ ... }:
{
  boot.loader.grub.device = "/dev/vda";
  boot.loader.grub.useOSProber = true;
  boot.loader.grub.enableCryptodisk = true;
  boot.initrd.secrets = {
    "/boot/crypto_keyfile.bin" = null;
  };
  boot.initrd.luks.devices = {
    "luks-5f2b8c1e-3d4a-4e6f-8a9b-1c2d3e4f5a6b" = {
      device = "/dev/disk/by-uuid/5f2b8c1e-3d4a-4e6f-8a9b-1c2d3e4f5a6b";
      keyFile = "/boot/crypto_keyfile.bin";
    };
    "luks-9e8d7c6b-5a4f-4e3d-9c2b-1a0f9e8d7c6b" = {
      device = "/dev/disk/by-uuid/9e8d7c6b-5a4f-4e3d-9c2b-1a0f9e8d7c6b";
      keyFile = "/boot/crypto_keyfile.bin";
    };
  };
}
