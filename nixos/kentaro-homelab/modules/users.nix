{config, ...}: {
  users = {
    mutableUsers = false; # パスワードを上書きできるように
    users.kentaro = {
      isNormalUser = true;
      extraGroups = ["wheel"];
      createHome = true;
      hashedPasswordFile = config.sops.secrets.kentaro-password.path;
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGMeqxiGjNrfjXyUFgS4edXiFBwUFYy1EJx5UTvsO7sh kentaro"
      ];
    };
  };

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

  services.openssh.enable = true;
}
