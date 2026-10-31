# Named eval assertions (flake check `eval-home-paths`): lib/home-paths.txt, the static list of
# what Nusku's Home Manager config puts in a home, which install.sh checks before a build
# (lib/sh/home-check.sh), matches the Home Manager config. Every home.file target of the fixture
# hosts (between them: every app, every language, both Firefox profile locations, several
# accents) is covered by an entry, and every entry covers a target of one of them.
{ hosts, lib, ... }:
let
  entries = builtins.filter (l: l != "" && !(lib.hasPrefix "#" l))
    (lib.splitString "\n" (builtins.readFile ../../lib/home-paths.txt));
  hmOf = c: c.home-manager.users.${c.nusku.user};
  targetsOf = c: map (f: f.target) (builtins.attrValues (hmOf c).home.file);
  # hyperv-full: every app and language; vm-full: panels, Firefox; vm-min: nothing picked;
  # hyperv-small: another accent. An install from before 26.05 keeps home.stateVersion 26.05, so
  # Firefox's profile stays under ~/.config/mozilla.
  targets = lib.unique (lib.concatMap (n: targetsOf hosts.${n}.config)
    [ "hyperv-full" "vm-full" "vm-min" "hyperv-small" "vm-luks" ]);
  # dir/ covers the directory and what is under it; prefix* what starts with prefix; else exact.
  covers = e: t:
    if lib.hasSuffix "/" e then t == lib.removeSuffix "/" e || lib.hasPrefix e t
    else if lib.hasSuffix "*" e then lib.hasPrefix (lib.removeSuffix "*" e) t
    else t == e;
  uncovered = builtins.filter (t: !(builtins.any (e: covers e t) entries)) targets;
  stale = builtins.filter (e: !(builtins.any (covers e) targets)) entries;
in
{
  "home-paths: the list is not empty" = builtins.length entries > 20;
  "home-paths: every Home Manager target is covered by lib/home-paths.txt" =
    lib.warnIf (uncovered != [ ]) "not in lib/home-paths.txt: ${toString uncovered}" (uncovered == [ ]);
  "home-paths: every entry is a Home Manager target (no stale entries)" =
    lib.warnIf (stale != [ ]) "stale in lib/home-paths.txt: ${toString stale}" (stale == [ ]);
  "home-paths: entries are relative to the home, without spaces at either end" =
    builtins.all (e: !(lib.hasPrefix "/" e) && !(lib.hasPrefix "~" e) && lib.trim e == e) entries;
}
