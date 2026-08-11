{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  grafanaTrapAuthorization =
    config.sops.secrets.codex-grafana-trap-authorization.path;
  codexUnwrapped = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.codex;
  codex =
    pkgs.runCommand "codex-with-grafana-trap-auth" {
      nativeBuildInputs = [pkgs.makeWrapper];
      meta.mainProgram = "codex";
    } ''
      mkdir -p $out/bin
      makeWrapper ${lib.getExe codexUnwrapped} $out/bin/codex \
        --run 'if [ -r "${grafanaTrapAuthorization}" ]; then export CODEX_MCP_GRAFANA_TRAP_AUTHORIZATION="$(cat "${grafanaTrapAuthorization}")"; fi'
    '';
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
      ExecStart = "${codex}/bin/codex app-server --remote-control --listen unix://";
      Restart = "on-failure";
      RestartSec = "5s";
      UMask = "0077";
    };
  };
}
