# OpenClaw

## Grafana Cloud MCP

Grafana Cloud MCP は OpenClaw と同じ Pod の sidecar として動作し、loopback の
Streamable HTTP エンドポイントからのみ接続できる。

Grafana Cloud の URL は Deployment に公開設定し、サービスアカウントトークンだけを
専用 Secret で管理する。

```sh
sops k8s/apps/base/openclaw/secrets/grafana-cloud-mcp.enc.yaml
```

`GRAFANA_SERVICE_ACCOUNT_TOKEN` には OpenClaw 専用サービスアカウントのトークンを
設定する。必要な操作だけを許可する最小権限のサービスアカウントを使用すること。
