# Sharing this PC: Sunshine (stream it to Moonlight) and wayvnc (share the screen over VNC).
# Neither starts with the session: each is a launcher entry ("Sunshine", "Screen sharing
# (VNC)") that starts the user service, or stops it when it's running (nusku-toggle-service).
#
# wayvnc listens on every address (port 5900, opened by modules/nixos/apps.nix) and asks for
# this PC's own user name and password (PAM; the NixOS side adds the PAM service). The
# connection is always encrypted: TLS (VeNCrypt, e.g. Remmina) or RSA-AES (e.g. TigerVNC). The
# keys are made on its first start, in ~/.local/state/nusku/wayvnc, and kept. Sunshine's
# service and ports are in modules/nixos/apps.nix.
{ osConfig, config, lib, pkgs, ... }:
let
  keyDir = "${config.xdg.stateHome}/nusku/wayvnc";

  # Makes the TLS certificate and the RSA key once (the commands wayvnc's README gives).
  wayvncKeys = pkgs.writeShellApplication {
    name = "nusku-wayvnc-keys";
    runtimeInputs = with pkgs; [ coreutils openssl openssh ];
    text = ''
      dir="${keyDir}"
      mkdir -p "$dir"
      chmod 700 "$dir"
      if [ ! -s "$dir/tls_key.pem" ] || [ ! -s "$dir/tls_cert.pem" ]; then
        openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:secp384r1 -sha384 -days 3650 \
          -nodes -keyout "$dir/tls_key.pem" -out "$dir/tls_cert.pem" \
          -subj "/CN=${osConfig.nusku.hostname}" \
          -addext "subjectAltName=DNS:${osConfig.nusku.hostname},DNS:localhost,IP:127.0.0.1" 2>/dev/null
      fi
      if [ ! -s "$dir/rsa_key.pem" ]; then
        rm -f "$dir/rsa_key.pem" "$dir/rsa_key.pem.pub"
        ssh-keygen -q -m pem -t rsa -b 4096 -N "" -f "$dir/rsa_key.pem"
      fi
      chmod 600 "$dir"/*.pem
    '';
  };
  picked = id: builtins.elem id osConfig.nusku.apps;
  scripts = import ../../lib/scripts.nix { inherit pkgs lib; };
  toggle = scripts.mkScript {
    name = "nusku-toggle-service";
    deps = with pkgs; [ libnotify ]; # systemctl comes from the system
  };
  # A launcher entry that starts or stops a user service.
  entry = { name, comment, icon, unit, label, running }: {
    inherit name comment icon;
    exec = "${toggle}/bin/nusku-toggle-service ${unit} \"${label}\" \"${running}\"";
    terminal = false;
    categories = [ "Network" ];
  };
in
lib.mkMerge [
 (lib.mkIf (picked "sunshine" || picked "wayvnc") {
  home.packages = [ toggle ];
 })

 # Sunshine's own launcher entry starts a second Sunshine outside its service: this one (same
 # id, so it replaces it) starts or stops the service; its other two entries are hidden.
 (lib.mkIf (picked "sunshine") {
  xdg.desktopEntries = {
    "dev.lizardbyte.app.Sunshine" = entry {
      name = "Sunshine";
      comment = "Start or stop streaming this PC to Moonlight";
      icon = "sunshine";
      unit = "sunshine";
      label = "Sunshine";
      running = "Moonlight on your other device can find this PC now; its settings are at https://localhost:47990.";
    };
    "dev.lizardbyte.app.Sunshine.terminal" = { name = "Sunshine (terminal)"; noDisplay = true; };
    "dev.lizardbyte.app.Sunshine.kwin" = { name = "Sunshine (KWin)"; noDisplay = true; };
  };
 })

 (lib.mkIf (picked "wayvnc") {
  xdg.desktopEntries.nusku-wayvnc = entry {
    name = "Screen sharing (VNC)";
    comment = "Start or stop sharing this screen over VNC (wayvnc)";
    icon = "preferences-desktop-remote-desktop";
    unit = "wayvnc";
    label = "Screen sharing";
    running = "VNC viewers can connect to this PC on port 5900 with your user name and password.";
  };

  services.wayvnc = {
    enable = true;
    # Not at login: the launcher's "Screen sharing (VNC)" starts it.
    autoStart = false;
    settings = {
      address = "0.0.0.0";
      port = 5900;
      enable_auth = true;
      enable_pam = true;
      certificate_file = "${keyDir}/tls_cert.pem";
      private_key_file = "${keyDir}/tls_key.pem";
      rsa_private_key_file = "${keyDir}/rsa_key.pem";
      # Typed keys are looked up in this PC's layout (settings.json "keymap").
      xkb_layout = osConfig.nusku.keymap;
    };
  };
  systemd.user.services.wayvnc = {
    Service = {
      ExecStartPre = "${wayvncKeys}/bin/nusku-wayvnc-keys";
      # The session can restart under it (a rebuild, a monitor change): come back.
      Restart = "on-failure";
      RestartSec = 3;
    };
    Unit.X-Restart-Triggers = [ "${config.xdg.configFile."wayvnc/config".source}" ];
  };
}
 )
]
