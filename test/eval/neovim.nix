# Named eval assertions (flake check `eval-neovim`): language runtimes (modules/nixos/langs.nix),
# Neovim's LazyVim config without Mason and the language tools (modules/home/neovim.nix).
{ hosts, catalogue, lib, pkgs, ... }:
let
  langs = import ../../lib/langs.nix pkgs;
  # vm-full (every language, no Neovim) with these apps and languages picked instead.
  pick = apps: ls: (hosts.vm-full.extendModules {
    modules = [{ nusku.apps = lib.mkForce apps; nusku.langs = lib.mkForce ls; }];
  }).config;
  full = hosts.vm-full.config;
  py = pick [ "neovim" ] [ "python" ];
  hmOf = c: c.home-manager.users.${c.nusku.user};
  nameOf = p: p.pname or p.name or "";
  homeNames = c: map nameOf (hmOf c).home.packages;
  sysNames = c: map nameOf c.environment.systemPackages;
  hasHome = n: c: builtins.elem n (homeNames c);
  hasSys = n: c: builtins.elem n (sysNames c);
  cfgFile = c: name: (hmOf c).xdg.configFile.${name} or { };
  cfgText = c: name: (cfgFile c name).text or "";
  read = f: if builtins.pathExists f then builtins.readFile f else "";
  has = lib.hasInfix;
  noCtx = builtins.unsafeDiscardStringContext;
  nvimDir = ../../config/nvim;
  nuskuNix = read ../../config/nvim/lua/plugins/nusku-nix.lua;
  rustupStep = c: (hmOf c).home.activation.nuskuRustup or null;
  # Every package lib/langs.nix names, with the language it belongs to.
  allLangPkgs = langs.core ++ lib.concatMap (l: l.runtime ++ l.tools) (builtins.attrValues langs.langs);
  rustAnalyzer = n: lib.hasPrefix "rust-analyzer" n;
