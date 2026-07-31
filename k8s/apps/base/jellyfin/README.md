# メディア・録画サーバー

各アプリケーションは個別のサブ Kustomization で管理する。テレビ録画のデータフローは次のとおり。

1. Mirakurun が PX-S1UD と B-CAS カードリーダーを使用して放送波を受信する。
2. EPGStation が Mirakurun の API を使用して番組表・予約を管理し、TS を `tv-recordings` PVC に保存する。
3. KonomiTV と Jellyfin が同じ `tv-recordings` PVC を読み取り専用で参照する。

Jellyfin は録画済み番組のライブラリとしてのみ使用する。Mirakurun を Jellyfin の Live TV
チューナーとして登録しない。録画ファイルの書き込み元も EPGStation のみに限定する。

## 内部 URL

- Mirakurun API: <https://mirakurun.internal.kentaro1043.com>
- EPGStation: <https://epgstation.internal.kentaro1043.com>
- KonomiTV: <https://konomitv.internal.kentaro1043.com>

## 初回のみ必要な操作

Flux による反映と各 Pod の起動を確認した後、
[Mirakurun の手順](./mirakurun/README.md)に従ってチャンネルスキャンを一度だけ実行する。
スキャン用の Job や起動時処理は用意していない。

その後、EPGStation で番組表を確認して録画予約を行う。Jellyfin では
`/media/tv-recordings` を番組ライブラリとして登録する。KonomiTV には同じパスが設定済みである。

## ストレージ

この配下で使用する PVC はすべて `nfs-homelab` StorageClass を明示している。
共有が必要なのは録画 TS 用の `tv-recordings` のみで、それ以外のアプリケーションデータは
アプリごとに分離する。NFS の要求容量は Kubernetes 上の要求値であり、NFS サーバー側の
ハードクォータではない。
