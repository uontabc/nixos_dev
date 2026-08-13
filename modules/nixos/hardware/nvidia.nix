# NVIDIA RTX 5060 Laptop (Blackwell, sm_120).
# Dragon Range HX CPU has no usable iGPU — the dGPU drives the displays
# directly, so PRIME offload/sync is NOT configured by default. Enable it
# only if a hybrid iGPU+dGPU laptop is used instead.
# Ref: wiki.nixos.org/wiki/NVIDIA
{ config, lib, ... }:

{
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    modesetting.enable = true;

    # Open kernel modules. Blackwell (50-series) REQUIRES open modules.
    open = true;

    package = config.boot.kernelPackages.nvidiaPackages.stable;

    # Preserve VRAM across suspend/resume (otherwise wedged GPU on Optimus).
    powerManagement.enable = true;
    powerManagement.finegrained = true;

    nvidiaSettings = true;
  };

  boot.kernelParams = [
    "nvidia.NVreg_PreserveVideoMemoryAllocations=1"
    "nvidia_drm.modeset=1"
  ];

  # Disabled: HX-series laptops have dGPU-only display pipeline.
  # For a hybrid iGPU+dGPU laptop, set BusIDs from
  # `lspci -nn | grep -E 'VGA|3D'` (hex -> decimal), then flip offload.enable.
  hardware.nvidia.prime = {
    offload = {
      enable = lib.mkDefault false;
      enableOffloadCmd = lib.mkDefault false;
    };
    # amdgpuBusId = "PCI:5:0:0";
    # nvidiaBusId = "PCI:1:0:0";
  };
}