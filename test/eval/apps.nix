# Named eval assertions (flake check `eval-apps`): the app catalogue and modules/nixos/apps.nix.
{ hosts, catalogue, lib, ... }:
let
  min = hosts.vm-min.config; # no apps
  full = hosts.vm-full.config; # firefox, obsidian; ext4
  all = hosts.vm-apps.config; # every catalogue app; btrfs / and /home
  # vm-full with only these apps picked.
  pick = apps: (hosts.vm-full.extendModules { modules = [{ nusku.apps = lib.mkForce apps; }]; }).config;
  hmOf = c: c.home-manager.users.${c.nusku.user};
  namesOf = ps: map (p: p.pname or p.name or "") ps;
  sysNames = c: namesOf c.environment.systemPackages;
  homeNames = c: namesOf (hmOf c).home.packages;
  hasAll = xs: ys: builtins.all (x: builtins.elem x ys) xs;
  hasNone = xs: ys: !(builtins.any (x: builtins.elem x ys) xs);
  groupsOf = c: c.users.users.${c.nusku.user}.extraGroups;
  tcp = c: c.networking.firewall.allowedTCPPorts;
  udp = c: c.networking.firewall.allowedUDPPorts;
  mime = c: c.xdg.mime.defaultApplications;

  ids = map (a: a.id) catalogue.apps;
  starred = map (a: a.id) (builtins.filter (a: a.star or false) catalogue.apps);
  inGroup = g: map (a: a.id) (builtins.filter (a: a.group == g) catalogue.apps);
  labelOf = id: (lib.findFirst (a: a.id == id) null catalogue.apps).label;

  # Where apps.nix provides each id: plain packages, a NixOS block, or Home Manager.
  src = full.nusku.internal.apps;
  places = id:
    lib.optional (src.packages ? ${id}) "packages"
    ++ lib.optional (builtins.elem id src.system) "system"
    ++ lib.optional (builtins.elem id src.home) "home";
  provided = builtins.attrNames src.packages ++ src.system ++ src.home;

  docker = pick [ "docker" ];
  localsend = pick [ "localsend" ];
  sunshine = pick [ "sunshine" ];
  snapperExt4 = pick [ "snapper" ];
  none = pick [ ];
