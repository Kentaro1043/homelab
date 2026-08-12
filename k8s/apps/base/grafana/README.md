# Grafana Cloud monitoring

Grafana Alloy を各 Kubernetes ノードに 1 Pod ずつ配置し、Grafana Cloud へ直接送信する。
Grafana、Prometheus、Loki はローカルに配置しない。

収集対象は以下のとおり。

- ノードの CPU、メモリ、ディスク、ネットワーク、NFS などの主要メトリクス
- kubelet の稼働状況、Pod 数、PVC 使用量、resource endpoint の CPU・メモリ使用量
- cAdvisor のコンテナ CPU、メモリ、ネットワーク、OOM メトリクス
- kube-state-metrics の Kubernetes オブジェクト状態
- Kubernetes Pod のログ
- k3s systemd unit の journal ログ
- Alloy 自身のメトリクス

メトリクスは 60 秒間隔で収集し、kubelet/cAdvisor は主要な系列だけを送信する。
Grafana Cloud Kubernetes Monitoringの既定allowlistと、Git Syncダッシュボードが参照する系列の和集合を
収集する。`kube-state-metrics` は必要なresourceとmetricだけを有効にした単一Podとし、追加の系列と
Kubernetes API watchを抑える。

軽量性を優先し、次の機能は収集しない。

- OpenCostによるコストメトリクス
- Keplerによる消費電力メトリクス
- Kubernetes Events
- API server、scheduler、controller-managerなどのcontrol planeメトリクス
- トレースとプロファイル

Git Sync用ダッシュボードはリポジトリルートの [`grafana`](../../../../grafana) に配置している。

## Grafana Cloud の認証情報

適用前に、stack realm の Access Policy を作成し、`metrics:write` と `logs:write` のみを許可した
トークンを発行する。Grafana Cloud Portal の Stack Details から Prometheus と Loki の送信先および
ユーザー ID を確認する。

Secret を SOPS で開く。

```shell
sops k8s/apps/base/grafana/secrets/grafana-cloud.enc.yaml
```

復号された `stringData` のプレースホルダーを次の値に置き換える。

| キー | 値 |
| --- | --- |
| `GRAFANA_CLOUD_METRICS_URL` | Prometheus remote write URL（末尾は通常 `/api/prom/push`） |
| `GRAFANA_CLOUD_METRICS_USERNAME` | Prometheus のユーザー ID |
| `GRAFANA_CLOUD_LOGS_URL` | Loki push URL（末尾は通常 `/loki/api/v1/push`） |
| `GRAFANA_CLOUD_LOGS_USERNAME` | Loki のユーザー ID |
| `GRAFANA_CLOUD_API_TOKEN` | Access Policy token |

プレースホルダーのまま適用すると Alloy は起動するが、Grafana Cloud への送信は認証エラーになる。

## 永続データ

Alloy の metrics WAL とログ読み取り位置は、ホストの `/var/lib/alloy` に保存する。
NixOS の impermanence 対象にも追加してあるため、サーバー再起動後も未送信メトリクスと読み取り位置を維持する。

## 確認

マニフェストは適用せずに Kustomize で確認できる。

```shell
kubectl kustomize k8s/apps/homelab >/dev/null
```

適用後の確認例:

```shell
kubectl -n grafana get pods
kubectl -n grafana logs daemonset/alloy
```

Grafana Explore では、Prometheus で `up{cluster="homelab"}`、Loki で
`{cluster="homelab"}` を確認する。

Kubernetes Monitoring用の主要なjobは以下になる。

| コンポーネント | `job` |
| --- | --- |
| kubelet | `integrations/kubernetes/kubelet` |
| kubelet resource | `integrations/kubernetes/resources` |
| cAdvisor | `integrations/kubernetes/cadvisor` |
| kube-state-metrics | `integrations/kubernetes/kube-state-metrics` |
| embedded node exporter | `integrations/node_exporter` |
| k3s journal | `integrations/kubernetes/journal` |

Grafana Cloud側では[Kubernetes Monitoringを別途有効化](https://grafana.com/docs/grafana-cloud/monitor-infrastructure/kubernetes-monitoring/configuration/activate/)する。
有効化はhost-hours課金の開始を伴うため、メトリクス送信を確認してから実施する。

有効化前後に、Grafana Exploreで次の系列を確認する。

```promql
kubernetes_build_info{cluster="homelab", job="integrations/kubernetes/kubelet"}
node_cpu_usage_seconds_total{cluster="homelab", job="integrations/kubernetes/resources"}
machine_memory_bytes{cluster="homelab", job="integrations/kubernetes/cadvisor"}
kube_node_info{cluster="homelab", job="integrations/kubernetes/kube-state-metrics"}
kube_namespace_status_phase{cluster="homelab"}
kube_pod_start_time{cluster="homelab"}
```

ノードログはLokiで次を確認する。

```logql
{cluster="homelab", job="integrations/kubernetes/journal", source="journal"}
```
