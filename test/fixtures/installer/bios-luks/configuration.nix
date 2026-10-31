# As the NixOS graphical installer (Calamares) writes it for a BIOS install with "Encrypt system"
# and encrypted swap: GRUB on the disk with cryptodisk, a key file in the initrd so the disk is
# unlocked once, and the key file for each LUKS device.
{ config, pkgs, ... }:
{
  imports = [ ./hardware-configuration.nix ];

  # Bootloader.
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/vda";
  boot.loader.grub.useOSProber = true;

  # Setup keyfile
  boot.initrd.secrets = {
    "/boot/crypto_keyfile.bin" = null;
  };

  boot.loader.grub.enableCryptodisk = true;

  boot.initrd.luks.devices."luks-9e8d7c6b-5a4f-4e3d-9c2b-1a0f9e8d7c6b".keyFile = "/boot/crypto_keyfile.bin";
  boot.initrd.luks.devices."luks-5f2b8c1e-3d4a-4e6f-8a9b-1c2d3e4f5a6b".keyFile = "/boot/crypto_keyfile.bin";

  networking.hostName = "nixos";
  networking.networkmanager.enable = true;
  time.timeZone = "Australia/Brisbane";
  users.users.tester = { isNormalUser = true; extraGroups = [ "networkmanager" "wheel" ]; };
  system.stateVersion = "25.05";
}