in
{
  # --- catalogue (nusku-arch packages/apps.list with the spec §5 changes) --------------------
  "catalogue: ★ defaults are nusku-arch's" =
    starred == [ "neovim" "gh" "claude-code" "firefox" "discord" "obsidian" "spotify" "vlc" ];
  "catalogue: ArtCraft is nixpkgs' 9" =
    inGroup "artcraft" == [ "photocraft" "vectorcraft" "lightcraft" "pdfcraft" "wordcraft"
      "soundcraft" "deckcraft" "cadcraft" "gridcraft" ];
  "catalogue: Zen, UFW, Flatpak and the missing ArtCraft apps are gone" =
    hasNone [ "zen" "ufw" "flatpak" "filmcraft" "effectcraft" "designcraft" "figcraft" ] ids;
  "catalogue: group sizes" =
    map (g: builtins.length (inGroup g.id)) catalogue.groups == [ 6 12 4 5 9 10 6 ];
  "catalogue: optional GNOME Calendar with nusku-arch's label" =
    labelOf "calendar" == "GNOME Calendar (Google and Nextcloud sync)";
  "catalogue: LibreWolf no longer says Flatpak" = labelOf "librewolf" == "LibreWolf";
  "catalogue: snapper is the only btrfs app" =
    map (a: a.id) (builtins.filter (a: a.btrfs or false) catalogue.apps) == [ "snapper" ];
  "catalogue: browsers flagged" =
    map (a: a.id) (builtins.filter (a: a.browser or false) catalogue.apps)
    == [ "firefox" "chromium" "brave" "librewolf" ];

  # --- coverage ------------------------------------------------------------------------------
  "every catalogue app is provided in exactly one place" =
    builtins.all (id: builtins.length (places id) == 1) ids;
  "apps.nix provides nothing the catalogue lacks" = builtins.all (id: builtins.elem id ids) provided;
  "handled in Home Manager: exactly pokemon and yazi" = src.home == [ "pokemon" "yazi" ];
  "each Home Manager app really adds to the user's packages" =
    builtins.all (id: homeNames (pick [ id ]) != homeNames none) src.home;
  "every package in packagesFor evaluates" =
    builtins.all (p: lib.hasPrefix "/nix/store/" p.drvPath)
      (lib.concatLists (builtins.attrValues src.packages));
  "vm-apps picks every catalogue app" = lib.sort lib.lessThan all.nusku.apps == lib.sort lib.lessThan ids;

  # --- plain packages ------------------------------------------------------------------------
  "nothing picked: no app packages or services" =
    hasNone [ "libreoffice" "gimp" "vlc" "docker" "zathura-with-plugins" ] (sysNames min)
    && !min.virtualisation.docker.enable && !min.programs.steam.enable
    && !min.services.sunshine.enable && !min.services.avahi.enable
    && min.services.snapper.configs == { };
  "picked apps' packages installed (renamed nixpkgs attributes)" =
    hasAll [ "libreoffice" "kdenlive" "bitwarden-desktop" "parsec-bin" "moonlight-qt" "wine-wow64"
      "gnome-calendar" "gnome-online-accounts-gtk" "photocraft" "gridcraft" "obsidian" ] (sysNames all);
  "browsers go to the user's profile, not the system" =
    hasAll [ "firefox" "chromium" "brave" "librewolf" ] (homeNames all)
    && hasNone [ "firefox" "chromium" "brave" "librewolf" ] (sysNames all)
    && builtins.elem "firefox" (homeNames full) && !(builtins.elem "chromium" (homeNames full));
  "unpicked apps are not installed" =
    hasNone [ "libreoffice" "spotify" ] (sysNames full) && builtins.elem "obsidian" (sysNames full);

  # --- system-level apps ---------------------------------------------------------------------
  "docker: service on, user in the docker group" =
    docker.virtualisation.docker.enable && builtins.elem "docker" (groupsOf docker)
    && !full.virtualisation.docker.enable && !(builtins.elem "docker" (groupsOf full));
  "localsend: 53317 open for TCP and UDP" =
    builtins.elem 53317 (tcp localsend) && builtins.elem 53317 (udp localsend)
    && !(builtins.elem 53317 (tcp full));
  "sunshine: service with KMS capture, avahi on, nusku-arch's ports (settings page stays local)" =
    sunshine.services.sunshine.enable && sunshine.services.sunshine.capSysAdmin
    && sunshine.services.sunshine.autoStart
    && sunshine.services.avahi.enable
    && !sunshine.services.avahi.settings.publish."disable-user-service-publishing"
    && hasAll [ 47984 47989 48010 ] (tcp sunshine) && !(builtins.elem 47990 (tcp sunshine))
    && hasAll [ 47998 47999 48000 48002 48010 5353 ] (udp sunshine);
  "moonlight: mDNS replies allowed in" = builtins.elem 5353 (udp (pick [ "moonlight" ]));
  "wayvnc: installed, VNC port stays closed" =
    let c = pick [ "wayvnc" ]; in builtins.elem "wayvnc" (sysNames c) && !(builtins.elem 5900 (tcp c));
  "steam: programs.steam, gamescope, 32-bit audio" =
    let c = pick [ "steam" ]; in c.programs.steam.enable && c.programs.gamescope.enable
    && c.services.pipewire.alsa.support32Bit && !min.services.pipewire.alsa.support32Bit;
  "gamemode: programs.gamemode, user in the gamemode group" =
    let c = pick [ "gamemode" ]; in c.programs.gamemode.enable && builtins.elem "gamemode" (groupsOf c);
  "zathura: PDF default, only the mupdf plugin" =
    let c = pick [ "zathura" ]; in
    (mime c)."application/pdf" == "org.pwmt.zathura.desktop"
    && builtins.any (p: (p.pname or "") == "zathura-with-plugins"
      && builtins.any (q: lib.hasInfix "zathura-pdf-mupdf" (toString q)) p.paths
      && !(builtins.any (q: lib.hasInfix "zathura-cb" (toString q)) p.paths)) c.environment.systemPackages
    && !(mime full ? "application/pdf");
  "snapper on btrfs /home: /home config with timeline, .snapshots subvolume" =
    let h = all.services.snapper.configs.home or { }; in
    h.SUBVOLUME or "" == "/home" && h.ALLOW_USERS or [ ] == [ "appy" ]
    && h.TIMELINE_CREATE or false && h.TIMELINE_CLEANUP or false
    && builtins.elem "v /home/.snapshots 0750 root root -" all.systemd.tmpfiles.rules;
  "snapper on ext4: nothing configured, a warning instead" =
    snapperExt4.services.snapper.configs == { }
    && builtins.elem "Snapper was skipped: /home is not its own btrfs mount." snapperExt4.warnings
    && !(builtins.any (w: lib.hasInfix "Snapper" w) all.warnings);

  # --- default browser -----------------------------------------------------------------------
  "first picked browser opens links" =
    (mime full)."x-scheme-handler/https" == "firefox.desktop"
    && (mime all)."x-scheme-handler/http" == "firefox.desktop"
    && (mime (pick [ "chromium" "brave" ]))."text/html" == "chromium-browser.desktop"
    && (mime (pick [ "brave" ]))."x-scheme-handler/https" == "brave-browser.desktop"
    && (mime (pick [ "librewolf" ]))."x-scheme-handler/https" == "librewolf.desktop"
    && !(mime min ? "x-scheme-handler/https");
}
