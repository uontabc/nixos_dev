{
  flake.modules.nixos.input = {
    services.libinput = {
      enable = true;
      touchpad = {
        tapping = true;
        tappingButtonMap = "lrm";
        tappingDragLock = true;
        disableWhileTyping = true;
        naturalScrolling = false;
        middleEmulation = false;
      };
      mouse = {
        naturalScrolling = false;
        middleEmulation = false;
        accelProfile = "flat";
      };
    };
  };
}