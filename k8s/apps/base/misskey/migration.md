# Misskey 移行手順

移行元 context: `oke`
移行先 context: `homelab`

homelab の manifest では、CloudNativePG で `misskey-postgres` を作成する。Misskey の非機密設定は ConfigMap で管理し、Pod 起動時に暗号化 Secret の DB パスワードを加えて `default.yml` を生成する。Valkey は Flux `HelmRelease` で `misskey-valkey` としてインストールする。

CloudNativePG は Barman Cloud plugin で WAL を継続的にアーカイブし、毎日 03:00 UTC にベースバックアップを取得する。バックアップは 30 日間保持する。

1. 移行元への書き込みを止める。

   ```sh
   kubectl --context oke -n misskey scale deployment misskey --replicas=0
   kubectl --context oke -n misskey rollout status deployment misskey
   ```

2. 現在の外部 DB ホストから、移行元 PostgreSQL データベースを dump する。

   ```sh
   kubectl --context oke -n misskey run pg-dump --rm -i --restart=Never \
     --image=postgres:17 \
     --env=PGPASSWORD='<source-password>' \
     -- pg_dump -h private.oci.kentaro1043.com -U misskey -d misskey -Fc \
     > misskey.dump
   ```

3. homelab 側の manifest を reconcile または apply し、CloudNativePG の準備と app Secret の自動生成が完了するまで待つ。

   ```sh
   kubectl --context homelab -n misskey wait cluster/misskey-postgres --for=condition=Ready --timeout=10m
   kubectl --context homelab -n misskey get secret misskey-postgres-app
   ```

4. homelab 側 PostgreSQL に restore する。

   ```sh
   DB_PASS="$(kubectl --context homelab -n misskey get secret misskey-postgres-app -o jsonpath='{.data.password}' | base64 -d)"

   kubectl --context homelab -n misskey run pg-restore --rm -i --restart=Never \
     --image=postgres:17 \
     --env=PGPASSWORD="$DB_PASS" \
     -- pg_restore -h misskey-postgres-rw -U misskey -d misskey --clean --if-exists --no-owner \
     < misskey.dump
   ```

5. Misskey の正常動作に Valkey のデータは通常必須ではない。queue/cache の状態も維持したい場合は、Misskey を起動する前に `oke` 側の `misskey-valkey` PVC をコピーする。不要であれば、homelab 側 Valkey は空の状態で起動してよい。

6. homelab 側で Misskey を起動し、必要に応じて生成後の config の DB 接続先を確認する。

   ```sh
   kubectl --context homelab -n misskey scale deployment misskey --replicas=1
   kubectl --context homelab -n misskey rollout status deployment misskey
   kubectl --context homelab -n misskey logs deployment/misskey
   ```

7. 初回バックアップの完了と WAL アーカイブの状態を確認する。

   ```sh
   kubectl --context homelab -n misskey get backup
   kubectl --context homelab -n misskey get cluster misskey-postgres
   ```
