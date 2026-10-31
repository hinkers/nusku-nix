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
  "nvidia: hyprland env vars" =
    has ''hl.env("LIBVA_DRIVER_NAME", "nvidia")'' open.nusku.internal.hyprGpuLua
    && has ''hl.env("NVD_BACKEND", "direct")'' open.nusku.internal.hyprGpuLua
    && has ''hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")'' open.nusku.internal.hyprGpuLua;
  "hybrid intel: PRIME offload with bus ids" =
    hi.hardware.nvidia.prime.offload.enable && hi.hardware.nvidia.prime.offload.enableOffloadCmd
    && hi.hardware.nvidia.prime.intelBusId == "PCI:0:2:0" && hi.hardware.nvidia.prime.nvidiaBusId == "PCI:1:0:0"
    && hi.hardware.nvidia.open;
  "hybrid amd: PRIME offload with amdgpu bus id" =
    ha.hardware.nvidia.prime.offload.enable && ha.hardware.nvidia.prime.amdgpuBusId == "PCI:5:0:0"
    && !ha.hardware.nvidia.open;
  "hybrid: no nvidia env vars, runs on the iGPU" =
    !(has "LIBVA_DRIVER_NAME" hi.nusku.internal.hyprGpuLua) && has "prime-run" hi.nusku.internal.hyprGpuLua;
  "panels: monitor lua has scale 1.25" =
    has ''hl.monitor({ output = "eDP-1", mode = "preferred", position = "auto", scale = 1.25 })'' hi.nusku.internal.hyprMonitorLua
    && has "scale = 1.25" hi.nusku.internal.hyprGpuLua;
  "no panels: no monitor lua" = amd.nusku.internal.hyprMonitorLua == "";
  "amd/intel: mesa with 32-bit and vaapi" =
    amd.hardware.graphics.enable && amd.hardware.graphics.enable32Bit
    && intel.hardware.graphics.enable && intel.hardware.graphics.enable32Bit
    && builtins.any (p: lib.hasPrefix "intel-media-driver" p.name) intel.hardware.graphics.extraPackages;
  "vm: hyper-v guest, software rendering env, no hw cursor" =
    vm.virtualisation.hypervGuest.enable
    && has ''hl.env("LIBGL_ALWAYS_SOFTWARE", "1")'' vm.nusku.internal.hyprGpuLua
    && has "no_hardware_cursors = true" vm.nusku.internal.hyprGpuLua
    && has ''output = "", mode = "preferred", position = "auto", scale = 1'' vm.nusku.internal.hyprGpuLua;
}
