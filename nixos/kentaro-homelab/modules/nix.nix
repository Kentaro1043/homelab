{pkgs, ...}: {
  nix.settings = {
    experimental-features = "nix-command flakes";
    trusted-users = ["root" "@wheel"];
    extra-substituters = ["https://cache.numtide.com"];
    extra-trusted-public-keys = [
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
    ];
  };

  programs.nix-ld.enable = true;

  environment.systemPackages = with pkgs; [
    git
    ripgrep
    curl
    jq
    yq-go
    nodejs
    pnpm
    uv
    go
    kubectl
    sops
    age
  ];
}
