{ lib, ... }:

{
  hardware.cpu.amd.updateMicrocode = lib.mkDefault true;
  hardware.enableRedistributableFirmware = true;

  boot.kernelModules = [ "kvm-amd" "amd-pstate" ];

  boot.kernelParams = [ "amd_pstate=active" ];
}