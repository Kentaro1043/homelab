{config, ...}: {
  services.k3s = {
    enable = true;
    role = "server";
    tokenFile = config.sops.secrets.k3s-token.path;
    extraFlags = [
      "--write-kubeconfig-mode 644" # 一般ユーザーがkubectlできるようにする
      "--flannel-backend=host-gw"
      "--flannel-iface=wg0"
      "--write-kubeconfig-mode=644"
    ];
    disable = [
      "traefik"
    ];
    nodeName = "kentaro-homelab";
    nodeIP = "172.17.61.1";
  };
}
