{
  inputs,
  pkgs,
  ...
}: let
  codex = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.codex;
in {
  environment.systemPackages = [codex];

  systemd.services.codex-app-server = {
    description = "Codex App Server with Remote Control";
    wantedBy = ["multi-user.target"];
    wants = ["network-online.target"];
    after = ["network-online.target"];
    path = with pkgs; [
      bash
      git
      nodejs
      uv
    ];
    unitConfig.RequiresMountsFor = ["/home/kentaro/.codex"];

    environment = {
      HOME = "/home/kentaro";
      CODEX_HOME = "/home/kentaro/.codex";
    };

    serviceConfig = {
      Type = "simple";
      User = "kentaro";
      Group = "users";
      ExecStart = "${codex}/bin/codex app-server --remote-control --listen unix://";
      Restart = "on-failure";
      RestartSec = "5s";
      UMask = "0077";
    };
  };
}
