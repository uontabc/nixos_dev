{
  flake.modules.nixos.pi =
    {
      pkgs,
      config,
      lib,
      ...
    }:
    let
      piSettings = pkgs.writeText "pi-settings.json" (
        builtins.toJSON (
          {
            # Startup model defaults. Change interactively with /model + Ctrl+S.
            defaultProvider = "deepseek";
            defaultModel = "deepseek-chat";
            defaultThinkingLevel = "medium";

            theme = "dark";

            # Version is managed by nix — no update pings.
            enableInstallTelemetry = false;
          }
          // lib.optionalAttrs (config.my.piHttpProxy != null) {
            # Fixes "Error: Connection error." (openai SDK APIConnectionError)
            # when api.deepseek.com is unreachable directly — applied as
            # HTTP_PROXY/HTTPS_PROXY for all pi requests.
            httpProxy = config.my.piHttpProxy;
          }
        )
      );

      # Custom provider catalog (https://developer.amd.com.cn/radeon — AMD
      # Radeon Cloud, OpenAI-compatible gateway, free public model APIs).
      # AMD picks which models are served; run `curl -H "Authorization:
      # Bearer $RADEON_API_KEY" https://developer.amd.com.cn/radeon/api/v1/models`
      # to refresh the list.
      piModels = pkgs.writeText "pi-models.json" (
        builtins.toJSON {
          providers.radeon = {
            name = "AMD Radeon Cloud";
            baseUrl = "https://developer.amd.com.cn/radeon/api/v1";
            api = "openai-completions";
            apiKey = "$RADEON_API_KEY";
            models = [
              {
                id = "DeepSeek-V4-Flash";
                name = "DeepSeek V4 Flash";
                reasoning = true;
              }
              {
                id = "Qwen3.8-Flash-Next";
                name = "Qwen3.8 Flash Next";
                reasoning = true;
              }
            ];
          };
        }
      );
    in
    {
      my.packages = [ pkgs.pi-coding-agent ];

      # pi.dev (version/update pings) is unreachable in CN; skip it so pi
      # doesn't hang/error on startup. Set in the shell environment.
      environment.sessionVariables = {
        PI_SKIP_VERSION_CHECK = "1";
      };

      # ~/.pi layout, managed by hjem (modules/hjem.nix). The settings file
      # used to be a systemd-tmpfiles L+ rule; clobber keeps that semantics.
      hjem.users.${config.my.name}.files = {
        ".pi" = {
          type = "directory";
          permissions = "0700";
        };
        ".pi/agent" = {
          type = "directory";
          permissions = "0700";
        };
        ".pi/agent/settings.json" = {
          source = piSettings;
          clobber = true;
        };
        ".pi/agent/models.json" = {
          source = piModels;
          clobber = true;
        };
      };

      # API keys live in ~/.pi/agent/auth.json (0600), e.g.
      #   {"deepseek": {"type": "api_key", "key": "sk-..."}}
      #   {"radeon": {"type": "api_key", "key": "rc-..."}}
      # Create it with `pi`'s /login or write it yourself (RADEON_API_KEY
      # env var also works — the AMD key is shown in the Token Factory / your
      # profile page at developer.amd.com.cn/radeon). `~/.pi` is persisted by
      # impermanence, so it survives reboots.
      #
      # If you get "Error: Connection error." when talking to the model, set
      # `my.piHttpProxy` in modules/system/users.nix to your local proxy
      # (e.g. "http://127.0.0.1:7890") — deepseek's API is OpenAI-compatible
      # and pi routes through HTTP_PROXY/HTTPS_PROXY.
    };
}
