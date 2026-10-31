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
  obsidianThemes = c: map (t: t.pkg) ((hmOf c).programs.obsidian.defaultSettings.themes or [ ]);
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
  "firefox: Firefox Color itself installed by policy" =
    hm.programs.firefox.policies.ExtensionSettings.${colorId}.installation_mode or ""
    == "force_installed";
  "firefox: installed once, in the user's profile" =
    count "firefox" (homeNames full) == 1 && count "firefox" (homeNames all) == 1
    && !(builtins.elem "firefox" (sysNames all));
  "firefox: no Firefox or catppuccin warnings" =
    !(builtins.any (w: lib.hasInfix "irefox" w) (full.warnings ++ hm.warnings));

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
  "obsidian: HM programs.obsidian with catppuccin's theme as the vault default" =
    hm.programs.obsidian.enable && hm.catppuccin.obsidian.enable
    && obsidianThemes full == [ hm.catppuccin.sources.obsidian ];
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
