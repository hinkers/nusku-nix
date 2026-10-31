# The picked web browsers and Obsidian, in the user's profile, themed by catppuccin/nix
# (modules/nixos/apps.nix lists the browser packages and makes the first one open links).
#  - Firefox: HM programs.firefox with one `default` profile; catppuccin/nix themes it through
#    the Firefox Color extension (Mocha in the host accent), which a policy installs.
#  - Chromium and Brave: HM programs.chromium/brave; catppuccin/nix adds its Mocha theme
#    extension from the Chrome Web Store (no accent there).
#  - LibreWolf: a plain package, left default.
#  - Obsidian: HM programs.obsidian; catppuccin/nix makes its theme the default for vaults that
#    HM declares (programs.obsidian.vaults; none yet). Other vaults pick it from Obsidian's
#    community themes (README).
{ osConfig, lib, ... }:
let
  inherit (lib) mkIf;
  catalogue = import ../../lib/catalogue.nix;
  picked = id: builtins.elem id osConfig.nusku.apps;
  packagesOf = id: osConfig.nusku.internal.apps.packages.${id};
  # Browsers with a Home Manager module below; the other picked browsers are plain packages.
  viaModule = [ "firefox" "chromium" "brave" ];
  plainBrowsers = builtins.filter
    (a: (a.browser or false) && picked a.id && !(builtins.elem a.id viaModule)) catalogue.apps;
  # The one package apps.nix lists for a browser handled by an HM module.
  packageOf = id: builtins.head (packagesOf id);
  colorId = "FirefoxColor@mozilla.com";
in
{
  home.packages = lib.concatMap (a: packagesOf a.id) plainBrowsers;

  programs.firefox = mkIf (picked "firefox") {
    enable = true;
    package = packageOf "firefox";
    # A new profile under ~/.config/mozilla/firefox (HM's path for stateVersion 26.05).
    profiles.default = {
      id = 0;
      isDefault = true;
    };
    # catppuccin/nix only writes Firefox Color's settings; the extension comes from AMO.
    policies.ExtensionSettings.${colorId} = {
      install_url = "https://addons.mozilla.org/firefox/downloads/latest/firefox-color/latest.xpi";
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

  # Obsidian (an everyday app, not a browser) lives here because its theming is the same kind
  # of catppuccin/nix module; apps.nix lists it as handled in Home Manager.
  programs.obsidian.enable = picked "obsidian";
  catppuccin.obsidian.enable = picked "obsidian";
}
