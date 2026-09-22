# LiteLLM

Google AI Studio の Gemini API を OpenAI 互換 API として公開する。
LiteLLM v1.101.0、1 replica、DB なしの構成で、Master Key による認証を必須にする。
Virtual Key、利用料金の永続保存、管理 UI を使う場合は PostgreSQL などの追加構成が必要。

| クライアントから指定するモデル | Gemini API のモデル |
| --- | --- |
| `gemini-flash` | `gemini-3.8-flash` |
| `gemini-flash-lite` | `gemini-3.5-flash-lite` |

接続先は `https://litellm.internal.kentaro1043.com/v1`。
既存の内部サービスと同じ Traefik Ingress と `homelab-ca` の TLS 証明書を使用する。
内部 DNS でこのホスト名を Traefik に向け、クライアントで homelab CA を信頼させる。
クラスタ内からは `http://litellm.litellm.svc.cluster.local:4000/v1` でも接続できる。
Google AI Studio は外部 API のため、クラスタ内へのインストールは不要。

## Secret の準備と Flux への追加

API キーが未設定の Pod で既存の Flux apps の Ready 判定を妨げないよう、
初期状態では `k8s/apps/homelab/kustomization.yaml` に登録していない。
以下はリポジトリのルートで実行する。

1. Secret の作業用ファイルを作成する。`secrets/` 内の平文ファイルは既存の `.gitignore` で除外される。

   ```sh
   mkdir -p k8s/apps/base/litellm/secrets
   cp k8s/apps/base/litellm/secret.example.yaml k8s/apps/base/litellm/secrets/litellm-secrets.yaml
   chmod 600 k8s/apps/base/litellm/secrets/litellm-secrets.yaml
   ```

2. 作業用ファイルの `GEMINI_API_KEY` を [Google AI Studio](https://aistudio.google.com/apikey) の
   API キーに置き換える。`LITELLM_MASTER_KEY` には `sk-` で始まるランダムな値を設定する。
   例えば `openssl rand -hex 32` の出力に `sk-` を付ける。

3. 既存の `.sops.yaml` の age 公開鍵で暗号化する。

   ```sh
   sops --encrypt k8s/apps/base/litellm/secrets/litellm-secrets.yaml > k8s/apps/base/litellm/secrets/litellm-secrets.enc.yaml
   rm k8s/apps/base/litellm/secrets/litellm-secrets.yaml
   ```

4. `k8s/apps/base/litellm/kustomization.yaml` の `resources` に
   `secrets/litellm-secrets.enc.yaml` を追加する。
   `k8s/apps/homelab/kustomization.yaml` の `resources` に `../base/litellm` を追加する。
   両方の変更と暗号化 Secret を同じコミットに含める。

5. `kubectl kustomize k8s/apps/homelab` で生成を確認してから反映する。
   既存の Flux apps が SOPS Secret を復号する。
   暗号化した Secret を `kubectl apply -k` で直接適用しないこと。

## 接続確認

```sh
kubectl -n litellm rollout status deployment/litellm
kubectl -n litellm port-forward service/litellm 4000:4000
```

別のターミナルで `LITELLM_MASTER_KEY` に設定済みの値を読み込み、確認する。

```sh
curl --fail-with-body http://localhost:4000/v1/models \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY"

curl --fail-with-body http://localhost:4000/v1/chat/completions \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  -H 'Content-Type: application/json' \
  -d '{"model":"gemini-flash","messages":[{"role":"user","content":"こんにちは"}]}'
```

`/v1/models` は設定の確認、`/v1/chat/completions` は実際の Gemini API 呼び出しとなる。
probe は外部 API を呼び出さない `/health/liveliness` と `/health/readiness` を使う。

## 設定変更

モデルやプロバイダは `config/config.yaml` の `model_list` に追加する。
API キーは Secret と Deployment の `env` に追加し、設定から `os.environ/変数名` で参照する。
ConfigMap は Kustomize がハッシュ付きで生成し、設定変更時には Deployment が更新される。
Secret だけを変更した場合は、Flux の同期完了後に Pod を再起動する。

```sh
kubectl -n litellm rollout restart deployment/litellm
```

## 参考

- [LiteLLM: Google AI Studio](https://docs.litellm.ai/docs/providers/gemini)
- [LiteLLM: Deployment](https://docs.litellm.ai/docs/proxy/deploy)
- [LiteLLM: Health checks](https://docs.litellm.ai/docs/proxy/health)
- [Gemini API: モデル一覧](https://ai.google.dev/gemini-api/docs/models)
