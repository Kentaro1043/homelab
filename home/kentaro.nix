{
  inputs,
  lib,
  osConfig,
  pkgs,
  ...
}: let
  openclawPython = pkgs.python3.withPackages (pythonPackages:
    with pythonPackages; [
      pdfplumber
      pypdf
      reportlab
    ]);
  skillNames = [
    "gh-address-comments"
    "gh-fix-ci"
    "pdf"
    "security-best-practices"
    "security-threat-model"
    "yeet"
  ];
in {
  imports = [inputs.nix-openclaw.homeManagerModules.openclaw];

  home = {
    username = "kentaro";
    homeDirectory = "/home/kentaro";
    stateVersion = "25.11";
  };

  programs = {
    bash.enable = true;

    codex = {
      enable = true;
      package = null;
      context = ./codex/AGENTS.md;
    };

    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };

    git = {
      enable = true;
      package = null;
      ignores = [
        ".serena/"
      ];
      settings = {
        user = {
          email = "71170923+Kentaro1043@users.noreply.github.com";
          name = "Kentaro1043";
        };
        init.defaultBranch = "main";
        pull.rebase = false;
      };
    };

    mise = {
      enable = true;
      enableBashIntegration = true;
    };

    openclaw = {
      enable = true;
      runtimePlugins = ["discord"];
      runtimePackages = with pkgs; [
        gh
        openclawPython
        poppler-utils
        uv
      ];

      environment = {
        CODEX_MCP_GRAFANA_TRAP_AUTHORIZATION = osConfig.sops.secrets.codex-grafana-trap-authorization.path;
        DISCORD_BOT_TOKEN = osConfig.sops.secrets.openclaw-discord-bot-token.path;
        GEMINI_API_KEY = osConfig.sops.secrets.openclaw-gemini-api-key.path;
        OPENCLAW_GATEWAY_TOKEN = osConfig.sops.secrets.openclaw-gateway-token.path;
      };

      workspace.bootstrapFiles = {
        agents = ./openclaw/AGENTS.md;
        soul = ./openclaw/SOUL.md;
        tools = ./openclaw/TOOLS.md;
        identity = ./openclaw/IDENTITY.md;
        user = ./openclaw/USER.md;
      };

      config = {
        gateway = {
          mode = "local";
          bind = "lan";
          port = 18789;
          auth.mode = "token";
          controlUi = {
            enabled = true;
            allowedOrigins = ["https://claw.kentaro1043.com"];
          };
        };

        agents = {
          defaults = {
            model.primary = "openai/gpt-5.6-sol";
            models = {
              "openai/gpt-5.6-sol".agentRuntime.id = "codex";
              "google/gemma-4-31b-it".alias = "gemma-4-31b";
              "google/gemma-4-26b-a4b-it".alias = "gemma-4-26b";
            };
            imageGenerationModel.primary = "openai/gpt-image-2";
          };
          list = [
            {
              id = "default";
              default = true;
              identity.name = "OpenClaw Assistant";
              model.primary = "openai/gpt-5.6-sol";
            }
          ];
        };

        tools.exec.mode = "auto";
        cron.enabled = true;

        channels.discord = {
          enabled = true;
          token = {
            source = "env";
            provider = "default";
            id = "DISCORD_BOT_TOKEN";
          };
          groupPolicy = "allowlist";
          guilds."1366927360435425371" = {
            requireMention = true;
            users = ["766615423453364234"];
            channels."1529514412417744957".requireMention = false;
          };
          dmPolicy = "allowlist";
          allowFrom = ["766615423453364234"];
        };

        skills.allowBundled = ["weather"];
        plugins.entries = {
          codex = {
            enabled = true;
            config.appServer.homeScope = "user";
          };
          discord.enabled = true;
        };
      };
    };
  };

  home.file = lib.listToAttrs (
    map (name:
      lib.nameValuePair ".codex/skills/${name}" {
        source = inputs.codex-skills + "/skills/.curated/${name}";
        force = true;
      })
    skillNames
  );

  home.activation.setupCodexConfig = lib.hm.dag.entryAfter ["writeBoundary"] ''
    $DRY_RUN_CMD mkdir -p $HOME/.codex
    $DRY_RUN_CMD rm -f $HOME/.codex/config.toml
    $DRY_RUN_CMD cp ${./codex/config.toml} $HOME/.codex/config.toml
    $DRY_RUN_CMD chmod 600 $HOME/.codex/config.toml
  '';
}
