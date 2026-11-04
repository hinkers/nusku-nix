# The optional apps picked in settings.json "apps" (ids from lib/catalogue.nix). Every catalogue
# id is provided in exactly one place (test/eval/apps.nix checks it):
#   packagesFor    plain packages. Browsers go to the user's profile (modules/home/browsers.nix),
#                  the rest to environment.systemPackages.
#   systemApps     NixOS settings for apps that need more than a package: services, groups,
#                  firewall ports, file associations (nusku-arch's app hooks, declared).
#   handledInHome  Home Manager does all of it (modules/home/shell.nix, browsers.nix).
# settings.json "packages" (any nixpkgs package by name, no catalogue entry) are installed here too.
# Unfree apps (Discord, Obsidian, Spotify, Steam, VS Code, Claude Code, Parsec) rely on
# nixpkgs.config.allowUnfree (base.nix).
{ config, lib, pkgs, ... }:
let
  inherit (lib) mkIf mkMerge;
  cfg = config.nusku;
  catalogue = import ../../lib/catalogue.nix;
  picked = id: builtins.elem id cfg.apps;
  # Picked catalogue entries, in catalogue order.
  pickedApps = builtins.filter (a: picked a.id) catalogue.apps;
  isBrowser = a: a.browser or false;

  packagesFor = with pkgs; {
    # Neovim and the tools LazyVim calls (nusku-arch's list; the LazyVim config and the language
    # tools come from the Neovim module).
    neovim = [ neovim tree-sitter wl-clipboard unzip lazygit fd ripgrep nodejs ];
    gh = [ gh ];
    claude-code = [ claude-code ];
    lazygit = [ lazygit ];
    vscode = [ vscode ];

    firefox = [ firefox ];
    chromium = [ chromium ];
    brave = [ brave ];
    librewolf = [ librewolf ];
    discord = [ discord ];
    libreoffice = [ libreoffice ];
    thunderbird = [ thunderbird ];
    # Online Accounts and evolution-data-server run on every host (base.nix) for the clock's
    # drop-down calendar; this adds the full app and the accounts dialog.
    calendar = [ gnome-calendar gnome-online-accounts-gtk ];
    bitwarden = [ bitwarden-desktop ];

    spotify = [ spotify ];
    vlc = [ vlc ];
    obs = [ obs-studio ];
    audacity = [ audacity ];

    gimp = [ gimp ];
    krita = [ krita ];
    inkscape = [ inkscape ];
    kdenlive = [ kdePackages.kdenlive ];
    blender = [ blender ];

    photocraft = [ photocraft ];
    vectorcraft = [ vectorcraft ];
    lightcraft = [ lightcraft ];
    pdfcraft = [ pdfcraft ];
    wordcraft = [ wordcraft ];
    soundcraft = [ soundcraft ];
    deckcraft = [ deckcraft ];
    cadcraft = [ cadcraft ];
    gridcraft = [ gridcraft ];

    lutris = [ lutris wineWow64Packages.stable winetricks ];
    heroic = [ heroic ];
    parsec = [ parsec-bin ];
    # nixpkgs' mangohud carries the 32-bit Vulkan layer too (nusku-arch's lib32-mangohud).
    mangohud = [ mangohud ];
    protonup = [ protonup-qt ];
    wine = [ wineWow64Packages.stable winetricks ];
    # Bolt logs in with a Jagex account and starts RuneLite (or the official client).
    osrs = [ bolt-launcher ];

    remmina = [ remmina ];
    gparted = [ gparted ];
  };

  # Snapper keeps /home's history (system state is covered by NixOS generations), so it needs
  # /home to be its own btrfs subvolume, as the NixOS installer lays out a btrfs disk.
  homeIsBtrfs = (config.fileSystems."/home".fsType or null) == "btrfs";

  systemApps = {
    # docker includes the compose and buildx plugins.
    docker = {
      virtualisation.docker.enable = true;
      users.users.${cfg.user}.extraGroups = [ "docker" ];
    };

    # Turns on 32-bit graphics (nusku-arch's multilib + gpu32).
    steam = {
      programs.steam.enable = true;
      programs.gamescope.enable = true;
    };

    gamemode = {
      programs.gamemode.enable = true;
      users.users.${cfg.user}.extraGroups = [ "gamemode" ];
    };

    # Not at login: you opt in with the launcher's "Sunshine" entry (modules/home/sharing.nix),
    # which starts its user service, or stops it. Moonlight finds it over mDNS (Avahi). Ports
    # are nusku-arch's UFW rules: the streaming ports only, so the settings page (47990) stays
    # reachable from this PC alone (openFirewall would open it too).
    sunshine = {
      services.sunshine = {
        enable = true;
        autoStart = false;
        capSysAdmin = true; # KMS screen capture
      };
      services.avahi.enable = true;
      networking.firewall.allowedTCPPorts = [ 47984 47989 48010 ];
      networking.firewall.allowedUDPPorts = [ 47998 47999 48000 48002 48010 ];
    };

    # Shares the screen on port 5900. The user service, its config and its keys are in
    # modules/home/wayvnc.nix; it asks for this PC's user name and password through PAM, and
    # always encrypts, so the port is open to the network.
    wayvnc = {
      environment.systemPackages = [ pkgs.wayvnc ];
      networking.firewall.allowedTCPPorts = [ 5900 ];
      security.pam.services.wayvnc = { };
    };

    # Moonlight looks for Sunshine hosts with its own mDNS queries; let the replies in.
    moonlight = {
      environment.systemPackages = [ pkgs.moonlight-qt ];
      networking.firewall.allowedUDPPorts = [ 5353 ];
    };

    localsend.programs.localsend = {
      enable = true;
      openFirewall = true; # 53317 TCP and UDP
    };

    snapper = mkIf homeIsBtrfs {
      services.snapper.configs.home = {
        SUBVOLUME = "/home";
        ALLOW_USERS = [ cfg.user ];
        TIMELINE_CREATE = true;
        TIMELINE_CLEANUP = true;
      };
      # Snapper keeps snapshots in a .snapshots subvolume ("v" creates one on btrfs).
      systemd.tmpfiles.rules = [ "v /home/.snapshots 0750 root root -" ];
    };

    # Zathura with only the PDF (mupdf) plugin, as nusku-arch: the comic-book plugin would claim
    # folders. PDFs open in it unless the user picks another viewer (~/.config/mimeapps.list).
    zathura = {
      environment.systemPackages = [
        (pkgs.zathura.override { plugins = [ pkgs.zathuraPkgs.zathura_pdf_mupdf ]; })
      ];
      xdg.mime.defaultApplications."application/pdf" = "org.pwmt.zathura.desktop";
    };
  };

  # Home Manager modules install these when picked; nothing here.
  handledInHome = [
    "pokemon" # krabby (shell.nix)
    "yazi" # programs.yazi with preview helpers + launcher entry (shell.nix)
    "obsidian" # programs.obsidian + catppuccin/nix theme (browsers.nix)
  ];

  # Links open in the first picked browser (catalogue order) unless the user's own
  # ~/.config/mimeapps.list says otherwise (nusku-arch apps_browser_setup).
  browserDesktop = {
    firefox = "firefox.desktop";
    chromium = "chromium-browser.desktop";
    brave = "brave-browser.desktop";
    librewolf = "librewolf.desktop";
  };
  browsers = builtins.filter isBrowser pickedApps;
