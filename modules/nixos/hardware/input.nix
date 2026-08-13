{ ... }:

{
  services.libinput = {
    enable = true;

    touchpad = {
      enable = true;
      tapping = true;
      tapButtonMap = "lrm";
      dragLock = true;
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
}