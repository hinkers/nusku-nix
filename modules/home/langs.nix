# The user's side of the picked languages (settings.json "langs"; the runtimes are system
# packages, modules/nixos/langs.nix). Neovim's language tools are in neovim.nix.
#
# Rust: nusku-arch's apps_hook_rust, Neovim or not. nusku-rustup gives rustup a stable default
# with rust-analyzer and rustfmt. rustup downloads them (nusku-arch behaviour, named in the plan:
# the one place a toolchain comes from outside Nix), so it runs as a user service in the
# background after login instead of in activation, where a ~300 MB download would hold up boot
# and could time out the switch. It exits at once when everything is there; when a download
# fails (offline) it exits non-zero and systemd tries again a minute later. Restarts 60 s apart
# never reach systemd's start limit (5 starts in 10 s), so it keeps retrying until it succeeds.
{ osConfig, lib, pkgs, ... }:
let
  scripts = import ../../lib/scripts.nix { inherit pkgs lib; };
  nusku-rustup = scripts.mkScript {
    name = "nusku-rustup";
    deps = [ pkgs.rustup pkgs.gnugrep ];
  };
in
{
  systemd.user.services.nusku-rustup = lib.mkIf (builtins.elem "rust" osConfig.nusku.langs) {
    Unit.Description = "Rust stable toolchain with rust-analyzer and rustfmt (rustup)";
    Service = {
      Type = "exec";
      ExecStart = "${nusku-rustup}/bin/nusku-rustup";
      Restart = "on-failure";
      RestartSec = 60;
    };
    Install.WantedBy = [ "default.target" ];
  };
}
