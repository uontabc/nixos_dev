{ lib, ... }: {
  flake.modules.nixos.cpu-intel = {
    hardware.cpu.intel.updateMicrocode = lib.mkDefault true;
    boot.kernelModules = [ "kvm-intel" ];
  };
}
