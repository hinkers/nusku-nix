# GPU drivers, NVIDIA (open or the 580 legacy branch), PRIME offload, Hyper-V guest support, and
# the Hyprland GPU/monitor Lua that modules/home writes to ~/.config/nusku/gpu.lua.
# Ported from nusku-arch lib/gpu.sh (gpu_hypr_lua, gpu_panel_lua, gpu_vm_services).
{ config, lib, pkgs, ... }:
let
  inherit (lib) mkIf mkMerge mkOption types;
  cfg = config.nusku;
  isNvidia = builtins.elem cfg.gpu [ "nvidia" "hybrid-intel" "hybrid-amd" ];
  isHybrid = lib.hasPrefix "hybrid-" cfg.gpu;
  prime = if cfg.prime == null then { } else cfg.prime;
  # The integrated GPU's bus id key differs per hybrid flavour.
  igpuKey = if cfg.gpu == "hybrid-amd" then "amdgpuBusId" else "intelBusId";
  hasPrime = isHybrid && (prime.${igpuKey} or null) != null && (prime.nvidiaBusId or null) != null;

  # One hl.monitor line per built-in panel that needs a scale (nusku-arch gpu_panel_lua).
  monitorLua = lib.concatMapStrings
    (p: ''hl.monitor({ output = "${p.output}", mode = "preferred", position = "auto", scale = ${builtins.toJSON p.scale} })'' + "\n")
    cfg.panels;
  panelBlock = lib.optionalString (cfg.panels != [ ])
    ("-- Laptop screen: auto scale picks 1.5 here; 1.25 fits more. Override in local.lua.\n" + monitorLua);

  header = "-- Nusku GPU settings (generated from settings.json; loaded by ~/.config/hypr/hyprland.lua)\n";
  gpuLua = header + {
    nvidia = ''
      hl.env("LIBVA_DRIVER_NAME", "nvidia")
      hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
      hl.env("NVD_BACKEND", "direct")
    '' + panelBlock;
    hybrid-intel = "-- Hybrid: Hyprland runs on the integrated GPU; use prime-run for apps.\n" + panelBlock;
    hybrid-amd = "-- Hybrid: Hyprland runs on the integrated GPU; use prime-run for apps.\n" + panelBlock;
    # Virtual displays report a 0x0 mm size and Hyprland's auto scale then picks 2. The VM is
    # Hyper-V (nusku-arch's microsoft case), which needs software rendering.
    vm = ''
      hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })
      hl.config({ cursor = { no_hardware_cursors = true } })
      hl.env("LIBGL_ALWAYS_SOFTWARE", "1")
      hl.env("WLR_RENDERER_ALLOW_SOFTWARE", "1")
    '';
    amd = if cfg.panels == [ ] then "-- Nothing to override for this GPU.\n" else panelBlock;
    intel = if cfg.panels == [ ] then "-- Nothing to override for this GPU.\n" else panelBlock;
  }.${cfg.gpu};
in
{
  options.nusku.internal = {
    hyprGpuLua = mkOption {
      type = types.lines;
      internal = true;
      description = "Contents of ~/.config/nusku/gpu.lua (GPU env vars, monitor rules).";
    };
    hyprMonitorLua = mkOption {
      type = types.lines;
      internal = true;
      description = "One hl.monitor line per entry of nusku.panels.";
    };
  };

  config = mkMerge [
    {
      nusku.internal.hyprGpuLua = gpuLua;
      nusku.internal.hyprMonitorLua = monitorLua;
      assertions = [
        {
          assertion = isHybrid -> hasPrime;
          message = "hybrid GPU needs prime.intelBusId/amdgpuBusId and nvidiaBusId in settings.json — re-run ./install.sh (gpu ${cfg.gpu} needs prime.${igpuKey} and prime.nvidiaBusId)";
        }
      ];
    }

    # Mesa with VA-API; 32-bit for Steam (Task 7 relies on it).
    (mkIf (cfg.gpu != "vm") {
      hardware.graphics = {
        enable = true;
        enable32Bit = true;
      };
    })
    (mkIf (builtins.elem cfg.gpu [ "intel" "hybrid-intel" ]) {
      hardware.graphics.extraPackages = [ pkgs.intel-media-driver ];
    })

    (mkIf isNvidia {
      services.xserver.videoDrivers = (lib.optional (cfg.gpu == "hybrid-amd") "amdgpu") ++ [ "nvidia" ];
      hardware.nvidia = {
        open = cfg.nvidia == "open";
        modesetting.enable = true;
        # nusku-arch's "proprietary" is the 580xx branch (nvidia-580xx-dkms).
        package = mkIf (cfg.nvidia == "proprietary") config.boot.kernelPackages.nvidiaPackages.legacy_580;
      };
    })

    (mkIf (isNvidia && hasPrime) (mkIf isHybrid {
      hardware.nvidia.prime = {
        offload.enable = true;
        offload.enableOffloadCmd = true; # the prime-run command
        nvidiaBusId = prime.nvidiaBusId;
      } // { ${igpuKey} = prime.${igpuKey}; };
    }))

    # Hyper-V guest services (nusku-arch gpu_vm_services, microsoft case).
    (mkIf (cfg.gpu == "vm") {
      virtualisation.hypervGuest.enable = true;
    })
  ];
}
