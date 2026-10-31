# The installer (install.sh) side of the flake. test/unit/install.bats checks that a first run
# writes exactly test/fixtures/hosts/installer-laptop/settings.json; evaluating that fixture
# (check installer-laptop) proves what the installer writes passes the settings.json validation.
#
# The NixOS installer's boot and encryption settings (hosts/NAME/installer.nix): for each case in
# test/fixtures/installer/<case>/ (a configuration.nix as the NixOS installer writes it),
# lib/installer-config.nix of the evaluated configuration is <case>/evaluated.json, the JSON
# install.bats feeds its stubbed evaluator; install.bats renders that JSON to the installer.nix
# of fixture host vm-luks (bios-luks) and vm-swap (uefi-swap), and none for plain. Those hosts
# are evaluated here.
{ hosts, catalogue, lib, ... }:
let
  laptop = hosts.installer-laptop.config;
  luks = hosts.vm-luks.config;
  swap = hosts.vm-swap.config;
  min = hosts.vm-min.config;
  installerCase = name:
    let
      dir = ../fixtures/installer + "/${name}";
      evaluated = (lib.nixosSystem {
        system = "x86_64-linux";
        modules = [ (dir + "/configuration.nix") ];
      }).config;
    in
    import ../../lib/installer-config.nix evaluated == builtins.fromJSON (builtins.readFile (dir + "/evaluated.json"));
  keyFile = "/boot/crypto_keyfile.bin";
  rootLuks = "luks-5f2b8c1e-3d4a-4e6f-8a9b-1c2d3e4f5a6b";
  swapLuks = "luks-9e8d7c6b-5a4f-4e3d-9c2b-1a0f9e8d7c6b";
  uefiSwapLuks = "luks-e6f7a8b9-c0d1-4e2f-8a3b-4c5d6e7f8a9b";
in
{
  "test/fixtures/catalogue.json (the unit tests' copy of `nix eval --json .#lib.catalogue`) is lib.catalogue" =
    builtins.fromJSON (builtins.readFile ../fixtures/catalogue.json) == catalogue;
  "the installer's hybrid laptop gets its PRIME bus IDs" =
    laptop.hardware.nvidia.prime.intelBusId == "PCI:0:2:0"
    && laptop.hardware.nvidia.prime.nvidiaBusId == "PCI:1:0:0";
  "the installer's laptop screen scale is read" =
    laptop.nusku.panels == [ { output = "eDP-1"; scale = 1.25; } ];
  "the installer's apps are the ★ picks" =
    laptop.nusku.apps == map (a: a.id) (builtins.filter (a: a.star or false) catalogue.apps);

  # --- hosts/NAME/installer.nix ----------------------------------------------------------------
  "installer-config: BIOS + LUKS configuration.nix evaluates to bios-luks/evaluated.json" = installerCase "bios-luks";
  "installer-config: UEFI + encrypted swap evaluates to uefi-swap/evaluated.json" = installerCase "uefi-swap";
  "installer-config: a plain UEFI install evaluates to plain/evaluated.json" = installerCase "plain";
  "BIOS + LUKS host: GRUB on the installer's disk with cryptodisk and os-prober" =
    luks.boot.loader.grub.enable && luks.boot.loader.grub.device == "/dev/vda"
    && luks.boot.loader.grub.enableCryptodisk && luks.boot.loader.grub.useOSProber;
  "BIOS + LUKS host: the key file goes into the initrd and unlocks root and swap" =
    luks.boot.initrd.secrets == { ${keyFile} = null; }
    && luks.boot.initrd.luks.devices.${rootLuks}.keyFile == keyFile
    && luks.boot.initrd.luks.devices.${swapLuks}.keyFile == keyFile
    && luks.boot.initrd.luks.devices.${swapLuks}.device == "/dev/disk/by-uuid/9e8d7c6b-5a4f-4e3d-9c2b-1a0f9e8d7c6b";
  "BIOS + LUKS host: the installer's GRUB disk wins over a stale settings.json boot.device" =
    (hosts.vm-luks.extendModules { modules = [{ nusku.boot.device = lib.mkForce "/dev/sdz"; }]; })
      .config.boot.loader.grub.device == "/dev/vda";
  "UEFI + encrypted swap host: the swap's LUKS device, systemd-boot on the ESP at /boot/efi" =
    swap.boot.initrd.luks.devices ? ${uefiSwapLuks}
    && swap.boot.initrd.luks.devices.${uefiSwapLuks}.device == "/dev/disk/by-uuid/e6f7a8b9-c0d1-4e2f-8a3b-4c5d6e7f8a9b"
    && swap.boot.loader.systemd-boot.enable && swap.boot.loader.efi.efiSysMountPoint == "/boot/efi"
    && swap.boot.loader.efi.canTouchEfiVariables && !swap.boot.loader.grub.enable;
  "hosts without installer.nix are unchanged: no LUKS, secrets, cryptodisk or os-prober; ESP at /boot" =
    builtins.all (c:
      c.boot.initrd.luks.devices == { } && c.boot.initrd.secrets == { }
      && !c.boot.loader.grub.enableCryptodisk && !c.boot.loader.grub.useOSProber
      && c.boot.loader.efi.efiSysMountPoint == "/boot")
      [ min laptop hosts.vm-grub.config hosts.vm-full.config ];
  "a host without installer.nix still takes GRUB's disk from settings.json" =
    hosts.vm-grub.config.boot.loader.grub.device == "/dev/sda";
}
