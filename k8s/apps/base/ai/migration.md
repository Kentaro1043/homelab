# ai 移行手順

移行元 context: `oke`
移行先 context: `homelab`

このアプリの可変データは、`/ai/data` にマウントされる `data-ai-0` PVC に保存される。暗号化済みの `ai-config-json` Secret は `manifest/ai` からコピー済み。Misskey token や API key を変更する場合は、別途 Secret を更新または再暗号化する。

1. 移行元の workload を停止する。

   ```sh
   kubectl --context oke -n ai scale statefulset ai --replicas=0
   kubectl --context oke -n ai rollout status statefulset ai
   ```

2. homelab 側の manifest を apply または reconcile したあと、データコピー中は移行先 workload を停止しておく。

   ```sh
   kubectl --context homelab -n ai scale statefulset ai --replicas=0
   ```

3. 移行元の PVC をマウントした一時 Pod 内でアーカイブを作成し、ローカルへコピーする。

   ```sh
   kubectl --context oke -n ai run ai-migration-src \
     --restart=Never \
     --image=docker.io/library/busybox:1.37.0 \
     --overrides='{"spec":{"volumes":[{"name":"data","persistentVolumeClaim":{"claimName":"data-ai-0"}}],"containers":[{"name":"ai-migration-src","image":"docker.io/library/busybox:1.37.0","command":["sleep","3600"],"volumeMounts":[{"name":"data","mountPath":"/data"}]}]}}'

   kubectl --context oke -n ai wait \
     pod/ai-migration-src \
     --for=condition=Ready \
     --timeout=2m

   kubectl --context oke -n ai exec ai-migration-src -- \
     tar czf /tmp/ai-data.tgz -C /data .

   kubectl --context oke -n ai exec ai-migration-src -- \
     tar tzf /tmp/ai-data.tgz >/dev/null \
     && echo "ai-data.tgz validation: OK"

   kubectl --context oke -n ai cp \
     ai-migration-src:/tmp/ai-data.tgz \
     /Users/kentaro/Downloads/ai-data.tgz

   tar tzf /Users/kentaro/Downloads/ai-data.tgz >/dev/null \
     && echo "local ai-data.tgz validation: OK"

   kubectl --context oke -n ai delete pod ai-migration-src
   ```

   アーカイブのバイナリを `kubectl run -i` の標準出力から直接保存すると、Pod のログや削除メッセージが混入するため使用しない。

4. 移行先の PVC をマウントした一時 Pod へアーカイブをコピーし、検証後に展開する。

   ```sh
   kubectl --context homelab -n ai run ai-migration-dst \
     --restart=Never \
     --image=docker.io/library/busybox:1.37.0 \
     --overrides='{"spec":{"volumes":[{"name":"data","persistentVolumeClaim":{"claimName":"data-ai-0"}}],"containers":[{"name":"ai-migration-dst","image":"docker.io/library/busybox:1.37.0","command":["sleep","3600"],"volumeMounts":[{"name":"data","mountPath":"/data"}]}]}}'

   kubectl --context homelab -n ai wait \
     pod/ai-migration-dst \
     --for=condition=Ready \
     --timeout=2m

   kubectl --context homelab -n ai cp \
     /Users/kentaro/Downloads/ai-data.tgz \
     ai-migration-dst:/tmp/ai-data.tgz

   kubectl --context homelab -n ai exec ai-migration-dst -- \
     tar tzf /tmp/ai-data.tgz >/dev/null \
     && echo "ai-data.tgz validation: OK"

   kubectl --context homelab -n ai exec ai-migration-dst -- \
     tar xzf /tmp/ai-data.tgz -C /data

   kubectl --context homelab -n ai delete pod ai-migration-dst
   ```

5. 移行先 workload を起動し、ログを確認する。

   ```sh
   kubectl --context homelab -n ai scale statefulset ai --replicas=1
   kubectl --context homelab -n ai rollout status statefulset ai
   kubectl --context homelab -n ai logs statefulset/ai
   ```
