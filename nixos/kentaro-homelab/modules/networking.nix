{
  config,
  lib,
  ...
}: {
  networking = {
    hostName = "kentaro-homelab";
    nameservers = [
      "192.168.1.1"
    ];
    nat = {
      enable = true;
      enableIPv6 = true;
      externalInterface = "enp51s0";
      internalInterfaces = ["wg0"];
    };
    useNetworkd = true; # for WireGuard
    useDHCP = false;

    firewall = {
      enable = true;
      interfaces.cni0.allowedTCPPorts = [
        18789 # OpenClaw gateway (Kubernetes ingress -> host)
      ];
      allowedTCPPorts = [
        22 # SSH
        80 # HTTP
        8080 # Alt HTTP
        6443 # k3s
        2049 # NFSv4
      ];
      allowedUDPPorts = [
        49920 # WireGuard
      ];
    };
  };

  services.resolved = {
    enable = true;
    settings.Resolve = {
      DNS = config.networking.nameservers;
      DNSOverTLS = false;
      DNSSEC = false;
    };
  };

  # k3s/containerd should use real upstream DNS servers, not the
  # systemd-resolved stub at 127.0.0.53.
  environment.etc."resolv.conf".source = lib.mkForce "/run/systemd/resolve/resolv.conf";

  systemd.network = {
    enable = true;
    networks."10-enp51s0" = {
      matchConfig.Name = "enp51s0";
      networkConfig = {
        DHCP = "yes";
        DNS = config.networking.nameservers;
        IPv6PrivacyExtensions = "kernel";
      };
      dhcpV4Config.UseDNS = false;
      dhcpV6Config.UseDNS = false;
      ipv6AcceptRAConfig.UseDNS = false;
    };
    networks."50-wg0" = {
      matchConfig.Name = "wg0";
      networkConfig = {
        IPv4Forwarding = true;
        IPv6Forwarding = true;
      };
      address = [
        "172.17.61.1/24"
        "fd2f:6ed0:a9ae::1/64"
      ];
    };
    netdevs."50-wg0" = {
      netdevConfig = {
        Kind = "wireguard";
        Name = "wg0";
        MTUBytes = "1360";
      };

      wireguardConfig = {
        ListenPort = 49920;
        PrivateKeyFile = config.sops.secrets.wireguard-privatekey.path;
        # To automatically create routes for everything in AllowedIPs,
        # add RouteTable=main
        RouteTable = "main";
        # FirewallMark marks all packets send and received by wg0
        # with the number 42, which can be used to define policy rules on these packets.
        FirewallMark = 42;
      };

      wireguardPeers = [
        {
          # macbook
          PublicKey = "3v0K8zREG4AgTYd5Y++takUTqwofJtZ9gEt2BAiGWTM=";
          AllowedIPs = [
            "172.17.61.2/32"
            "fd2f:6ed0:a9ae::2/128"
          ];
        }
        {
          # iPhone
          PublicKey = "YAyVFFwJhT3duczGYuruc4xJSMYLGEK3ApxgOwldJww=";
          AllowedIPs = [
            "172.17.61.3/32"
            "fd2f:6ed0:a9ae::3/128"
          ];
        }
      ];
    };
  };
}
