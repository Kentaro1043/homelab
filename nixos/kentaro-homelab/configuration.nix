{
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
  ];

  # Nix Config
  nix.settings = {
    experimental-features = "nix-command flakes";
    trusted-users = ["root" "@wheel"];
  };

  # Boot
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Network
  networking.hostName = "kentaro-homelab";
  networking.networkmanager.enable = true;

  # Internationalisation
  i18n.defaultLocale = "ja_JP.UTF-8";
  time.timeZone = "Asia/Tokyo";

  # Sound
  services.pulseaudio.enable = true;

  # User
  users.users.kentaro = {
    isNormalUser = true;
    extraGroups = ["wheel"];
    createHome = true;
    password = "passw0rd";
  };
  # Sudo
  security.sudo = {
    enable = true;
    extraRules = [
      {
        groups = ["wheel"];
        commands = [
          {
            command = "ALL";
            options = ["NOPASSWD"];
          }
        ];
      }
    ];
  };

  # OpenSSH
  services.openssh.enable = true;

  # Firewall
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  networking.firewall.enable = false;

  # DO NOT MODIFY
  system.stateVersion = "25.11";
}
