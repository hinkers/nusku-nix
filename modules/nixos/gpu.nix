# GPU drivers, NVIDIA (open or the 580 legacy branch), PRIME offload, Hyper-V guest support, and
# the niri GPU/screen KDL that modules/home writes to ~/.config/nusku/gpu.kdl.
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

  # One output block per built-in panel that needs a scale (nusku-arch gpu_panel_lua).
  panelBlock = lib.optionalString (cfg.panels != [ ]) (
    "// Laptop screen at 1.25 (an automatic 1.5 would leave little room). Override in local.kdl.\n"
    + lib.concatMapStrings (p: ''output ${builtins.toJSON p.output} { scale ${builtins.toJSON p.scale}; }'' + "\n") cfg.panels
  );

  header = "// Nusku GPU settings (generated from settings.json; included by ~/.config/niri/config.kdl)\n";
  gpuKdl = header + {
    nvidia = ''
      environment {
          LIBVA_DRIVER_NAME "nvidia"
          __GLX_VENDOR_LIBRARY_NAME "nvidia"
          NVD_BACKEND "direct"
      }
    '' + panelBlock;
    hybrid-intel = "// Hybrid: niri runs on the integrated GPU; use prime-run for apps.\n" + panelBlock;
    hybrid-amd = "// Hybrid: niri runs on the integrated GPU; use prime-run for apps.\n" + panelBlock;
    # The VM is Hyper-V (nusku-arch's microsoft case): no 3D, so software rendering, and the
    # cursor drawn with the frame.
    vm = ''
      environment {
          LIBGL_ALWAYS_SOFTWARE "1"
      }
      debug {
          disable-cursor-plane
      }
    '';
    amd = if cfg.panels == [ ] then "// Nothing to override for this GPU.\n" else panelBlock;
    intel = if cfg.panels == [ ] then "// Nothing to override for this GPU.\n" else panelBlock;
  }.${cfg.gpu};
in
{
  options.nusku.internal = {
    niriGpuKdl = mkOption {
      type = types.lines;
      internal = true;
      description = "Contents of ~/.config/nusku/gpu.kdl (GPU environment, laptop screen scale).";
    };
  };

  config = mkMerge [
    {
      nusku.internal.niriGpuKdl = gpuKdl;
      assertions = [
        {
          assertion = isHybrid -> hasPrime;
          message = "hybrid GPU needs prime.intelBusId/amdgpuBusId and nvidiaBusId in settings.json — re-run ./install.sh (gpu ${cfg.gpu} needs prime.${igpuKey} and prime.nvidiaBusId)";
        }
      ];
    }

    # Mesa with VA-API; 32-bit for Steam and other 32-bit games (apps.nix).
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
      # niri's NVIDIA fix (niri wiki, Nvidia): without it the driver keeps freed buffers and niri
      # can hold around 1 GiB of VRAM instead of about 100 MiB.
      environment.etc."nvidia/nvidia-application-profiles-rc.d/50-limit-free-buffer-pool-in-wayland-compositors.json".text =
        builtins.toJSON {
          rules = [{ pattern = { feature = "procname"; matches = "niri"; }; profile = "Limit Free Buffer Pool On Wayland Compositors"; }];
          profiles = [{ name = "Limit Free Buffer Pool On Wayland Compositors"; settings = [{ key = "GLVidHeapReuseRatio"; value = 0; }]; }];
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
