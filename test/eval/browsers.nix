# Named eval assertions (flake check `eval-browsers`): Catppuccin for the picked browsers and
# Obsidian (modules/home/browsers.nix), through catppuccin/nix.
{ hosts, lib, ... }:
let
  full = hosts.vm-full.config; # apps: firefox, obsidian; accent blue
  all = hosts.vm-apps.config; # every catalogue app
  # vm-full with only these apps picked (and optionally another accent).
  pickA = accent: apps: (hosts.vm-full.extendModules {
    modules = [{ nusku.apps = lib.mkForce apps; nusku.accent = lib.mkForce accent; }];
  }).config;
  pick = pickA "blue";
  hmOf = c: c.home-manager.users.${c.nusku.user};
  hm = hmOf full;
  homeNames = c: map (p: p.pname or p.name or "") (hmOf c).home.packages;
  sysNames = c: map (p: p.pname or p.name or "") c.environment.systemPackages;
  count = x: xs: builtins.length (builtins.filter (y: y == x) xs);
  files = c: builtins.attrNames (hmOf c).home.file;
  hasFile = suffix: c: builtins.any (lib.hasSuffix suffix) (files c);

  # Firefox: catppuccin/nix writes Firefox Color's settings into the profile.
  colorId = "FirefoxColor@mozilla.com";
  ffColor = c: (hmOf c).programs.firefox.profiles.default.extensions.settings.${colorId}.settings or { };
  ffStorage = "/default/browser-extension-data/${colorId}/storage.js";
  mauve = pickA "mauve" [ "firefox" ];
  # catppuccin/nix's Chromium-family theme extension for Mocha (Chrome Web Store id).
  mochaExt = "bkkmolkhemgaeaeggcmfbghljjjoofoh";
  extIds = c: browser: map (e: e.id) (hmOf c).programs.${browser}.extensions;
  chromium = pick [ "chromium" ];
  brave = pick [ "brave" ];
  librewolf = pick [ "librewolf" ];
  none = pick [ ];
  # nusku-obsidian-theme (in the user's packages), its activation step and its autostart.
  themer = c: lib.findFirst (p: (p.pname or p.name or "") == "nusku-obsidian-theme") null
    (hmOf c).home.packages;
  activation = c: (hmOf c).home.activation.nuskuObsidianTheme or null;
  autostart = c: (hmOf c).xdg.configFile."nusku/autostart.lua".text or "";
  obsidianOnly = pick [ "obsidian" ];
  noCtx = builtins.unsafeDiscardStringContext; # hasInfix can't take store-path strings
