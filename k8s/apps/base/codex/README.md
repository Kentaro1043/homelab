# Codex workspace

Microsoft Dev Container と同じ OCI イメージを k3s の StatefulSet で動かす、
Codex Remote Control 用の開発環境。Docker daemon は使用せず、k3s に同梱された
containerd が GHCR からイメージを取得する。

## 境界

- Codex は Pod 内では `danger-full-access` で動かし、Pod 自体を外側の隔離境界とする。
- Kubernetes API の ServiceAccount token、ホストパス、コンテナランタイムの socket は渡さない。
- restricted Pod Security、seccomp、capability drop、CPU・メモリ・一時領域の上限を適用する。
- NetworkPolicy は DNS と public HTTPS への outbound のみを許可し、LAN とクラスタ内部を遮断する。
- Codex の状態と GitHub CLI 認証は `codex-state`、作業ツリーは `codex-workspace` PVC に保持する。
- Grafana Cloud の token は MCP sidecar のみに渡し、Codex は loopback HTTP で接続する。

コンテナは強い境界ではあるが VM ではない。カーネルを共有したくないワークロードでは、
Kata Containers や専用 VM へ移すこと。

この設計は OpenAI の [Agent approvals & security][security] にある
Dev Container を外側の sandbox とする構成と、[Remote Control][remote] の
outbound 接続方式に沿う。

## 初回セットアップ

main への merge 後、GitHub Actions が
`ghcr.io/kentaro1043/homelab-codex:main` を publish する。private package は
SOPS 管理の `ghcr-pull-secret` を使って取得する。この Secret は kubelet の
image pull 専用で、Pod 内には mount しない。

Pod が起動したら認証する。

```sh
kubectl -n codex exec -it codex-0 -c codex -- codex login --device-auth
kubectl -n codex exec -it codex-0 -c codex -- gh auth login --git-protocol https
```

認証後は `codex-state` PVC に保存される。状態確認には次を使う。

```sh
kubectl -n codex get pod codex-0
kubectl -n codex logs -f codex-0 -c codex
```

## MCP credentials

資格情報は SOPS で暗号化した `secrets/mcp-credentials.enc.yaml` で管理する。
値を更新する場合は次を実行する。

```sh
sops k8s/apps/base/codex/secrets/mcp-credentials.enc.yaml
```

[remote]: https://learn.chatgpt.com/docs/remote-connections
[security]: https://learn.chatgpt.com/docs/agent-approvals-security
