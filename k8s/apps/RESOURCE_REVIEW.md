# CPU requests 調整（2026-09-22）

Grafana Cloud MCP の `grafanacloud-prom`、`cluster="homelab"` を使用。
直近7日、5分 rate・5分間隔で2016点を取得した。
CPU の単位は millicores（1000m = 1コア）。最大値も5分平均の最大であり、瞬間ピークではない。

## 変更

通常負荷に余裕を持たせて CPU requests を削減する。
CPU limits は維持し、Palworld は従来どおり CPU limit を設けない。
メモリ requests/limits は変更しない。requests の削減は CPU の競合時の配分にも影響するため、
ゲーム参加者増加・エンコード・大量ダウンロードなど観測期間外の負荷は再評価する。

| Namespace / Container | CPU P95 (m) | CPU 最大 (m) | requests 変更 (m) |
| --- | ---: | ---: | ---: |
| adguard-home / adguard-home | 1.8 | 4.0 | 50 → 25 |
| invidious / invidious | 9.8 | 16.9 | 100 → 50 |
| jellyfin / epgstation | 1.5 | 64.0 | 100 → 50 |
| jellyfin / mariadb | 9.4 | 11.9 | 100 → 50 |
| jellyfin / konomitv | 5.5 | 6.9 | 200 → 100 |
| jellyfin / mirakurun | 12.6 | 12.8 | 100 → 50 |
| jellyfin / oh-my-ytdl | 29.4 | 84.4 | 100 → 75 |
| jellyfin / rclone | 0.2 | 1.1 | 25 → 10 |
| kubernetes-mcp-server / kubernetes-mcp-server | 0.5 | 2.8 | 100 → 10 |
| misskey / misskey-valkey | 9.0 | 11.6 | 50 → 25 |
| openclaw / gateway | 16.7 | 23.5 | 250 → 100 |
| openclaw / grafana-cloud-mcp | 0.1 | 0.4 | 50 → 10 |
| palworld / palworld | 256.2 | 257.1 | 1000 → 500 |
| wavelog / wavelog | 0.6 | 8.3 | 100 → 25 |
| wavelog / mariadb | 9.6 | 22.2 | 100 → 50 |
| yattee-server / yattee-server | 2.6 | 78.2 | 100 → 50 |

定常稼働時の予約を合計 **1345m** 削減する。
観測時のノード予約3925mに、未スケジュールのLiteLLM＋PostgreSQL各100mを加味すると、
反映後の見込みは **2780m / 4000m**（ローリング更新中の追加Pod・一時Jobは除外）。

## 維持した主なアプリ

- Jellyfin: P95 10.7m、最大 1790.5m。エンコードのバーストに備えて requests 100m / limit 2コアを維持。
- Misskey: P95 30.2m、最大 117.0m。requests 100m / limit 500mを維持。
- Invidious companion: P95 17.8m、最大 26.7m。requests 50mを維持。
- Alloy: P95 65.6m、最大 84.8m。requests 100mを維持。
- AI・Vaultwarden・kube-state-metrics: requests は既に10mのため維持。
- LiteLLM・専用PostgreSQL: 未起動で実測データがないため、各100mを維持。
- 既存PostgreSQLとインフラコントローラ: 今回のCPU予約不足は上記アプリの調整で解消する見込みのため、設定は変更しない。

メモリ working set の7日最大も確認した。KonomiTV 約985.4Mi、
Misskey 約1193.1Mi、oh-my-ytdl 約728.8Miなど、
現在の予約を超えているアプリもあるため、一律削減は行わない。
Alloy は最大約490.5Miで512Miのlimitに近いため、OOMと増加傾向を継続観測する。

## クエリと反映確認

```promql
quantile_over_time(0.95,
  (sum by (namespace, container) (
    rate(container_cpu_usage_seconds_total{cluster="homelab",container!="",container!="POD"}[5m])
  ))[7d:5m]
) * 1000
```

最大CPUは `quantile_over_time` を `max_over_time` に置き換えて取得。
メモリは `max by(namespace,container)(max_over_time(container_memory_working_set_bytes{cluster="homelab",container!="",container!="POD"}[7d])) / 1024 / 1024`。
同一namespace内の同名コンテナはCPUが合算されるため、集約されるFluxのmanagerは個別調整に使用していない。

Push後はFlux同期、変更したDeployment/HelmRelease/MariaDBのReady、LiteLLMのPending解消を確認する。
単一replicaのRecreateアプリやDBでは更新時に再起動・短い停止が発生する。
CPU throttling、応答時間、ゲーム稼働中の負荷を再確認し、競合時に不足するアプリはrequestsを引き上げる。

