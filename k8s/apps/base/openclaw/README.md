# OpenClaw

OpenClaw Gateway 本体は NixOS ホスト上の Home Manager user service
`openclaw-gateway.service` として動作する。Kubernetes 側には公開用 Ingress、
selector-less Service、ホストの WireGuard アドレス `172.17.61.1` を指す
EndpointSlice だけを残す。

設定、Discord/Gemini/Gateway の Secret、永続状態はそれぞれ Home Manager、
sops-nix、impermanence で管理する。Kubernetes Secret や PVC は使用しない。

この構成では first-party の
[`nix-openclaw`](https://github.com/openclaw/nix-openclaw) を使用する。
`OPENCLAW_NIX_MODE=1` だけをコンテナへ渡す構成と異なり、パッケージ、immutable な
設定、systemd user service、runtime plugin を同じ flake で固定・ロールバックできる。

## Codex とサンドボックス

Codex プラグインは `appServer.homeScope = "user"` でホストの `~/.codex` を共有する。
これにより Codex CLI と同じ認証、設定、MCP、プラグイン、スレッドを利用できる。
同じスレッドを CLI と OpenClaw から同時に更新せず、OpenClaw から続行する場合は
先に fork すること。

これは `PATH` 上のホスト Codex 実行ファイルを直接選択する設定ではない。Codex
プラグインは OpenClaw と互換性を固定した managed app-server を使用する。
`appServer.command` でホスト実行ファイルへ切り替えるには両者の要求バージョンが
完全に一致する必要があるため、現在の pin では override しない。

Docker バックエンドは使用しない。既定エージェントを Codex に fail-closed し、
`tools.exec.mode = "auto"` によって Codex Guardian の approval と
`workspace-write` サンドボックスを使用する。この境界は Codex ランタイムに対して
有効であり、将来 Codex 以外のエージェントを追加する場合は OpenShell などの
OpenClaw sandbox backend を別途構成すること。

OpenClaw は Docker 以外に SSH と OpenShell backend もサポートするが、OpenShell の
Kubernetes deployment は現時点で experimental である。そのため今回は
[Codex harness の app-server policy](https://docs.openclaw.ai/plugins/codex-harness#app-server-policy)
にある Guardian mapping を採用し、OpenShell は安定後の選択肢として残す。

`homeScope = "user"` の動作と同一スレッドを同時更新しない制約は
[Codex harness reference](https://docs.openclaw.ai/plugins/codex-harness-reference#auth-and-environment-isolation)
を参照する。

## 確認

```sh
systemctl --user status openclaw-gateway
openclaw health
openclaw config get tools.exec.mode
```

Discord で `/status` を実行し、`Runtime: OpenAI Codex` と表示されること、
`/codex permissions status` で Guardian の approval と `workspace-write` が
選択されていることも確認する。
