# PDS 移行手順

移行元 context: `oke`
移行先 context: `homelab`

このアプリの可変データは、次の2つの PVC に保存される。

- `data-pds-0`: `/pds/data` にマウント
- `blocks-pds-0`: `/pds/blocks` にマウント

暗号化済みの `pds-secrets` と `smtp-credentials` Secret は `manifest/pds` からコピー済み。

1. 移行元 PDS を停止する。

   ```sh
   kubectl --context oke -n pds scale statefulset pds --replicas=0
   kubectl --context oke -n pds rollout status statefulset pds
   ```

2. homelab 側の manifest を apply または reconcile したあと、データコピー中は移行先 workload を停止しておく。

   ```sh
   kubectl --context homelab -n pds scale statefulset pds --replicas=0
   ```

3. 移行元の PVC をマウントした一時 Pod 内でアーカイブを作成し、ローカルへコピーする。

   ```sh
   kubectl --context oke -n pds run pds-migration-src \
     --restart=Never \
     --image=docker.io/library/busybox:1.37.0 \
     --overrides='{"spec":{"volumes":[{"name":"data","persistentVolumeClaim":{"claimName":"data-pds-0"}},{"name":"blocks","persistentVolumeClaim":{"claimName":"blocks-pds-0"}}],"containers":[{"name":"pds-migration-src","image":"docker.io/library/busybox:1.37.0","command":["sleep","3600"],"volumeMounts":[{"name":"data","mountPath":"/data"},{"name":"blocks","mountPath":"/blocks"}]}]}}'

   kubectl --context oke -n pds wait \
     pod/pds-migration-src \
     --for=condition=Ready \
     --timeout=2m

   kubectl --context oke -n pds exec pds-migration-src -- \
     tar czf /tmp/pds-data.tgz -C /data .

   kubectl --context oke -n pds exec pds-migration-src -- \
     tar czf /tmp/pds-blocks.tgz -C /blocks .

   kubectl --context oke -n pds exec pds-migration-src -- \
     tar tzf /tmp/pds-data.tgz >/dev/null \
     && echo "pds-data.tgz validation: OK"

   kubectl --context oke -n pds exec pds-migration-src -- \
     tar tzf /tmp/pds-blocks.tgz >/dev/null \
     && echo "pds-blocks.tgz validation: OK"

   kubectl --context oke -n pds cp \
     pds-migration-src:/tmp/pds-data.tgz \
     /Users/kentaro/Downloads/pds-data.tgz

   kubectl --context oke -n pds cp \
     pds-migration-src:/tmp/pds-blocks.tgz \
     /Users/kentaro/Downloads/pds-blocks.tgz

   tar tzf /Users/kentaro/Downloads/pds-data.tgz >/dev/null \
     && echo "local pds-data.tgz validation: OK"

   tar tzf /Users/kentaro/Downloads/pds-blocks.tgz >/dev/null \
     && echo "local pds-blocks.tgz validation: OK"

   kubectl --context oke -n pds delete pod pds-migration-src
   ```

   アーカイブのバイナリを `kubectl run -i` の標準出力から直接保存すると、Pod のログや削除メッセージが混入するため使用しない。

4. 移行先の PVC をマウントした一時 Pod へアーカイブをコピーし、検証後に展開する。

   ```sh
   kubectl --context homelab -n pds run pds-migration-dst \
     --restart=Never \
     --image=docker.io/library/busybox:1.37.0 \
     --overrides='{"spec":{"volumes":[{"name":"data","persistentVolumeClaim":{"claimName":"data-pds-0"}},{"name":"blocks","persistentVolumeClaim":{"claimName":"blocks-pds-0"}}],"containers":[{"name":"pds-migration-dst","image":"docker.io/library/busybox:1.37.0","command":["sleep","3600"],"volumeMounts":[{"name":"data","mountPath":"/data"},{"name":"blocks","mountPath":"/blocks"}]}]}}'

   kubectl --context homelab -n pds wait \
     pod/pds-migration-dst \
     --for=condition=Ready \
     --timeout=2m

   kubectl --context homelab -n pds cp \
     /Users/kentaro/Downloads/pds-data.tgz \
     pds-migration-dst:/tmp/pds-data.tgz

   kubectl --context homelab -n pds cp \
     /Users/kentaro/Downloads/pds-blocks.tgz \
     pds-migration-dst:/tmp/pds-blocks.tgz

   kubectl --context homelab -n pds exec pds-migration-dst -- \
     tar tzf /tmp/pds-data.tgz >/dev/null \
     && echo "pds-data.tgz validation: OK"

   kubectl --context homelab -n pds exec pds-migration-dst -- \
     tar tzf /tmp/pds-blocks.tgz >/dev/null \
     && echo "pds-blocks.tgz validation: OK"

   kubectl --context homelab -n pds exec pds-migration-dst -- \
     tar xzf /tmp/pds-data.tgz -C /data

   kubectl --context homelab -n pds exec pds-migration-dst -- \
     tar xzf /tmp/pds-blocks.tgz -C /blocks

   kubectl --context homelab -n pds delete pod pds-migration-dst
   ```

5. 移行先を起動し、サービスの状態を確認する。

   ```sh
   kubectl --context homelab -n pds scale statefulset pds --replicas=1
   kubectl --context homelab -n pds rollout status statefulset pds
   kubectl --context homelab -n pds logs statefulset/pds
   ```
