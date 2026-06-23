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
    };
  };

  # Nix Config
  nix.settings = {
    experimental-features = "nix-command flakes";
    trusted-users = ["root" "@wheel"];
  };

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
    ];
    files = [
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
      ];
    };
  };

  # Network
  networking = {
    hostName = "kentaro-homelab";
    nat = {
      enable = true;
      enableIPv6 = true;
      externalInterface = "enp51s0";
      internalInterfaces = ["wg0"];
    };
    useNetworkd = true; # for WireGuard
  };
  systemd.network.enable = true;
  # Firewall
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      22 # SSH
    ];
    allowedUDPPorts = [
      49920 # WireGuard
    ];
  };
  # WireGuard
  systemd.network = {
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
          # iPhone
          PublicKey = "vcASWXo+S5Q1id1EE6YsBaZmXEM9vl0/PteUKsLZnkk=";
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
