{utils, ...}: {
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
}
