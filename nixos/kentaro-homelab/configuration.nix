{
  config,
  lib,
  pkgs,
  utils,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    ./disk-config.nix
    ./services
  ];

  # Sops Decryption
  sops = {
    defaultSopsFile = ../../secrets/kentaro-homelab.enc.yaml;
    age = {
      # Impermanenceのバインドマウント完了を待たずに直接実体から読み込ませるため、/persistent のパスを指定
      sshKeyPaths = ["/persistent/etc/ssh/ssh_host_ed25519_key"];
      keyFile = "/var/lib/sops-nix/key.txt";
      generateKey = true;
    };

    secrets = {
      kentaro-password = {
        neededForUsers = true;
      };
      wireguard-privatekey = {
        owner = "systemd-network";
        group = "systemd-network";
        mode = "0640";
      };
      k3s-token = {};
    };
  };

  # Nix Config
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

  # Boot
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Impermanence
  boot.initrd.systemd = {
    enable = true; # Default in 26.05
    services.wipe-file-systems = {
      # Specify dependencies explicitly
      unitConfig.DefaultDependencies = false;
      # The script needs to run to completion before this service is done
      serviceConfig.Type = "oneshot";
      # This service is required for boot to succeed
      requiredBy = ["initrd.target"];
      # Should complete before any file systems are mounted
      before = ["sysroot.mount"];

      # Wait for the disk to appear
      requires = ["${utils.escapeSystemdPath "/dev/disk/by-partlabel/disk-main-root"}.device"];
      after = [
        "${utils.escapeSystemdPath "/dev/disk/by-partlabel/disk-main-root"}.device"
        # Allow hibernation to resume before trying to alter any data
        "local-fs-pre.target"
      ];

      script = ''
        mkdir /btrfs_tmp
        mount /dev/disk/by-partlabel/disk-main-root /btrfs_tmp
        if [[ -e /btrfs_tmp/rootfs ]]; then
            mkdir -p /btrfs_tmp/old_roots
            timestamp=$(date --date="@$(stat -c %Y /btrfs_tmp/rootfs)" "+%Y-%m-%-d_%H:%M:%S")
            mv /btrfs_tmp/rootfs "/btrfs_tmp/old_roots/$timestamp"
        fi

        delete_subvolume_recursively() {
            IFS=$'\n'
            for i in $(btrfs subvolume list -o "$1" | cut -f 9- -d ' '); do
                delete_subvolume_recursively "/btrfs_tmp/$i"
            done
            btrfs subvolume delete "$1"
        }

        for i in $(find /btrfs_tmp/old_roots/ -maxdepth 1 -mtime +30); do
            delete_subvolume_recursively "$i"
        done

        btrfs subvolume create /btrfs_tmp/rootfs
        umount /btrfs_tmp
      '';
    };
  };
  fileSystems."/persistent".neededForBoot = true;
  environment.persistence."/persistent" = {
    enable = true;
    hideMounts = true;
    directories = [
      "/var/log"
      "/var/lib/bluetooth"
      "/var/lib/nixos"
      "/var/lib/systemd/coredump"
      "/etc/NetworkManager/system-connections"

      # k3s
      "/var/lib/rancher/k3s"
      "/etc/rancher/k3s"
      "/etc/rancher/node"

      # NFS
      "/var/lib/nfs/nfsdcld"
      "/var/lib/nfs/sm"
      "/var/lib/nfs/sm.bak"
      "/var/lib/nfs/v4recovery"
      "/srv/nfs/kubernetes"
    ];
    files = [
      "/var/lib/nfs/state"
      "/etc/machine-id"
      "/etc/ssh/ssh_host_ed25519_key"
      "/etc/ssh/ssh_host_ed25519_key.pub"
      "/etc/ssh/ssh_host_rsa_key"
      "/etc/ssh/ssh_host_rsa_key.pub"
    ];
    users.kentaro = {
      directories = [
        {
          directory = ".ssh";
          mode = "0700";
        }
        {
          directory = ".codex";
          mode = "0700";
        }
        "Documents"
      ];
      files = [
        ".bash_history"
      ];
    };
  };

  # Network
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
  systemd.network.enable = true;
  # Firewall
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      22 # SSH
      80 # HTTP
      8080 #Alt HTTP
      6443 # k3s
      2049 # NFSv4
    ];
    allowedUDPPorts = [
      49920 # WireGuard
    ];
  };
  # WireGuard
  systemd.network = {
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

  # Internationalisation
  i18n.defaultLocale = "ja_JP.UTF-8";
  time.timeZone = "Asia/Tokyo";

  # Sound
  services.pulseaudio.enable = true;

  # User
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

  # DO NOT MODIFY
  system.stateVersion = "25.11";
}
