{ lib, ... }: {
  flake.modules.nixos.cpu-amd = {
    hardware.cpu.amd.updateMicrocode = lib.mkDefault true;
    # amd-pstate is built into the kernel (CONFIG_X86_AMD_PSTATE=y); only
    # kvm-amd needs to be loaded as a module.
    boot.kernelModules = [ "kvm-amd" ];
    boot.kernelParams = [ "amd_pstate=active" ];
  };
}