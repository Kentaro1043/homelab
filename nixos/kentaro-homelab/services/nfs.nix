{pkgs, ...}: {
  services.nfs = {
    server = {
      enable = true;
      exports = ''
        /srv/nfs 172.17.61.0/24(ro,fsid=0,no_subtree_check,crossmnt)
        /srv/nfs/kubernetes 172.17.61.0/24(rw,sync,no_subtree_check,no_root_squash,no_all_squash)
      '';
    };

    settings = {
      nfsd = {
        vers3 = "n";
        vers4 = "y";
        udp = "n";
      };
      mountd.manage-gids = true;
    };
  };

  environment.systemPackages = [
    pkgs.nfs-utils
  ];

  # 権限を指定して初期ディレクトリ作成
  systemd.tmpfiles.rules = [
    "d /srv/nfs 0755 root root -"
    "d /srv/nfs/kubernetes 0777 root root -"
  ];
}
