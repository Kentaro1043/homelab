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
      sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"];
      keyFile = "/var/lib/sops-nix/key.txt";
      generateKey = true;
    };

    secrets = {
      kentaro-password = {
        neededForUsers = true;
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
  networking.hostName = "kentaro-homelab";
  networking.networkmanager.enable = true;

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

  # Firewall
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  networking.firewall.enable = false;

  # DO NOT MODIFY
  system.stateVersion = "25.11";
}
