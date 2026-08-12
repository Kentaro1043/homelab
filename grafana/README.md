# Grafana dashboards

Grafana Cloud の Git Sync で管理するダッシュボードを配置する。
同期対象のリポジトリパスは `grafana/dashboards` とする。

Grafana Git Sync はダッシュボードファイルとして JSON を扱うため、YAML ではなく JSON で保存している。
ダッシュボードはすべて Kubernetes 形式の `dashboard.grafana.app/v2`、フォルダー定義は
`folder.grafana.app/v1` を使用する。

## Grafana Cloud への接続

1. Grafana Cloud で **Administration > General > Provisioning** を開く。
2. **Repositories** からこの GitHub リポジトリと同期対象ブランチを登録する。
3. Path に `grafana/dashboards` を指定する。
4. Grafana 側の編集を Git に戻す場合は、GitHub App または Contents の書き込み権限を持つトークンを設定する。
   Git を正とするpull-only運用なら読み取り権限だけにする。
5. 接続後に **Pull** を実行し、Resources に2フォルダー、5ダッシュボードが表示されることを確認する。

各ダッシュボードはPrometheusデータソース変数を持つ。初回表示時にGrafana Cloud Metricsの
Prometheusデータソースを選択する。収集側は全系列に `cluster="homelab"` を付与し、
Node Exporterのジョブ名を `integrations/node_exporter` に固定している。

## 内容

- `nodes/node-overview.json`: Node Exporter Full revision 101から、現在有効なcollectorで表示できる
  CPU、メモリ、ディスク、ネットワーク、pressureのパネルだけを抽出した軽量版
- `kubernetes/*.json`: dotdc/grafana-dashboards-kubernetes v3.0.6のGlobal、Namespaces、Nodes、Podsビュー

クラスタ側には単一の`kube-state-metrics` Podを追加し、Git Syncダッシュボードと
Grafana Cloud Kubernetes Monitoringの双方に必要なresourceとmetricのallowlistを設定している。
上流の旧名 `kube_hpa_labels` は、現在のkube-state-metricsに合わせて
`kube_horizontalpodautoscaler_labels` へ置換した。

派生元、変更内容、ライセンスは [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) を参照する。

## Grafana Cloud Kubernetes Monitoring

収集設定はGrafana Cloud Kubernetes Monitoringの既定job名と最小metric allowlistに対応する。
カスタムダッシュボードとは独立した機能なので、利用する場合はGrafana Cloudで
[Kubernetes Monitoringを有効化](https://grafana.com/docs/grafana-cloud/monitor-infrastructure/kubernetes-monitoring/configuration/activate/)する。

軽量性を優先してOpenCost、Kepler、Kubernetes Events、control planeメトリクスは収集しないため、
コスト、消費電力、イベント、control planeに関するビューは対象外となる。

## ローカル検証

```shell
find grafana/dashboards -name '*.json' -print0 | xargs -0 -n1 jq -e . >/dev/null
find grafana/dashboards -name '*.json' ! -name '_folder.json' -print0 \
  | xargs -0 -n1 jq -e '.apiVersion == "dashboard.grafana.app/v2"' >/dev/null
```
