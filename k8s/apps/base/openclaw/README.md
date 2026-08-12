# OpenClaw

## Grafana Cloud MCP

Grafana Cloud MCP は OpenClaw と同じ Pod の sidecar として動作し、loopback の
Streamable HTTP エンドポイントからのみ接続できる。

デプロイ前に、専用 Secret の `GRAFANA_URL` と
`GRAFANA_SERVICE_ACCOUNT_TOKEN` を設定する。

```sh
sops k8s/apps/base/openclaw/secrets/grafana-cloud-mcp.enc.yaml
```

`GRAFANA_URL` には Grafana Cloud stack URL（例:
`https://example.grafana.net`）、`GRAFANA_SERVICE_ACCOUNT_TOKEN` には OpenClaw
専用サービスアカウントのトークンを設定する。必要な操作だけを許可する最小権限の
サービスアカウントを使用すること。
