{ lib, ... }: {
  flake.modules.nixos.cpu-amd = {
    hardware.cpu.amd.updateMicrocode = lib.mkDefault true;
    boot.kernelModules = [ "kvm-amd" "amd-pstate" ];
    boot.kernelParams = [ "amd_pstate=active" ];
  };
}