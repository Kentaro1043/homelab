# Jellyfin 音楽ライブラリの同期

`jellyfin-music` PVC は、読み取り専用の rclone WebDAV サーバーとして
<https://music-sync.internal.kentaro1043.com> に公開される。

## ローカル PC の設定

1. `k8s/apps/base/jellyfin/rclone-music/secrets/rclone-music.enc.yaml` を SOPS で復号し、認証情報を確認する。

   ```shell
   sops --decrypt k8s/apps/base/jellyfin/rclone-music/secrets/rclone-music.enc.yaml
   ```

   SOPS の秘密鍵がない PC では、Flux の反映後にクラスタから取得できる。

   ```shell
   kubectl get secret rclone-music -n jellyfin -o jsonpath='{.data.username}' | openssl base64 -d -A
   kubectl get secret rclone-music -n jellyfin -o jsonpath='{.data.password}' | openssl base64 -d -A
   ```

2. rclone に WebDAV remote を追加する。

   ```shell
   rclone config
   ```

   以下の値を指定する。

   - Name: `homelab-music`
   - Storage: `webdav`
   - URL: `https://music-sync.internal.kentaro1043.com`
   - Vendor: `rclone`
   - User / Password: 復号した Secret の値

3. 初回は dry-run で同期内容を確認する。

   ```shell
   rclone sync homelab-music: ~/Music/Jellyfin --dry-run --progress
   ```

4. 問題がなければ同期を実行する。

   ```shell
   rclone sync homelab-music: ~/Music/Jellyfin --progress
   ```

`sync` はサーバーに存在しないローカルファイルを削除する。ローカル独自のファイルを残す場合は、
代わりに `rclone copy homelab-music: ~/Music/Jellyfin` を使用する。

サーバー側は rclone の `--read-only` と Kubernetes の読み取り専用マウントを併用しているため、
ローカル PC から Jellyfin のライブラリへ書き込むことはできない。

## 他の PVC を同期する

対象 PVC と同じ Namespace に `rclone-music-*` 相当の Deployment、Service、Ingress、Secret を追加する。
Deployment は状態を持たないため、変更が必要なのは PVC 名、公開ホスト名、認証用 Secret のみ。
