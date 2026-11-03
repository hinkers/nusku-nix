# wayvnc (System tools app): share this screen over VNC. It starts with the niri session and
# listens on every address (port 5900, opened by modules/nixos/apps.nix). Log in with this
# PC's own user name and password (PAM; the NixOS side adds the PAM service). The connection is
# always encrypted: TLS (VeNCrypt, e.g. Remmina) or RSA-AES (e.g. TigerVNC). The keys are made
# on the first start, in ~/.local/state/nusku/wayvnc, and kept.
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
in
lib.mkIf (builtins.elem "wayvnc" osConfig.nusku.apps) {
  services.wayvnc = {
    enable = true;
    autoStart = true; # WantedBy graphical-session.target, which niri-session reaches
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
