{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = "/dev/nvme0n1";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              type = "EF00";
              size = "1024M";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = ["umask=0077"];
              };
            };
            root = {
              size = "100%";
              content = {
                type = "btrfs";
                extraArgs = ["-f"]; # 強制フォーマット
                subvolumes = {
                  # root filesystem: Always delete at reboot
                  "/rootfs" = {
                    mountpoint = "/";
                    mountOptions = ["compress=zstd" "noatime" "discard=async"];
                  };
                  # Nix Store
                  "/nix" = {
                    mountpoint = "/nix";
                    mountOptions = ["compress=zstd" "noatime" "discard=async"];
                  };
                  "/persistent" = {
                    mountpoint = "/persistent";
                    mountOptions = ["compress=zstd" "noatime" "discard=async"];
                  };
                };
              };
            };
          };
        };
      };
    };
  };
}
