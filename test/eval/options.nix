# Named eval assertions (flake check `eval-options`): every name must evaluate to true.
{ self, hosts, catalogue, lib, ... }:
let
  min = hosts.vm-min.config;
  full = hosts.vm-full.config;
  ids = xs: map (x: x.id) xs;
  groupIds = ids catalogue.groups;
  hmOf = c: c.home-manager.users.${c.nusku.user};
in
{
  "vm-min hostName comes from settings" = min.networking.hostName == "vm-min";
  "vm-min optional keys take defaults" =
    min.nusku.timezone == "UTC" && min.nusku.locale == "en_US.UTF-8" && min.nusku.keymap == "us"
    && min.nusku.boot == { loader = "systemd-boot"; device = null; }
    && min.nusku.nvidia == null && min.nusku.prime == null
    && min.nusku.panels == [ ] && min.nusku.apps == [ ] && min.nusku.langs == [ ]
    && min.nusku.stateVersion == "26.05";
  "vm-full settings reach nusku options" =
    full.nusku.user == "nathan" && full.nusku.accent == "blue" && full.nusku.gpu == "vm"
    && full.nusku.timezone == "Australia/Brisbane" && full.nusku.locale == "en_AU.UTF-8"
    && full.nusku.apps == [ "firefox" "obsidian" ] && builtins.elem "rust" full.nusku.langs;
  # --- stateVersion: the release NixOS was installed with (settings.json "stateVersion") -------
  "stateVersion: the system's is the installed release from settings.json" =
    full.nusku.stateVersion == "25.11" && full.system.stateVersion == "25.11"
    && hosts.vm-luks.config.system.stateVersion == "25.05";
  "stateVersion: hosts recorded before the key existed stay on 26.05 (system and home)" =
    min.system.stateVersion == "26.05" && (hmOf min).home.stateVersion == "26.05";
  # Home Manager's state starts at Nusku's first build, with this flake's Home Manager: its
  # stateVersion is fixed, whatever release NixOS was installed from (a newer ISO's release could
  # be one this Home Manager doesn't know).
  "stateVersion: home is always 26.05; the system follows the recorded release" =
    let at = v: (hosts.vm-full.extendModules { modules = [{ nusku.stateVersion = lib.mkForce v; }]; }).config; in
    (hmOf full).home.stateVersion == "26.05"
    && builtins.all (v: (hmOf (at v)).home.stateVersion == "26.05" && (at v).system.stateVersion == v)
      [ "26.11" "27.05" ];
  "vm-full panel scale is 1.25" = (builtins.head full.nusku.panels).scale == 1.25;
  "fixtures are not nixosConfigurations" =
    !(self.nixosConfigurations ? vm-min) && !(self.nixosConfigurations ? vm-full);
  "catalogue app ids are unique" = lib.unique (ids catalogue.apps) == ids catalogue.apps;
  "catalogue lang ids are unique" = lib.unique (ids catalogue.langs) == ids catalogue.langs;
  "catalogue apps belong to known groups" =
    builtins.all (a: builtins.elem a.group groupIds) catalogue.apps;
}
