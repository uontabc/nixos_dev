# AMD Ryzen 9 8940HX (Dragon Range, Zen 4).
# HX series ships with minimal/disabled iGPU — dGPU drives the displays,
# so no PRIME offload config is expected for this laptop.
{ lib, ... }:

{
  hardware.cpu.amd.updateMicrocode = lib.mkDefault true;
  hardware.enableRedistributableFirmware = true;

  boot.kernelModules = [ "kvm-amd" "amd-pstate" ];

  # Active mode gives per-core frequency scaling on Zen 4.
  boot.kernelParams = [ "amd_pstate=active" ];
}