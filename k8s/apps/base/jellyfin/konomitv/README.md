# KonomiTV

内部向けの `konomitv.internal.kentaro1043.com` は従来の Traefik Ingress のまま維持する。
外部向けの `konomitv.kentaro1043.com` は Cloudflare Tunnel から既存の Traefik へ転送し、
専用の Traefik Ingress に設定した Basic Auth Middleware を経由して KonomiTV へ接続する。

Cloudflare Tunnel の Ingress backend は同じ Namespace の Service しか参照できないため、
`konomitv-traefik` ExternalName Service で `traefik.traefik.svc.cluster.local` を参照する。

## Basic Auth Secret

`kubernetes.io/basic-auth` 形式の初期認証情報は `konomitv-basic-auth` Secret として
SOPS で暗号化している。
認証情報を変更する場合は次のコマンドで Secret を再生成する。認証情報は Git に平文で保存しない。

```console
mkdir -p k8s/apps/base/jellyfin/konomitv/secrets
read -rsp 'Password: ' KONOMITV_PASSWORD
kubectl create secret generic konomitv-basic-auth \
  --namespace jellyfin \
  --type=kubernetes.io/basic-auth \
  --from-literal=username=konomitv \
  --from-literal=password="$KONOMITV_PASSWORD" \
  --dry-run=client \
  --output=yaml \
  > k8s/apps/base/jellyfin/konomitv/secrets/basic-auth.yaml
unset KONOMITV_PASSWORD
sops --encrypt \
  --output k8s/apps/base/jellyfin/konomitv/secrets/basic-auth.enc.yaml \
  k8s/apps/base/jellyfin/konomitv/secrets/basic-auth.yaml
```

生成後は平文の `secrets/basic-auth.yaml` を削除する。このファイルは `.gitignore` の対象だが、
ローカルにも残さないことを推奨する。
