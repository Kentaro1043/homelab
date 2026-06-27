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

3. `/pds/data` をコピーする。

   ```sh
   kubectl --context oke -n pds run pds-data-src --rm -i --restart=Never \
     --image=busybox:1.37.0 \
     --overrides='{"spec":{"volumes":[{"name":"data","persistentVolumeClaim":{"claimName":"data-pds-0"}}],"containers":[{"name":"pds-data-src","image":"busybox:1.37.0","command":["tar","czf","-","-C","/data","."],"volumeMounts":[{"name":"data","mountPath":"/data"}]}]}}' \
     > pds-data.tgz

   kubectl --context homelab -n pds run pds-data-dst --rm -i --restart=Never \
     --image=busybox:1.37.0 \
     --overrides='{"spec":{"volumes":[{"name":"data","persistentVolumeClaim":{"claimName":"data-pds-0"}}],"containers":[{"name":"pds-data-dst","image":"busybox:1.37.0","command":["tar","xzf","-","-C","/data"],"volumeMounts":[{"name":"data","mountPath":"/data"}]}]}}' \
     < pds-data.tgz
   ```

4. `/pds/blocks` をコピーする。

   ```sh
   kubectl --context oke -n pds run pds-blocks-src --rm -i --restart=Never \
     --image=busybox:1.37.0 \
     --overrides='{"spec":{"volumes":[{"name":"blocks","persistentVolumeClaim":{"claimName":"blocks-pds-0"}}],"containers":[{"name":"pds-blocks-src","image":"busybox:1.37.0","command":["tar","czf","-","-C","/blocks","."],"volumeMounts":[{"name":"blocks","mountPath":"/blocks"}]}]}}' \
     > pds-blocks.tgz

   kubectl --context homelab -n pds run pds-blocks-dst --rm -i --restart=Never \
     --image=busybox:1.37.0 \
     --overrides='{"spec":{"volumes":[{"name":"blocks","persistentVolumeClaim":{"claimName":"blocks-pds-0"}}],"containers":[{"name":"pds-blocks-dst","image":"busybox:1.37.0","command":["tar","xzf","-","-C","/blocks"],"volumeMounts":[{"name":"blocks","mountPath":"/blocks"}]}]}}' \
     < pds-blocks.tgz
   ```

5. 移行先を起動し、サービスの状態を確認する。

   ```sh
   kubectl --context homelab -n pds scale statefulset pds --replicas=1
   kubectl --context homelab -n pds rollout status statefulset pds
   kubectl --context homelab -n pds logs statefulset/pds
   ```
