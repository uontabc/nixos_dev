{ inputs, ... }:
{
  # Hjem — declarative $HOME file management (https://hjem.feel-co.org).
  #
  # Replaces the ad-hoc systemd-tmpfiles `d`/`L+` rules that used to scatter
  # user files (config.fish, starship, pi settings, app configs, state dirs)
  # the modules. Each module now declares its user files under
  # `hjem.users.<user>` (files = ~, xdg.config.files = ~/.config, ...) and
  # hjem's linker (smfh, run as the user via hjem-activate@.service) creates
  # and links them at boot. Dirs are created on demand by the linker, so only
  # dirs that need explicit permissions (0700/0755) are declared.
  #
  # Imported from modules/base.nix right after `users`, so `config.my.name`
  # is available. `user`/`directory` of hjem.users.<name> are mkDefault'd
  # from the matching users.users.<name> entry.
  flake.modules.nixos.hjem =
    { config, ... }:
    {
      imports = [ inputs.hjem.nixosModules.default ];

      hjem.users.${config.my.name}.enable = true;
    };
}
