{
  config,
  inputs,
  pkgs,
  ...
}: let
  codex = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.codex;
  codexPython = pkgs.python3.withPackages (pythonPackages:
    with pythonPackages; [
      pdfplumber
      pypdf
      reportlab
    ]);
  codexTools = with pkgs; [
    bash
    gh
    git
    nodejs
    poppler-utils
    uv
    codexPython
  ];
in {
  environment.systemPackages = [
    codex
    codexPython
    pkgs.gh
    pkgs.poppler-utils
  ];

  systemd.services.codex-app-server = {
    description = "Codex App Server with Remote Control";
    wantedBy = ["multi-user.target"];
    wants = ["network-online.target"];
    after = ["network-online.target"];
    path = codexTools;
    unitConfig.RequiresMountsFor = ["/home/kentaro/.codex"];

    environment = {
      HOME = "/home/kentaro";
      CODEX_HOME = "/home/kentaro/.codex";
    };

    serviceConfig = {
      Type = "simple";
      User = "kentaro";
      Group = "users";
      EnvironmentFile = config.sops.templates."codex-grafana-trap.env".path;
      ExecStart = "${codex}/bin/codex app-server --remote-control --listen unix://";
      Restart = "on-failure";
      RestartSec = "5s";
      UMask = "0077";
    };
  };
}
