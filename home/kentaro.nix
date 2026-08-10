{...}: {
  home = {
    username = "kentaro";
    homeDirectory = "/home/kentaro";
    stateVersion = "25.11";
  };

  programs = {
    bash.enable = true;

    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };

    mise = {
      enable = true;
      enableBashIntegration = true;
    };
  };
}
