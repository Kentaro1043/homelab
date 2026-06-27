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

3. 一時 Pod を使って、移行元 PVC から移行先 PVC に `/ai/data` をコピーする。以下はローカルの stdout/stdin 経由で `tar` を流す例。

   ```sh
   kubectl --context oke -n ai run ai-copy-src --rm -i --restart=Never \
     --image=busybox:1.37.0 \
     --overrides='{"spec":{"volumes":[{"name":"data","persistentVolumeClaim":{"claimName":"data-ai-0"}}],"containers":[{"name":"ai-copy-src","image":"busybox:1.37.0","command":["tar","czf","-","-C","/data","."],"volumeMounts":[{"name":"data","mountPath":"/data"}]}]}}' \
     > ai-data.tgz

   kubectl --context homelab -n ai run ai-copy-dst --rm -i --restart=Never \
     --image=busybox:1.37.0 \
     --overrides='{"spec":{"volumes":[{"name":"data","persistentVolumeClaim":{"claimName":"data-ai-0"}}],"containers":[{"name":"ai-copy-dst","image":"busybox:1.37.0","command":["tar","xzf","-","-C","/data"],"volumeMounts":[{"name":"data","mountPath":"/data"}]}]}}' \
     < ai-data.tgz
   ```

4. 移行先 workload を起動し、ログを確認する。

   ```sh
   kubectl --context homelab -n ai scale statefulset ai --replicas=1
   kubectl --context homelab -n ai rollout status statefulset ai
   kubectl --context homelab -n ai logs statefulset/ai
   ```
