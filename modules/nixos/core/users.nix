{ pkgs, ... }:

{
  users.users.onyx = {
    isNormalUser = true;
    description = "onyx";
    extraGroups = [ "wheel" "networkmanager" "video" "audio" "input" ];
    # CHANGE THIS on first login, or replace with `hashedPassword`.
    initialPassword = "changeme";
    # User-level packages (replaces home-manager's home.packages).
    packages = with pkgs; [
      kitty
      yazi
      superfile
      satty
      wl-clipboard
      qt6ct
    ];
  };

  security.sudo.enable = true;
}