# As nixos-generate-config writes it for a BIOS install with an encrypted root (the root's LUKS
# device is here; the installer's other boot settings are in configuration.nix).
{ lib, ... }:
{
  boot.initrd.availableKernelModules = [ "ata_piix" "uhci_hcd" "virtio_pci" "sr_mod" "virtio_blk" ];
  fileSystems."/" = { device = "/dev/disk/by-uuid/0d6f2a4c-6c55-4b0e-9a83-0d1f3c7a9e21"; fsType = "ext4"; };
  boot.initrd.luks.devices."luks-5f2b8c1e-3d4a-4e6f-8a9b-1c2d3e4f5a6b".device = "/dev/disk/by-uuid/5f2b8c1e-3d4a-4e6f-8a9b-1c2d3e4f5a6b";
  swapDevices = [ { device = "/dev/disk/by-uuid/7a8b9c0d-1e2f-4a3b-8c4d-5e6f7a8b9c0d"; } ];
  boot.initrd.luks.devices."luks-9e8d7c6b-5a4f-4e3d-9c2b-1a0f9e8d7c6b".device = "/dev/disk/by-uuid/9e8d7c6b-5a4f-4e3d-9c2b-1a0f9e8d7c6b";
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
