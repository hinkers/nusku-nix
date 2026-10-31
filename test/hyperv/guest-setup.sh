#!/usr/bin/env bash
# Runs inside the test VM as root (Initialize-NuskuNixVM.ps1 runs it with sudo over SSH): what the
# nusku-nix test loop needs before Nusku's first build. It goes in /etc/nixos/nusku-test.nix,
# imported from configuration.nix, then the base system is rebuilt. Safe to run again.
#
#   guest-setup.sh [USER]    USER (default tester) gets passwordless sudo
set -euo pipefail

user="${1:-tester}"
case "$user" in
    *[!a-z0-9_-]* | "") echo "guest-setup.sh: bad user name: $user" >&2; exit 2 ;;
esac

tee /etc/nixos/nusku-test.nix >/dev/null <<EOF
# Hyper-V test VM only: what the nusku-nix test loop needs before Nusku's first build
# (test/hyperv/guest-setup.sh). Nusku's own build replaces all of /etc/nixos; the loop's
# NAME-hyperv-test variant (test/hyperv/guest.nix) keeps the same access after it.
{ pkgs, ... }:
{
  services.openssh.enable = true;
  security.sudo.extraRules = [
    { users = [ "$user" ]; commands = [ { command = "ALL"; options = [ "NOPASSWD" ]; } ]; }
  ];
  virtualisation.hypervGuest.enable = true;
  environment.systemPackages = [ pkgs.git ];
}
EOF

grep -q 'nusku-test.nix' /etc/nixos/configuration.nix ||
    sed -i 's|\./hardware-configuration\.nix|./hardware-configuration.nix ./nusku-test.nix|' /etc/nixos/configuration.nix

if ! grep -n 'nusku-test.nix' /etc/nixos/configuration.nix; then
    echo "Could not add ./nusku-test.nix to the imports in /etc/nixos/configuration.nix;" \
        "add it to the imports list by hand and run this again." >&2
    exit 1
fi

nixos-rebuild switch
echo "guest setup done"
