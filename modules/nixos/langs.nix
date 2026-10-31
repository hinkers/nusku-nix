# The languages picked in settings.json "langs": each one's runtime and package manager
# (lib/langs.nix), installed whether or not Neovim is picked, as on nusku-arch. Their language
# servers, formatters and linters come with Neovim (modules/home/neovim.nix).
{ config, lib, pkgs, ... }:
let
  langs = (import ../../lib/langs.nix pkgs).langs;
in
{
  environment.systemPackages = lib.concatMap (id: langs.${id}.runtime or [ ]) config.nusku.langs;
}