in
{
  options.nusku.internal.apps = lib.mkOption {
    type = lib.types.raw;
    internal = true;
    readOnly = true;
    description = ''
      How each catalogue app is provided: { packages = { id = [ package ]; }; system = [ id ];
      home = [ id ]; }. modules/home/browsers.nix takes the browsers' packages from it.
    '';
  };

  config = mkMerge ([
    {
      nusku.internal.apps = {
        packages = packagesFor;
        system = builtins.attrNames systemApps;
        home = handledInHome;
      };

      environment.systemPackages = lib.concatMap (a: packagesFor.${a.id} or [ ])
        (builtins.filter (a: !isBrowser a) pickedApps)
        # settings.json "packages": any nixpkgs package by name. Names that aren't one are left
        # out here and reported by options.nix's assertion (a clear message, not a Nix trace).
        ++ builtins.filter (p: (builtins.tryEval (lib.isDerivation p)).value or false)
          (map (name: lib.attrByPath (lib.splitString "." name) null pkgs) cfg.packages);

      xdg.mime.defaultApplications = mkIf (browsers != [ ]) (
        let desktop = browserDesktop.${(builtins.head browsers).id}; in {
          "x-scheme-handler/http" = desktop;
          "x-scheme-handler/https" = desktop;
          "text/html" = desktop;
        }
      );

      warnings = lib.optional (picked "snapper" && !homeIsBtrfs)
        "Snapper was skipped: /home is not its own btrfs mount.";
    }
  ] ++ lib.mapAttrsToList (id: settings: mkIf (picked id) settings) systemApps);
}
