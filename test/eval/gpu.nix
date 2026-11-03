# Named eval assertions (flake check `eval-gpu`): every name must evaluate to true.
{ hosts, lib, ... }:
let
  c = name: hosts.${name}.config;
  open = c "gpu-nvidia-open";
  prop = c "gpu-nvidia-prop";
  hi = c "gpu-hybrid-intel";
  ha = c "gpu-hybrid-amd";
  amd = c "gpu-amd";
  intel = c "gpu-intel";
  vm = c "vm-min";
  has = lib.hasInfix;
in
{
  "nvidia open: module open, modesetting, xserver driver" =
    open.hardware.nvidia.open && open.hardware.nvidia.modesetting.enable
    && builtins.elem "nvidia" open.services.xserver.videoDrivers;
  "nvidia proprietary: closed module on the 580 legacy branch" =
    !prop.hardware.nvidia.open && lib.hasPrefix "580." prop.hardware.nvidia.package.version;
  "nvidia: niri env vars" =
    has ''LIBVA_DRIVER_NAME "nvidia"'' open.nusku.internal.niriGpuKdl
    && has ''NVD_BACKEND "direct"'' open.nusku.internal.niriGpuKdl
    && has ''__GLX_VENDOR_LIBRARY_NAME "nvidia"'' open.nusku.internal.niriGpuKdl;
  "nvidia: niri's VRAM fix (application profile for the niri process)" =
    let f = open.environment.etc."nvidia/nvidia-application-profiles-rc.d/50-limit-free-buffer-pool-in-wayland-compositors.json".text; in
    has "GLVidHeapReuseRatio" f && has ''"matches":"niri"'' f
    && !(amd.environment.etc ? "nvidia/nvidia-application-profiles-rc.d/50-limit-free-buffer-pool-in-wayland-compositors.json");
  "hybrid intel: PRIME offload with bus ids" =
    hi.hardware.nvidia.prime.offload.enable && hi.hardware.nvidia.prime.offload.enableOffloadCmd
    && hi.hardware.nvidia.prime.intelBusId == "PCI:0:2:0" && hi.hardware.nvidia.prime.nvidiaBusId == "PCI:1:0:0"
    && hi.hardware.nvidia.open;
  "hybrid amd: PRIME offload with amdgpu bus id" =
    ha.hardware.nvidia.prime.offload.enable && ha.hardware.nvidia.prime.amdgpuBusId == "PCI:5:0:0"
    && !ha.hardware.nvidia.open;
  "hybrid: no nvidia env vars, runs on the iGPU" =
    !(has "LIBVA_DRIVER_NAME" hi.nusku.internal.niriGpuKdl) && has "prime-run" hi.nusku.internal.niriGpuKdl;
  "panels: gpu.kdl has the panel's output block with scale 1.25" =
    has ''output "eDP-1" { scale 1.25; }'' hi.nusku.internal.niriGpuKdl;
  "no panels: no output block" = !(has "output " amd.nusku.internal.niriGpuKdl);
  "amd/intel: mesa with 32-bit and vaapi" =
    amd.hardware.graphics.enable && amd.hardware.graphics.enable32Bit
    && intel.hardware.graphics.enable && intel.hardware.graphics.enable32Bit
    && builtins.any (p: lib.hasPrefix "intel-media-driver" p.name) intel.hardware.graphics.extraPackages;
  "vm: hyper-v guest, software rendering env, no cursor plane" =
    vm.virtualisation.hypervGuest.enable
    && has ''LIBGL_ALWAYS_SOFTWARE "1"'' vm.nusku.internal.niriGpuKdl
    && has "disable-cursor-plane" vm.nusku.internal.niriGpuKdl;
}
