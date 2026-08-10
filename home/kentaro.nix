{
  inputs,
  lib,
  ...
}: let
  skillNames = [
    "gh-address-comments"
    "gh-fix-ci"
    "pdf"
    "security-best-practices"
    "security-threat-model"
  ];
in {
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
