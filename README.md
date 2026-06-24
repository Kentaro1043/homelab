# homelab

## disko適用

```log
λ scp ./disko/kentaro-homelab.nix nixos@192.168.1.3:/home/nixos
(nixos@192.168.1.3) Password:
kentaro-homelab.nix

λ ssh nixos@192.168.1.3
(nixos@192.168.1.3) Password:

[nixos@nixos:~]$ ls
kentaro-homelab.nix

[nixos@nixos:~]$ sudo nix --experimental-features "nix-command flakes" run github:nix-community/disko/latest -- --mode destroy,format,mount kentaro-homelab.nix
...

[nixos@nixos:~]$ lsblk
NAME        MAJ:MIN RM   SIZE RO TYPE MOUNTPOINTS
loop0         7:0    0   1.4G  1 loop /nix/.ro-store
sda           8:0    1  14.3G  0 disk
├─sda1        8:1    1   1.5G  0 part /iso
└─sda2        8:2    1     3M  0 part
nvme0n1     259:0    0 476.9G  0 disk
├─nvme0n1p1 259:2    0     1G  0 part /mnt/boot
└─nvme0n1p2 259:3    0 475.9G  0 part /mnt/persistent
                                      /mnt/nix
                                      /mnt
```

## インストール

### テスト

```log
λ nix run github:nix-community/nixos-anywhere -- --flake .#kentaro-homelab --vm-test
```

### 実行

ホストキーをsopsの復号化鍵にする必要がある

```log
λ mkdir -p /tmp/nixos-install-keys/persistent/etc/ssh
λ ssh-keygen -t ed25519 -N "" -C "kentaro-homelab" -f /tmp/nixos-install-keys/persistent/etc/ssh/ssh_host_ed25519_key
λ ssh-keygen -t rsa -b 4096 -N "" -C "kentaro-homelab" -f /tmp/nixos-install-keys/persistent/etc/ssh/ssh_host_rsa_key
λ chmod 755 /tmp/nixos-install-keys/persistent
λ chmod 755 /tmp/nixos-install-keys/persistent/etc
λ chmod 755 /tmp/nixos-install-keys/persistent/etc/ssh
λ chmod 600 /tmp/nixos-install-keys/persistent/etc/ssh/ssh_host_*_key
λ nix-shell -p ssh-to-age --run 'cat /tmp/nixos-install-keys/persistent/etc/ssh/ssh_host_ed25519_key.pub | ssh-to-age' # .sops.yamlに追加
λ nix run github:nix-community/nixos-anywhere -- \
    --extra-files /tmp/nixos-install-keys \
    --flake .#kentaro-homelab \
    nixos@192.168.1.3
```

## Flux CD セットアップ

```log
λ flux bootstrap github \
  --token-auth \
  --owner=Kentaro1043 \
  --repository=homelab \
  --branch=main \
  --path=k8s/clusters/homelab \
  --personal
```
