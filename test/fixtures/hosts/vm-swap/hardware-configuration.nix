# As nixos-generate-config writes it for a UEFI install with an encrypted root and the ESP
# mounted at /boot/efi.
{ lib, ... }:
{
  boot.initrd.availableKernelModules = [ "xhci_pci" "nvme" "usb_storage" "sd_mod" ];
  fileSystems."/" = { device = "/dev/disk/by-uuid/2b3c4d5e-6f7a-4b8c-9d0e-1f2a3b4c5d6e"; fsType = "ext4"; };
  boot.initrd.luks.devices."luks-c1d2e3f4-a5b6-4c7d-8e9f-0a1b2c3d4e5f".device = "/dev/disk/by-uuid/c1d2e3f4-a5b6-4c7d-8e9f-0a1b2c3d4e5f";
  fileSystems."/boot/efi" = { device = "/dev/disk/by-uuid/1A2B-3C4D"; fsType = "vfat"; options = [ "fmask=0077" "dmask=0077" ]; };
  swapDevices = [ { device = "/dev/disk/by-uuid/4e5f6a7b-8c9d-4e0f-9a1b-2c3d4e5f6a7b"; } ];
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
