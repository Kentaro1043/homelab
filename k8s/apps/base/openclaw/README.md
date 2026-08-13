# OpenClaw

OpenClaw Gateway 本体は NixOS ホスト上の Home Manager user service
`openclaw-gateway.service` として動作する。Kubernetes 側には公開用 Ingress、
selector-less Service、ホストの WireGuard アドレス `172.17.61.1` を指す
EndpointSlice だけを残す。

設定、Discord/Gemini/Gateway の Secret、永続状態はそれぞれ Home Manager、
sops-nix、impermanence で管理する。Kubernetes Secret や PVC は OpenClaw 本体には
使用しない。

この構成では first-party の
[`nix-openclaw`](https://github.com/openclaw/nix-openclaw) を使用する。
`OPENCLAW_NIX_MODE=1` だけをコンテナへ渡す構成と異なり、パッケージ、immutable な
設定、systemd user service、runtime plugin を同じ flake で固定・ロールバックできる。

## Codex と厳密なサンドボックス

Codex プラグインは `appServer.homeScope = "user"` でホストの `~/.codex` を共有する。
Codex CLI と同じ認証とスレッドを利用できるが、同じスレッドを CLI と OpenClaw から
同時に更新しないこと。OpenClaw から続行する場合は先に fork する。

これは `PATH` 上のホスト Codex 実行ファイルを直接選択する設定ではない。Codex
プラグインは OpenClaw と互換性を固定した managed app-server を使用する。
`appServer.command` でホスト実行ファイルへ切り替えるには両者の要求バージョンが
完全に一致する必要があるため、現在の pin では override しない。

ツール実行の境界に Codex auto-review は使用しない。全 agent turn に対して
`agents.defaults.sandbox.mode = "all"` と `backend = "openshell"` を設定し、コマンド、
ファイル操作、process tool を k3s 内の Agent Sandbox Pod へ送る。OpenShell、OIDC、
port-forward のいずれかが利用できない場合はホスト実行へフォールバックせず、その
ツール呼び出しを失敗させる。

Codex app-server には防御を重ねるため `approvalPolicy = "never"`、
`approvalsReviewer = "user"`、`sandbox = "read-only"` も明示し、Codex 側でも昇格を
要求できないようにする。ただし、これらは主たる隔離境界ではない。OpenClaw sandbox が
有効な turn では Codex の native Code Mode、user MCP server、app-backed plugin execution
は無効になり、shell access は OpenShell-backed dynamic tool だけになる。したがって
共有できる主な利点は認証とスレッドであり、ホストの MCP/プラグインをそのまま実行
できるわけではない。

OpenShell workspace は `remote` mode であり、最初に一度だけホスト workspace から
seed した後は sandbox 側を正とする。sandbox 内の変更はホストへ同期されない。
ホストの変更を反映するには `openclaw sandbox recreate --all` で再作成する。

## OpenShell on k3s

OpenShell `0.0.104` と Kubernetes SIG Agent Sandbox `v0.5.0` を固定する。Gateway、
supervisor、base sandbox image、Helm chart は digest も固定する。Sandbox Pod は次の
設定で作成する。

- Kubernetes user namespace を有効にして container UID 0 を host の非特権 UID へ写す
- process supervisor を非 root・全 capability drop の sidecar topology に分離する
- network 初期化だけに限定した init container を使う
- `RuntimeDefault` AppArmor、OpenShell の seccomp/Landlock、NetworkPolicy を有効にする
- policy validation を `fail_closed`、telemetry と loopback plaintext service を無効にする
- sandbox workspace と Gateway SQLite を `local-path` PVC に置く
- `autoProviders = false` とし、ホストの provider credential を sandbox に自動投入しない

OpenShell Gateway は ClusterIP のまま公開しない。ホストの
`openshell-port-forward.service` が `127.0.0.1:17670` のみに転送する。Gateway の user
authentication は Authentik OIDC の client credentials を必須にし、
`allowUnauthenticatedUsers` は無効のままにする。`openshell-bootstrap.service` は
Gateway が生成した TLS bundle と Authentik client secret を Kubernetes Secret から
`~/.config/openshell` へ owner-only で配置する。短命 OIDC token は wrapper が期限前に
更新する。

OpenShell の Kubernetes deployment は upstream で experimental 扱いである。本番級の
強いマルチテナント境界とは見なさず、更新時は Agent Sandbox/OpenShell の release note
と Sandbox Pod の securityContext を再確認する。

## 適用と確認

先に Flux の infrastructure と apps を同期し、Agent Sandbox controller、OpenShell、
Authentik blueprint が Ready になってから NixOS 設定を適用する。

```sh
flux reconcile kustomization infra-controllers --with-source
flux reconcile kustomization apps --with-source
kubectl -n agent-sandbox-system rollout status deployment/agent-sandbox-controller
kubectl -n openshell rollout status statefulset/openshell

sudo nixos-rebuild switch --flake .#kentaro-homelab
systemctl --user restart openshell-port-forward openshell-bootstrap openclaw-gateway
```

状態と実効 policy を確認する。

```sh
systemctl --user status openshell-port-forward openshell-bootstrap openclaw-gateway
openshell --gateway k3s status
openclaw health
openclaw sandbox list
openclaw sandbox explain
```

Discord で `/status` を実行し `Runtime: OpenAI Codex` と表示されること、ツールから
`uname -n` を実行した結果がホスト名 `kentaro-homelab` ではなく Sandbox Pod になることも
確認する。

参考資料:

- [OpenClaw OpenShell backend](https://docs.openclaw.ai/gateway/openshell)
- [OpenClaw Codex harness reference](https://docs.openclaw.ai/plugins/codex-harness-reference)
- [OpenShell Kubernetes setup](https://docs.nvidia.com/openshell/latest/kubernetes/setup)
- [OpenShell Gateway authentication](https://docs.nvidia.com/openshell/reference/gateway-auth)
