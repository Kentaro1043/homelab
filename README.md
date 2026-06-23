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
