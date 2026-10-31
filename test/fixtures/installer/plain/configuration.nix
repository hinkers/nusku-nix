# As the NixOS graphical installer (Calamares) writes it for a plain UEFI install: nothing about
# booting that Nusku's own settings don't already cover.
{ config, pkgs, ... }:
{
  imports = [ ./hardware-configuration.nix ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "nixos";
  users.users.tester = { isNormalUser = true; extraGroups = [ "wheel" ]; };
  system.stateVersion = "25.11";
}
