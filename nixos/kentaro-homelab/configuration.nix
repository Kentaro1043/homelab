{...}: {
  imports = [
    ./hardware-configuration.nix
    ./disk-config.nix
    ./modules
    ./services
  ];

  # DO NOT MODIFY
  system.stateVersion = "25.11";
}
