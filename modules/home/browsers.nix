# The picked web browsers and Obsidian, in the user's profile, themed with Catppuccin
# (modules/nixos/apps.nix lists the browser packages and makes the first one open links).
#  - Firefox: HM programs.firefox with one `default` profile; catppuccin/nix themes it through
#    the Firefox Color extension (Mocha in the host accent), installed by policy from a pinned
#    copy in the Nix store.
#  - Chromium and Brave: HM programs.chromium/brave; catppuccin/nix adds its Mocha theme
#    extension, which the browser fetches from the Chrome Web Store (no accent there).
#  - LibreWolf: a plain package, left default.
#  - Obsidian: HM programs.obsidian installs it; nusku-obsidian-theme copies catppuccin/nix's
#    Obsidian theme into every vault Obsidian knows and selects it where the vault has no theme
#    chosen (on each rebuild and each login).
{ osConfig, config, lib, pkgs, ... }:
let
  inherit (lib) mkIf;
  scripts = import ../../lib/scripts.nix { inherit pkgs lib; };
  catalogue = import ../../lib/catalogue.nix;
  picked = id: builtins.elem id osConfig.nusku.apps;
  packagesOf = id: osConfig.nusku.internal.apps.packages.${id};
  # Browsers with a Home Manager module below; the other picked browsers are plain packages.
  viaModule = [ "firefox" "chromium" "brave" ];
  plainBrowsers = builtins.filter
    (a: (a.browser or false) && picked a.id && !(builtins.elem a.id viaModule)) catalogue.apps;
  # The one package apps.nix lists for a browser handled by an HM module.
  packageOf = id: builtins.head (packagesOf id);

  # Firefox Color, pinned (AMO's current version, file 3643624).
  colorId = "FirefoxColor@mozilla.com";
  firefoxColor = pkgs.fetchurl {
    url = "https://addons.mozilla.org/firefox/downloads/file/3643624/firefox_color-2.1.7.xpi";
    hash = "sha256-t/sHtniPcjPdYiPngOGJtMe5VsJcQEk8KNcCBJMkkpI=";
  };

  nusku-obsidian-theme = scripts.mkScript {
    name = "nusku-obsidian-theme";
    deps = with pkgs; [ coreutils jq ];
    env.NUSKU_OBSIDIAN_THEME = "${config.catppuccin.sources.obsidian}";
  };
in
{
  home.packages = lib.concatMap (a: packagesOf a.id) plainBrowsers
    ++ lib.optional (picked "obsidian") nusku-obsidian-theme;

  programs.firefox = mkIf (picked "firefox") {
    enable = true;
    package = packageOf "firefox";
    # A new profile under ~/.config/mozilla/firefox (HM's path for stateVersion 26.05).
    profiles.default = {
      id = 0;
      isDefault = true;
    };
    # catppuccin/nix only writes Firefox Color's settings; the extension itself comes from the
    # store, enabled on install (a policy, as HM's globalExtensions does).
    policies.ExtensionSettings.${colorId} = {
      install_url = "file://${firefoxColor}";
      installation_mode = "force_installed";
    };
  };
  # Accent and flavour come from the global catppuccin settings (modules/home/default.nix).
  # `force`: HM may replace Firefox Color's storage.js in that profile (it asserts this).
  catppuccin.firefox = mkIf (picked "firefox") {
    enable = true;
    force = true;
  };

  programs.chromium = mkIf (picked "chromium") {
    enable = true;
    package = packageOf "chromium";
  };
  catppuccin.chromium.enable = picked "chromium";

  programs.brave = mkIf (picked "brave") {
    enable = true;
    package = packageOf "brave";
  };
  catppuccin.brave.enable = picked "brave";

  # Obsidian (an everyday app, not a browser) lives here because its theming sits with the
  # others; apps.nix lists it as handled in Home Manager.
  programs.obsidian.enable = picked "obsidian";
  # catppuccin/nix's module would only theme vaults declared in programs.obsidian.vaults, as
  # read-only files; nusku-obsidian-theme themes every vault instead, with the same theme.
  catppuccin.obsidian.enable = false;
  # On each rebuild (after obsidian.json is merged) and at each login (autostart below), so a
  # vault made after a rebuild is themed at the next login. A vault it can't do is reported
  # and skipped; that never fails the switch.
  home.activation.nuskuObsidianTheme = mkIf (picked "obsidian")
    (lib.hm.dag.entryAfter [ "linkGeneration" "obsidian" ] ''
      run ${nusku-obsidian-theme}/bin/nusku-obsidian-theme || true
    '');
  # Included by niri's config.kdl (Nix-written startup commands and binds for picked apps).
  xdg.configFile."nusku/apps.kdl" = mkIf (picked "obsidian") {
    text = ''
      // Obsidian: Catppuccin in vaults made since the last rebuild (modules/home/browsers.nix).
      spawn-at-startup "nusku-obsidian-theme"
    '';
  };
}
