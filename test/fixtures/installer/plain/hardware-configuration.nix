# As nixos-generate-config writes it for a plain UEFI install (no encryption).
{ lib, ... }:
{
  boot.initrd.availableKernelModules = [ "xhci_pci" "nvme" "sd_mod" ];
  fileSystems."/" = { device = "/dev/disk/by-uuid/3c4d5e6f-7a8b-4c9d-0e1f-2a3b4c5d6e7f"; fsType = "ext4"; };
  fileSystems."/boot" = { device = "/dev/disk/by-uuid/5E6F-7A8B"; fsType = "vfat"; options = [ "fmask=0077" "dmask=0077" ]; };
  swapDevices = [ ];
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
