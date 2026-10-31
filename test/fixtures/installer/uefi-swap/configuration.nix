# As the NixOS graphical installer (Calamares) writes it for a UEFI install with "Encrypt system",
# encrypted swap and the ESP at /boot/efi: systemd-boot, and the swap's LUKS device (which
# nixos-generate-config leaves out of hardware-configuration.nix).
{ config, pkgs, ... }:
{
  imports = [ ./hardware-configuration.nix ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.efi.efiSysMountPoint = "/boot/efi";

  boot.initrd.luks.devices."luks-e6f7a8b9-c0d1-4e2f-8a3b-4c5d6e7f8a9b".device = "/dev/disk/by-uuid/e6f7a8b9-c0d1-4e2f-8a3b-4c5d6e7f8a9b";

  networking.hostName = "nixos";
  users.users.tester = { isNormalUser = true; extraGroups = [ "wheel" ]; };
  system.stateVersion = "25.11";
}
