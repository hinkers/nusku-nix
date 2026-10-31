# Minimal hardware configuration for evaluation fixtures: btrfs subvolumes for / and /home (as
# the NixOS installer lays out a btrfs disk), so Snapper's /home config applies.
{ lib, ... }:
{
  fileSystems."/" = { device = "/dev/disk/by-label/nixos"; fsType = "btrfs"; options = [ "subvol=@" ]; };
  fileSystems."/home" = { device = "/dev/disk/by-label/nixos"; fsType = "btrfs"; options = [ "subvol=@home" ]; };
  fileSystems."/boot" = { device = "/dev/disk/by-label/BOOT"; fsType = "vfat"; };
  boot.initrd.availableKernelModules = [ "sd_mod" "sr_mod" ];
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
