{lib, ...}: {
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

  home.activation.setupCodexConfig = lib.hm.dag.entryAfter ["writeBoundary"] ''
    $DRY_RUN_CMD mkdir -p $HOME/.codex
    $DRY_RUN_CMD rm -f $HOME/.codex/config.toml
    $DRY_RUN_CMD cp ${./codex/config.toml} $HOME/.codex/config.toml
    $DRY_RUN_CMD chmod 600 $HOME/.codex/config.toml
  '';
}
