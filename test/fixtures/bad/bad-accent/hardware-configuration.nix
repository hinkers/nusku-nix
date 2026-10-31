# Minimal hardware configuration for evaluation fixtures (a real host keeps the one
# nixos-generate-config wrote).
{ lib, ... }:
{
  fileSystems."/" = { device = "/dev/disk/by-label/nixos"; fsType = "ext4"; };
  fileSystems."/boot" = { device = "/dev/disk/by-label/BOOT"; fsType = "vfat"; };
  boot.initrd.availableKernelModules = [ "sd_mod" "sr_mod" ];
  # Until base.nix configures the boot loader, keep GRUB from asserting a device.
  boot.loader.grub.enable = lib.mkDefault false;
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
