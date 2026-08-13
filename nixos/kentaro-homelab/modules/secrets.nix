{...}: {
  sops = {
    defaultSopsFile = ../../../secrets/kentaro-homelab.enc.yaml;
    age = {
      # Impermanenceのバインドマウント完了を待たずに直接実体から読み込ませるため、/persistent のパスを指定
      sshKeyPaths = ["/persistent/etc/ssh/ssh_host_ed25519_key"];
      keyFile = "/var/lib/sops-nix/key.txt";
      generateKey = true;
    };

    secrets = {
      kentaro-password.neededForUsers = true;
      wireguard-privatekey = {
        owner = "systemd-network";
        group = "systemd-network";
        mode = "0640";
      };
      k3s-token = {};
      codex-grafana-cloud-service-account-token = {
        owner = "kentaro";
        group = "users";
        mode = "0400";
      };
    };
  };
}
