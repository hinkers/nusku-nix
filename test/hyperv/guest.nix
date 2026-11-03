# Hyper-V test VM only (test/hyperv/README.md). Imported by test/hyperv/hosts.nix into the
# NAME-hyperv-test outputs, never into a host's own NAME: what the base install's
# /etc/nixos/configuration.nix gave the VM, which the first `nixos-rebuild switch` to a Nusku
# host would otherwise drop, so the test loop keeps its way in, plus the autologin it relies on.
{ config, ... }:
let
  cfg = config.nusku;
in
{
  assertions = [
    {
      assertion = cfg.gpu == "vm";
      message = "test/hyperv/guest.nix is for the Hyper-V test VM only (gpu \"vm\"); host ${cfg.hostname} has gpu \"${cfg.gpu}\"";
    }
  ];

  # SSH with keys only. The key is the one the base install put in ~/.ssh/authorized_keys (the
  # README's steps), so no key is in the repo; sshd keeps reading that file.
  services.openssh = {
    enable = true;
    openFirewall = true;
    authorizedKeysInHomedir = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  # The loop runs install.sh and nusku-rebuild over SSH, with nobody to type a password.
  security.sudo.extraRules = [
    {
      users = [ cfg.user ];
      commands = [{ command = "ALL"; options = [ "NOPASSWD" ]; }];
    }
  ];

  # KVP tells Hyper-V the VM's IP address (gpu "vm" turns this on too; the loop can't do without it).
  virtualisation.hypervGuest.enable = true;

  # Straight into niri at boot (nusku-arch's loop did the same), so the session's checks and
  # screenshots need no login.
  services.displayManager.autoLogin = {
    enable = true;
    user = cfg.user;
  };

  # nusku-rebuild in the VM builds this variant again, not the plain host (which has no sshd).
  environment.variables.NUSKU_FLAKE_ATTR = "${cfg.hostname}-hyperv-test";
}
