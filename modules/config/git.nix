{
  flake.modules.nixos.git =
    { pkgs, ... }: {
      environment.systemPackages = [ pkgs.git ];
    };
}