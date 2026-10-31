# Base system, driven by config.nusku (settings.json).
{ config, lib, pkgs, ... }:
let
  cfg = config.nusku;
  grub = cfg.boot.loader == "grub";
in
{
  # Boot: systemd-boot on EFI, or GRUB on the device the installer picked.
  boot.loader = {
    systemd-boot.enable = !grub;
    efi.canTouchEfiVariables = !grub;
    grub = lib.mkIf grub {
      enable = true;
      device = cfg.boot.device;
    };
  };
  boot.kernelPackages = pkgs.linuxPackages_latest;

  networking.networkmanager.enable = true;
  # The firewall stays on. services.openssh opens port 22 itself, so SSH is reachable
  # only on a host that enables it.
  networking.firewall.enable = true;

  # Audio and Bluetooth.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = lib.mkDefault false; # Steam turns it on (32-bit games)
    pulse.enable = true;
    wireplumber.enable = true;
  };
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };
  services.blueman.enable = true;

  # Firmware, including Intel laptop audio (SOF).
  hardware.enableRedistributableFirmware = true;
  hardware.firmware = [ pkgs.sof-firmware ];

  time.timeZone = cfg.timezone;
  i18n.defaultLocale = cfg.locale;
  console.keyMap = cfg.keymap;

  programs.zsh.enable = true;
  # ~/.zshrc (config/zsh/zshrc) runs compinit itself; one run is enough.
  programs.zsh.enableGlobalCompInit = false;
  users.users.${cfg.user} = {
    isNormalUser = true;
    shell = pkgs.zsh;
    extraGroups = [ "wheel" "networkmanager" "video" "audio" ];
  };

  # A C toolchain on every host, as nusku-arch's base-devel: Rust (rustup's toolchains link
  # with cc), Go's cgo, Python native wheels and Neovim plugin builds need one.
  environment.systemPackages = [ pkgs.gcc pkgs.gnumake ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };
  nixpkgs.config.allowUnfree = true;

  security.polkit.enable = true;
  services.gnome.gnome-keyring.enable = true;
  # Calendar sync for the clock drop-down (nusku-calendar) and GNOME Calendar: Online Accounts
  # (Google, Nextcloud) feed evolution-data-server, which the calendar reads events from.
  services.gnome.gnome-online-accounts.enable = true;
  services.gnome.evolution-data-server.enable = true;
  services.avahi.enable = lib.mkDefault false; # an app that needs mDNS turns it on (Task 7)
}
