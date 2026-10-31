# Named eval assertions (flake check `eval-base`): every name must evaluate to true.
{ hosts, lib, ... }:
let
  min = hosts.vm-min.config;
  full = hosts.vm-full.config;
  grub = hosts.vm-grub.config;
  has = list: x: builtins.elem x list;
in
{
  "systemd-boot with EFI by default" =
    min.boot.loader.systemd-boot.enable && min.boot.loader.efi.canTouchEfiVariables
    && !min.boot.loader.grub.enable;
  "grub host uses the device from settings" =
    grub.boot.loader.grub.enable && grub.boot.loader.grub.device == "/dev/sda"
    && !grub.boot.loader.systemd-boot.enable;
  "latest kernel" = min.boot.kernelPackages.kernel.version == hosts.vm-min.pkgs.linuxPackages_latest.kernel.version;
  "NetworkManager on" = min.networking.networkmanager.enable;
  "PipeWire with WirePlumber and pulse/alsa" =
    min.services.pipewire.enable && min.services.pipewire.wireplumber.enable
    && min.services.pipewire.pulse.enable && min.services.pipewire.alsa.enable
    && !min.services.pulseaudio.enable;
  "bluetooth and blueman" = min.hardware.bluetooth.enable && min.services.blueman.enable;
  "firmware: redistributable and sof" =
    min.hardware.enableRedistributableFirmware && builtins.any (p: lib.hasPrefix "sof-firmware" p.name) min.hardware.firmware.paths;
  "timezone, locale and keymap from settings" =
    full.time.timeZone == "Australia/Brisbane" && full.i18n.defaultLocale == "en_AU.UTF-8"
    && min.services.xserver.xkb.layout == "us" && min.console.useXkbConfig && min.time.timeZone == "UTC";
  "user is a wheel/networkmanager/video/audio zsh user" =
    let u = min.users.users.nusku; in
    u.isNormalUser && u.shell == hosts.vm-min.pkgs.zsh && min.programs.zsh.enable
    && builtins.all (g: has u.extraGroups g) [ "wheel" "networkmanager" "video" "audio" ];
  "user follows settings" = full.users.users.nathan.isNormalUser && !(full.users.users ? nusku);
  "flakes enabled" = has min.nix.settings.experimental-features "nix-command"
    && has min.nix.settings.experimental-features "flakes";
  "weekly GC keeping 14 days" = min.nix.gc.automatic && min.nix.gc.dates == [ "weekly" ]
    && lib.hasInfix "14d" (toString min.nix.gc.options);
  "unfree allowed" = min.nixpkgs.config.allowUnfree;
  "firewall on, SSH closed by default" =
    min.networking.firewall.enable && !(has min.networking.firewall.allowedTCPPorts 22)
    && !min.services.openssh.enable;
  "polkit on" = min.security.polkit.enable;
  "keyring and online accounts" =
    min.services.gnome.gnome-keyring.enable && min.services.gnome.gnome-online-accounts.enable;
  "a C toolchain always (nusku-arch's base-devel): gcc and gnumake, so Rust and others can link" =
    builtins.all (c: builtins.elem c.pkgs.gcc c.config.environment.systemPackages
      && builtins.elem c.pkgs.gnumake c.config.environment.systemPackages)
      [ hosts.vm-min hosts.vm-full ];
  "avahi off by default" = !min.services.avahi.enable;
  "another module can enable avahi" =
    (hosts.vm-min.extendModules { modules = [ { services.avahi.enable = true; } ]; }).config.services.avahi.enable;
}
