# Third-party dashboard notices

The dashboard files in this directory include modified works distributed under the
Apache License 2.0. A copy of the license is provided in
[`LICENSES/Apache-2.0.txt`](LICENSES/Apache-2.0.txt).

## Node Exporter Full

- Source: [rfmoz/grafana-dashboards](https://github.com/rfmoz/grafana-dashboards)
- Imported artifact: Grafana dashboard 1860, revision 101
- Changes: optional-collector sections removed, title and UID changed, converted from the classic dashboard
  model to `dashboard.grafana.app/v2`, the remaining collapsed-row layout normalized, and repository-specific
  description and tags added

## Kubernetes views

- Source: [dotdc/grafana-dashboards-kubernetes](https://github.com/dotdc/grafana-dashboards-kubernetes)
- Imported release: v3.0.6
- Changes: four core view dashboards converted from the classic dashboard model to
  `dashboard.grafana.app/v2`; `kube_hpa_labels` queries updated to
  `kube_horizontalpodautoscaler_labels`; repository-specific description and tags added
