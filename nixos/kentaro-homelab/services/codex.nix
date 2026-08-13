{
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
in {
  environment.systemPackages = [
    codex
    codexPython
    pkgs.gh
    pkgs.poppler-utils
  ];
}
