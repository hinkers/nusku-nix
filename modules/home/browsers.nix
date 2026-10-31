# The picked web browsers, installed in the user's profile (modules/nixos/apps.nix lists their
# packages and makes the first one open links). Browser theming belongs here too.
{ osConfig, lib, ... }:
let
  catalogue = import ../../lib/catalogue.nix;
  browsers = builtins.filter (a: (a.browser or false) && builtins.elem a.id osConfig.nusku.apps)
    catalogue.apps;
in
{
  home.packages = lib.concatMap (a: osConfig.nusku.internal.apps.packages.${a.id}) browsers;
}
