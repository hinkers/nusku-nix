# Named eval assertions (flake check `eval-hyperv`): the Hyper-V test VM's NAME-hyperv-test
# variants (test/hyperv/hosts.nix + guest.nix). The variant the loop installs has sshd with keys
# only, passwordless sudo, KVP and autologin; every real host has none of it, and only gpu "vm"
# hosts get a variant at all.
{ hosts, hypervHosts, mkHypervHosts, lib, ... }:
let
  test = hypervHosts.hyperv-small-hyperv-test.config;
  full = hypervHosts.hyperv-full-hyperv-test.config;

  # Real hosts: the harness's own fixtures without the variant, a plain VM host, a laptop.
  real = map (n: hosts.${n}.config) [ "hyperv-small" "hyperv-full" "vm-min" "installer-laptop" "gpu-amd" ];

  nopasswd = cfg: builtins.any
    (r: builtins.any (c: builtins.elem "NOPASSWD" (c.options or [ ])) r.commands)
    cfg.security.sudo.extraRules;
  nopasswdFor = user: cfg: builtins.any
    (r: builtins.elem user (r.users or [ ])
      && builtins.any (c: c.command == "ALL" && builtins.elem "NOPASSWD" (c.options or [ ])) r.commands)
    cfg.security.sudo.extraRules;
  sshdKeysOnly = cfg:
    cfg.services.openssh.enable
    && cfg.services.openssh.settings.PasswordAuthentication == false
    && cfg.services.openssh.settings.KbdInteractiveAuthentication == false
    && cfg.services.openssh.settings.PermitRootLogin == "no";
  failedAssertions = cfg: map (a: a.message) (builtins.filter (a: !a.assertion) cfg.assertions);

  # A variant for every fixture host, gpu "vm" or not (hosts.nix `all`).
  forced = mkHypervHosts { dir = ../fixtures/hosts; all = true; };
  hasGuestRefusal = cfg: builtins.any (m: lib.hasInfix "Hyper-V test VM only" m) (failedAssertions cfg);
in
{
  "hyperv: the test variant has sshd with keys only, port 22 open" =
    sshdKeysOnly test && test.services.openssh.openFirewall
    && builtins.elem 22 test.services.openssh.ports;
  "hyperv: sshd reads ~/.ssh/authorized_keys (the key from the base install)" =
    test.services.openssh.authorizedKeysInHomedir
    && builtins.elem "%h/.ssh/authorized_keys" test.services.openssh.authorizedKeysFiles;
  "hyperv: passwordless sudo for the host's user (tester)" =
    test.nusku.user == "tester" && nopasswdFor "tester" test;
  "hyperv: Hyper-V guest services (KVP reports the IP)" = test.virtualisation.hypervGuest.enable;
  "hyperv: SDDM autologin into Hyprland as the user" =
    test.services.displayManager.autoLogin.enable
    && test.services.displayManager.autoLogin.user == "tester"
    && test.services.displayManager.defaultSession == "hyprland";
  "hyperv: nusku-rebuild in the VM keeps building the variant (NUSKU_FLAKE_ATTR)" =
    (test.environment.variables.NUSKU_FLAKE_ATTR or null) == "hyperv-small-hyperv-test";
  "hyperv: the full variant has the same test access" =
    sshdKeysOnly full && nopasswdFor "tester" full && full.services.displayManager.autoLogin.enable;
  "hyperv: the variant is the host plus guest.nix (same apps, langs, accent)" =
    test.nusku.apps == hosts.hyperv-small.config.nusku.apps
    && test.nusku.langs == hosts.hyperv-small.config.nusku.langs
    && test.networking.hostName == "hyperv-small";

  # test/hyperv/Invoke-NuskuNixTest.ps1 looks for this id ($catppuccinCrx) in External Extensions.
  "hyperv: catppuccin/nix's Chromium/Brave extension id is the one the harness checks" =
    let
      hm = full.home-manager.users.${full.nusku.user};
      ids = p: map (e: e.id) p.extensions;
    in
    builtins.elem "bkkmolkhemgaeaeggcmfbghljjjoofoh" (ids hm.programs.chromium)
    && builtins.elem "bkkmolkhemgaeaeggcmfbghljjjoofoh" (ids hm.programs.brave);

  "hyperv: real hosts have no sshd" = builtins.all (c: !c.services.openssh.enable) real;
  "hyperv: real hosts have no NOPASSWD sudo and wheel needs a password" =
    builtins.all (c: !(nopasswd c) && c.security.sudo.wheelNeedsPassword) real;
  "hyperv: real hosts have no autologin" =
    builtins.all (c: !c.services.displayManager.autoLogin.enable) real;
  "hyperv: real hosts have no NUSKU_FLAKE_ATTR" =
    builtins.all (c: !(c.environment.variables ? NUSKU_FLAKE_ATTR)) real;

  "hyperv: only gpu \"vm\" hosts get a variant" =
    hypervHosts ? vm-min-hyperv-test && hypervHosts ? hyperv-small-hyperv-test
    && !(hypervHosts ? gpu-amd-hyperv-test) && !(hypervHosts ? installer-laptop-hyperv-test)
    && !(hypervHosts ? gpu-nvidia-open-hyperv-test)
    && builtins.all (n: lib.hasSuffix "-hyperv-test" n) (builtins.attrNames hypervHosts);
  "hyperv: guest.nix refuses a real-hardware host" =
    hasGuestRefusal forced.gpu-amd-hyperv-test.config
    && hasGuestRefusal forced.installer-laptop-hyperv-test.config
    && !(hasGuestRefusal test);
}
