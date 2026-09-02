{
  flake.modules.nixos.daed =
    { pkgs, ... }:
    {
      # daed = dae (eBPF proxy core) + dae-wing (GraphQL API) + web UI in one
      # binary. The GUI is a web dashboard at http://127.0.0.1:2023.
      systemd.services.daed = {
        description = "daed - dae integration solution, API and UI";
        after = [ "network-online.target" "systemd-sysctl.service" ];
        wants = [ "network-online.target" ];
        serviceConfig = {
          Type = "simple";
          User = "root";
          LimitNPROC = 512;
          LimitNOFILE = 1048576;
          ExecStart = "${pkgs.daed}/bin/daed run -c /etc/daed/";
          Restart = "on-abnormal";
        };
        wantedBy = [ "multi-user.target" ];
      };

      # daed writes its DB/config into /etc/daed (persisted via impermanence).
      # Ensure the dir exists and is writable even on a fresh boot.
      # geoip.dat / geosite.dat come from v2ray-rules-dat (the v2ray/Loyalsoldier
      # dat format dae's geoip:/geosite: rules need). sing-geoip/sing-geosite
      # ship .srs files instead, which dae cannot read — without these two
      # files ApplyRules fails and the proxy stays off.
      systemd.tmpfiles.rules = [
        "d /etc/daed 0700 root root -"
        "L+ /etc/daed/geoip.dat - - - - ${pkgs.v2ray-rules-dat}/share/v2ray/geoip.dat"
        "L+ /etc/daed/geosite.dat - - - - ${pkgs.v2ray-rules-dat}/share/v2ray/geosite.dat"
      ];

      # eBPF programs need kernel headers/params dae checks at startup.
      boot.kernelParams = [ "bpf_jit_enable=1" ];

      # Web UI and the GraphQL API.
      networking.firewall.allowedTCPPorts = [ 2023 ];

      # Desktop entry that just opens the web dashboard in a browser.
      environment.systemPackages = [
        (pkgs.makeDesktopItem {
          name = "daed";
          exec = "${pkgs.xdg-utils}/bin/xdg-open http://127.0.0.1:2023";
          desktopName = "daed Web Panel";
          genericName = "Modern web dashboard for dae";
          comment = "High-performance eBPF-based proxy";
          categories = [ "Network" ];
        })
      ];
    };
}
