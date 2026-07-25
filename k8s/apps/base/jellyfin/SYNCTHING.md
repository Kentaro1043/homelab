# Jellyfin 音楽ライブラリの同期

Syncthing は Jellyfin の `jellyfin-music` PVC を読み取り専用で参照し、ローカル PC へ音楽を配信する。

## 初期設定

1. Flux の反映後、<https://syncthing.internal.kentaro1043.com> を開く。
2. 最初に Actions → Settings → GUI でユーザー名と強力なパスワードを設定する。
3. Folders → Add Folder で以下を設定する。
   - Folder Label: `Jellyfin Music`
   - Folder ID: `jellyfin-music`
   - Folder Path: `/music`
   - Folder Type: `Send Only`
4. ローカル PC に Syncthing をインストールし、両方の Device ID を登録する。
5. サーバー側の `Jellyfin Music` フォルダーをローカル PC と共有する。
6. ローカル PC で共有を承認し、Folder Type を `Receive Only` にする。

WireGuard 経由で自動接続できない場合は、ローカル PC からサーバーの Remote Device を編集し、Addresses に
`tcp://172.17.61.1:22000` を追加する。

サーバー Pod では `/music` が読み取り専用のため、ローカル PC での削除や変更は Jellyfin のライブラリへ
書き戻されない。