in
{
  # --- lib/langs.nix -------------------------------------------------------------------------
  "langs: every catalogue language has runtime and tools, and nothing else is listed" =
    builtins.attrNames langs.langs == lib.sort (a: b: a < b) (map (l: l.id) catalogue.langs)
    && builtins.all (l: l ? runtime && l ? tools) (builtins.attrValues langs.langs);
  "langs: every package evaluates (drvPath forced)" =
    builtins.all (p: lib.isDerivation p && builtins.isString p.drvPath) allLangPkgs;

  # --- runtimes ------------------------------------------------------------------------------
  "runtimes: each picked language's runtime is a system package, Neovim or not" =
    builtins.all (p: builtins.elem p full.environment.systemPackages)
      (lib.concatMap (l: l.runtime) (builtins.attrValues langs.langs));
  "runtimes: none without languages" =
    let none = pick [ ] [ ]; in # (the neovim app brings nodejs itself)
    !(builtins.any (p: builtins.elem p none.environment.systemPackages)
      (lib.concatMap (l: l.runtime) (builtins.attrValues langs.langs)));
  "python: python3 and uv are system packages" = hasSys "python3" py && hasSys "uv" py;

  # --- tools (Neovim picked) -----------------------------------------------------------------
  "python + neovim: basedpyright and ruff in the user's packages" =
    hasHome "basedpyright" py && hasHome "ruff" py;
  "python + neovim: no rust-analyzer, no other language's tools" =
    !(builtins.any rustAnalyzer (homeNames py ++ sysNames py))
    && !(hasHome "gopls" py) && !(hasHome "vtsls" py) && !(hasHome "phpactor" py);
  "neovim: core tools (lua_ls, stylua, shfmt) and git for lazy.nvim" =
    builtins.all (n: hasHome n py) [ "lua-language-server" "stylua" "shfmt" "git" ];
  "all languages + neovim: every language's tools in the user's packages" =
    let all = pick [ "neovim" ] (map (l: l.id) catalogue.langs); in
    builtins.all (p: builtins.elem p (hmOf all).home.packages)
      (lib.concatMap (l: l.tools) (builtins.attrValues langs.langs));
  "no neovim: no language tools, no nvim config (runtimes only)" =
    !(hasHome "basedpyright" full) && !(hasHome "lua-language-server" full)
    && cfgFile full "nvim" == { } && cfgFile full "nusku/nvim-languages.lua" == { }
    && hasSys "python3" full;

  # --- the LazyVim config --------------------------------------------------------------------
  "nvim: nusku-arch's config linked file by file (the dir stays writable for lazyvim.json)" =
    (cfgFile py "nvim").source or null == nvimDir && (cfgFile py "nvim").recursive or false;
  "nvim: languages file is exactly the picked list" =
    cfgText py "nusku/nvim-languages.lua" == ''
      return { "python" }
    '';
  "nvim: languages file in catalogue order; empty list without languages" =
    cfgText (pick [ "neovim" ] [ "lua" "go" "python" ]) "nusku/nvim-languages.lua" == ''
      return { "python", "go", "lua" }
    ''
    && cfgText (pick [ "neovim" ] [ ]) "nusku/nvim-languages.lua" == ''
      return {}
    '';
  "nvim: Mason and mason-lspconfig disabled" =
    has ''{ "mason-org/mason.nvim", enabled = false }'' nuskuNix
    && has ''{ "mason-org/mason-lspconfig.nvim", enabled = false }'' nuskuNix
    && !(has "mason" (read ../../config/nvim/lazy-lock.json));
  "nvim: no Mason step left in the headless sync" =
    !(has "mason" (read ../../config/nvim/lua/nusku/sync.lua));
  "nvim: treesitter from Nix: no parser installs or builds, install_dir from nvim-nix.lua" =
    has "opts.ensure_installed = {}" nuskuNix && has "build = false" nuskuNix
    && has "opts.install_dir = nix.parsers" nuskuNix
    && !(has "ensure_installed = {" (read ../../config/nvim/lua/plugins/nusku-gdscript.lua))
    && !(has "nvim-treesitter" (read ../../config/nvim/lazy-lock.json));
  "nvim: nvim-nix.lua names nixpkgs' nvim-treesitter, textobjects and the grammar dir" =
    let t = noCtx (cfgText py "nusku/nvim-nix.lua"); in
    has ''treesitter = "${noCtx pkgs.vimPlugins.nvim-treesitter}"'' t
    && has ''textobjects = "${noCtx pkgs.vimPlugins.nvim-treesitter-textobjects}"'' t
    && has ''parsers = "/nix/store/'' t && has "nvim-treesitter-grammars" t
    && !(has "lombok" t);
  "nvim: java picked: Lombok jar path for jdtls" =
    has "lombok = \"${noCtx pkgs.lombok}/share/java/lombok.jar\""
      (noCtx (cfgText (pick [ "neovim" ] [ "java" ]) "nusku/nvim-nix.lua"));
  "nvim: lazy.nvim keeps a writable lockfile copy (store files are read-only)" =
    has "fs_chmod" (read ../../config/nvim/lua/nusku/lockfile.lua);
  "nvim: accent file rendered from the palette" =
    has "#89b4fa" (cfgText py "nusku/theme/nvim-accent.lua");
  "nvim: Python server is basedpyright (vim.g.lazyvim_python_lsp kept)" =
    has ''vim.g.lazyvim_python_lsp = "basedpyright"'' (read ../../config/nvim/lua/config/options.lua);

  # --- rustup --------------------------------------------------------------------------------
  "rust picked: rustup default + components once, never failing the switch" =
    let a = (rustupStep (pick [ ] [ "rust" ])).data or ""; in
    has "grep -q '(default)'" a && has "default stable" a
    && has "component add" a && has "rust-analyzer" a && has "rustfmt" a
    && has "warnEcho" a && has "${noCtx pkgs.rustup}/bin/rustup" (noCtx a);
  "rust not picked: no rustup step" = rustupStep py == null;
}
