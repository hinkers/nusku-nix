# The nusku.* options: the installer's answers, read from the host's settings.json (passed in
# as the `settings` special argument by lib/hosts.nix). Every other module reads config.nusku.
{ config, lib, settings, ... }:
let
  inherit (lib) types mkOption;
  cfg = config.nusku;
  catalogue = import ../../lib/catalogue.nix;

  accents = [
    "rosewater" "flamingo" "pink" "mauve" "red" "maroon" "peach"
    "yellow" "green" "teal" "sky" "sapphire" "blue" "lavender"
  ];
  nvidiaGpus = [ "nvidia" "hybrid-intel" "hybrid-amd" ];

  required = [ "hostname" "user" "gpu" "accent" ];
  known = builtins.attrNames options;
  options = {
    hostname = mkOption {
      type = types.str;
      description = "Host name; also the host's directory under hosts/.";
    };
    user = mkOption {
      type = types.str;
      description = "The desktop user's login name.";
    };
    timezone = mkOption {
      type = types.str;
      default = "UTC";
      description = "Time zone, e.g. Australia/Brisbane.";
    };
    locale = mkOption {
      type = types.str;
      default = "en_US.UTF-8";
      description = "Default locale.";
    };
    keymap = mkOption {
      type = types.str;
      default = "us";
      description = "Keyboard layout (console and Hyprland).";
    };
    boot = mkOption {
      type = types.submodule {
        options = {
          loader = mkOption {
            type = types.enum [ "systemd-boot" "grub" ];
            default = "systemd-boot";
            description = "systemd-boot (UEFI) or GRUB (BIOS).";
          };
          device = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "GRUB install device, e.g. /dev/sda (GRUB only).";
          };
        };
      };
      default = { };
      description = "Boot loader.";
    };
    gpu = mkOption {
      type = types.enum [ "amd" "intel" "nvidia" "hybrid-intel" "hybrid-amd" "vm" ];
      description = "Graphics hardware.";
    };
    nvidia = mkOption {
      type = types.nullOr (types.enum [ "open" "proprietary" ]);
      default = null;
      description = "NVIDIA kernel module; set exactly when gpu is nvidia or hybrid-*.";
    };
    prime = mkOption {
      type = types.nullOr (types.submodule {
        options = lib.genAttrs [ "intelBusId" "amdgpuBusId" "nvidiaBusId" ] (_: mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "PCI bus id, e.g. PCI:1:0:0.";
        });
      });
      default = null;
      description = "PRIME bus ids (hybrid laptops only).";
    };
    panels = mkOption {
      type = types.listOf (types.submodule {
        options = {
          output = mkOption { type = types.str; description = "Output name, e.g. eDP-1."; };
          scale = mkOption { type = types.number; description = "Scale, e.g. 1.25."; };
        };
      });
      default = [ ];
      description = "Built-in panels that need a scale.";
    };
    accent = mkOption {
      type = types.str;
      description = "Catppuccin accent (one of the 14).";
    };
    apps = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "App ids from lib/catalogue.nix.";
    };
    langs = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Language ids from lib/catalogue.nix.";
    };
  };

  quote = s: "\"${s}\"";
  ids = xs: map (x: x.id) xs;
  unknownKeys = builtins.filter (k: !(builtins.elem k known)) (builtins.attrNames settings);
  unknownApps = builtins.filter (a: !(builtins.elem a (ids catalogue.apps))) cfg.apps;
  unknownLangs = builtins.filter (l: !(builtins.elem l (ids catalogue.langs))) cfg.langs;
  hasNvidia = builtins.elem cfg.gpu nvidiaGpus;

  # A missing required key fails the assertion below, and throws if read before assertions
  # run, so the error always names the key (not "option used but not defined").
  missingKeys = builtins.filter (k: !(settings ? ${k})) required;
  missingMsg = k: "settings.json: missing required key ${quote k}";
  missing = lib.genAttrs missingKeys (k: throw (missingMsg k));
in
{
  options.nusku = options;

  config = {
    nusku = lib.filterAttrs (k: _: builtins.elem k known) settings // missing;

    assertions = [
      {
        assertion = missingKeys == [ ];
        message = lib.concatMapStringsSep "\n" missingMsg missingKeys;
      }
      {
        assertion = unknownKeys == [ ];
        message = lib.concatMapStringsSep "\n" (k: "settings.json: unknown key ${quote k}") unknownKeys;
      }
      {
        assertion = builtins.elem cfg.accent accents;
        message = "settings.json: accent ${quote cfg.accent} is not a Catppuccin accent (one of: ${lib.concatStringsSep " " accents})";
      }
      {
        assertion = unknownApps == [ ];
        message = lib.concatMapStringsSep "\n" (a: "settings.json: unknown app id ${quote a} (not in lib/catalogue.nix)") unknownApps;
      }
      {
        assertion = unknownLangs == [ ];
        message = lib.concatMapStringsSep "\n" (l: "settings.json: unknown lang id ${quote l} (not in lib/catalogue.nix)") unknownLangs;
      }
      {
        assertion = hasNvidia -> cfg.nvidia != null;
        message = "settings.json: gpu ${quote cfg.gpu} needs \"nvidia\": \"open\" or \"proprietary\"";
      }
      {
        assertion = !hasNvidia -> cfg.nvidia == null;
        message = "settings.json: \"nvidia\" must be null when gpu is ${quote cfg.gpu}";
      }
      {
        assertion = cfg.boot.loader == "grub" -> cfg.boot.device != null;
        message = "settings.json: boot.loader \"grub\" needs boot.device (e.g. /dev/sda)";
      }
    ];
  };
}
