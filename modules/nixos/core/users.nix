{ ... }:

{
  users.users.onyx = {
    isNormalUser = true;
    description = "onyx";
    extraGroups = [ "wheel" "networkmanager" "video" "audio" "input" ];
    # CHANGE THIS on first login, or replace with `hashedPassword`.
    initialPassword = "changeme";
  };

  security.sudo.enable = true;
}