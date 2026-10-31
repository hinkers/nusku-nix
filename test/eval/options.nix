# Named eval assertions (flake check `eval-options`): every name must evaluate to true.
{ self, hosts, catalogue, lib, ... }:
let
  min = hosts.vm-min.config;
  full = hosts.vm-full.config;
  ids = xs: map (x: x.id) xs;
  groupIds = ids catalogue.groups;
in
{
  "vm-min hostName comes from settings" = min.networking.hostName == "vm-min";
  "vm-min optional keys take defaults" =
    min.nusku.timezone == "UTC" && min.nusku.locale == "en_US.UTF-8" && min.nusku.keymap == "us"
    && min.nusku.boot == { loader = "systemd-boot"; device = null; }
    && min.nusku.nvidia == null && min.nusku.prime == null
    && min.nusku.panels == [ ] && min.nusku.apps == [ ] && min.nusku.langs == [ ];
  "vm-full settings reach nusku options" =
    full.nusku.user == "nathan" && full.nusku.accent == "blue" && full.nusku.gpu == "vm"
    && full.nusku.timezone == "Australia/Brisbane" && full.nusku.locale == "en_AU.UTF-8"
    && full.nusku.apps == [ "firefox" "obsidian" ] && builtins.elem "rust" full.nusku.langs;
  "vm-full panel scale is 1.25" = (builtins.head full.nusku.panels).scale == 1.25;
  "fixtures are not nixosConfigurations" =
    !(self.nixosConfigurations ? vm-min) && !(self.nixosConfigurations ? vm-full);
  "catalogue app ids are unique" = lib.unique (ids catalogue.apps) == ids catalogue.apps;
  "catalogue lang ids are unique" = lib.unique (ids catalogue.langs) == ids catalogue.langs;
  "catalogue apps belong to known groups" =
    builtins.all (a: builtins.elem a.group groupIds) catalogue.apps;
}