in
{
  # --- Firefox -------------------------------------------------------------------------------
  "firefox: HM programs.firefox with one default profile" =
    hm.programs.firefox.enable
    && builtins.attrNames hm.programs.firefox.profiles == [ "default" ]
    && hm.programs.firefox.profiles.default.isDefault;
  "firefox: catppuccin on for the default profile, Mocha in the host accent" =
    let p = hm.catppuccin.firefox.profiles.default; in
    p.enable && p.flavor == "mocha" && p.accent == "blue"
    && (hmOf mauve).catppuccin.firefox.profiles.default.accent == "mauve";
  "firefox: Firefox Color theme written to the profile, and it follows the accent" =
    (ffColor full).firstRunDone or false && (ffColor full) ? theme
    && (ffColor mauve) ? theme && (ffColor full).theme != (ffColor mauve).theme
    && hasFile ffStorage full;
  "firefox: Firefox Color itself installed by policy, from a pinned copy in the store" =
    let e = hm.programs.firefox.policies.ExtensionSettings.${colorId} or { }; in
    e.installation_mode or "" == "force_installed"
    && lib.hasPrefix "file:///nix/store/" (e.install_url or "")
    && lib.hasSuffix "-firefox_color-2.1.7.xpi" e.install_url;
  "firefox: installed once, in the user's profile" =
    count "firefox" (homeNames full) == 1 && count "firefox" (homeNames all) == 1
    && !(builtins.elem "firefox" (sysNames all));
  "firefox: no Firefox or catppuccin warnings" =
    !(builtins.any (w: lib.hasInfix "firefox" (lib.toLower w)) (full.warnings ++ hm.warnings));

  # --- Chromium and Brave --------------------------------------------------------------------
  "chromium: HM programs.chromium with catppuccin's Mocha extension" =
    (hmOf chromium).programs.chromium.enable && (hmOf chromium).catppuccin.chromium.enable
    && extIds chromium "chromium" == [ mochaExt ]
    && hasFile "chromium/External Extensions/${mochaExt}.json" chromium;
  "brave: HM programs.brave with catppuccin's Mocha extension" =
    (hmOf brave).programs.brave.enable && (hmOf brave).catppuccin.brave.enable
    && extIds brave "brave" == [ mochaExt ]
    && hasFile "Brave-Browser/External Extensions/${mochaExt}.json" brave;
  "chromium and brave: installed once each" =
    count "chromium" (homeNames all) == 1 && count "brave" (homeNames all) == 1
    && count "chromium" (homeNames chromium) == 1;

  # --- LibreWolf (left default) --------------------------------------------------------------
  "librewolf: plain package, not themed" =
    count "librewolf" (homeNames librewolf) == 1 && !(hmOf librewolf).programs.librewolf.enable
    && count "librewolf" (homeNames all) == 1;

  # --- Obsidian ------------------------------------------------------------------------------
  "obsidian: HM programs.obsidian installs it; catppuccin/nix's HM-vault theming is off" =
    hm.programs.obsidian.enable && !hm.catppuccin.obsidian.enable
    && hm.programs.obsidian.defaultSettings.themes == null
    && !(builtins.any (lib.hasInfix ".obsidian/") (files full));
  "obsidian: nusku-obsidian-theme with jq on its PATH and catppuccin's theme" =
    themer full != null
    && builtins.any (l: lib.hasPrefix "export PATH=" l && lib.hasInfix "-jq-" l)
      (lib.splitString "\n" (themer full).drvAttrs.text)
    && lib.hasInfix (noCtx "NUSKU_OBSIDIAN_THEME=${hm.catppuccin.sources.obsidian}")
      (themer full).drvAttrs.text;
  "obsidian: themed on each rebuild, after obsidian.json is merged; never fails the switch" =
    let a = activation full; in
    a != null && builtins.elem "linkGeneration" a.after && builtins.elem "obsidian" a.after
    && lib.hasInfix (noCtx "${themer full}/bin/nusku-obsidian-theme || true") a.data;
  "obsidian: themed at each login (Hyprland autostart, loaded by hyprland.lua)" =
    lib.hasInfix ''hl.exec_cmd("nusku-obsidian-theme")'' (autostart full)
    && lib.hasInfix "hyprland.start" (autostart full)
    && lib.hasInfix ''require_if_present(paths.nusku .. "/autostart")''
      (builtins.readFile ../../config/hypr/hyprland.lua);
  "obsidian not picked: no themer, activation step or autostart" =
    builtins.all (c: themer c == null && activation c == null && autostart c == "")
      [ none mauve chromium ]
    && themer obsidianOnly != null && activation obsidianOnly != null;
  "obsidian: installed once, in the user's profile" =
    count "obsidian" (homeNames full) == 1 && !(builtins.elem "obsidian" (sysNames full))
    && !(builtins.elem "obsidian" (sysNames all));

  # --- nothing picked ------------------------------------------------------------------------
  "none picked: no browser or Obsidian modules, themes or packages" =
    let h = hmOf none; in
    !h.programs.firefox.enable && !h.programs.chromium.enable && !h.programs.brave.enable
    && !h.programs.obsidian.enable
    && !(builtins.any (f: lib.hasInfix colorId f || lib.hasInfix "External Extensions" f) (files none))
    && builtins.all (n: !(builtins.elem n (homeNames none)))
      [ "firefox" "chromium" "brave" "librewolf" "obsidian" ];
  "only firefox picked: chromium, brave and obsidian stay off" =
    let h = hmOf mauve; in
    !h.programs.chromium.enable && !h.programs.brave.enable && !h.programs.obsidian.enable;
}
