# The installer (install.sh) side of the flake. test/unit/install.bats checks that a first run
# writes exactly test/fixtures/hosts/installer-laptop/settings.json; evaluating that fixture
# (check installer-laptop) proves what the installer writes passes the settings.json validation.
{ hosts, catalogue, ... }:
let
  laptop = hosts.installer-laptop.config;
in
{
  "test/fixtures/catalogue.json (the unit tests' copy of `nix eval --json .#lib.catalogue`) is lib.catalogue" =
    builtins.fromJSON (builtins.readFile ../fixtures/catalogue.json) == catalogue;
  "the installer's hybrid laptop gets its PRIME bus IDs" =
    laptop.hardware.nvidia.prime.intelBusId == "PCI:0:2:0"
    && laptop.hardware.nvidia.prime.nvidiaBusId == "PCI:1:0:0";
  "the installer's laptop screen scale is read" =
    laptop.nusku.panels == [ { output = "eDP-1"; scale = 1.25; } ];
  "the installer's apps are the ★ picks" =
    laptop.nusku.apps == map (a: a.id) (builtins.filter (a: a.star or false) catalogue.apps);
}
