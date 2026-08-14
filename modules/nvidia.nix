{
  flake.modules.nixos.nvidia =
    { config, lib, ... }: {
      services.xserver.videoDrivers = [ "nvidia" ];

      hardware.nvidia = {
        modesetting.enable = true;
        open = true;
        package = config.boot.kernelPackages.nvidiaPackages.stable;
        powerManagement.enable = true;
        powerManagement.finegrained = true;
        nvidiaSettings = true;
      };

      boot.kernelParams = [
        "nvidia.NVreg_PreserveVideoMemoryAllocations=1"
        "nvidia_drm.modeset=1"
      ];

      hardware.nvidia.prime = {
        offload = {
          enable = lib.mkDefault false;
          enableOffloadCmd = lib.mkDefault false;
        };
        # amdgpuBusId = "PCI:5:0:0";
        # nvidiaBusId = "PCI:1:0:0";
      };
    };
}