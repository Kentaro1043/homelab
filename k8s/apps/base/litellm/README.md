# LiteLLM

Google AI Studio と OpenRouter を OpenAI 互換 API として公開する。
LiteLLM v1.101.0、1 replica と CloudNativePG の PostgreSQL を使用する。
API は Master Key または UI で発行した Virtual Key で認証する。

| クライアントから指定するモデル | 接続先 |
| --- | --- |
| `gemini-3.8-flash` | Google AI Studio |
| `gemini-3.5-flash-lite` | Google AI Studio |
| `gemma-4-31b-it` | OpenRouter 優先 / Google AI Studio 予備 |
| `gemma-4-26b-a4b-it` | OpenRouter 優先 / Google AI Studio 予備 |

モデル名にはバージョンを含め、異なるバージョン間の自動切り替えは行わない。
Gemma は同じ `model_name` に Google と OpenRouter の接続先を登録する。
`order: 1` の OpenRouter を優先し、接続障害やレート制限などで再試行後も利用できない場合、
同じバージョンの `order: 2` の Google AI Studio へフォールバックする。
OpenRouter がクールダウン中も利用可能な Google 側を使用する。
Gemini モデルは Google AI Studio のみを使用する。
OpenRouter は `google/gemma-4-31b-it:free` と `google/gemma-4-26b-a4b-it:free` のみ使用する。
無料モデルが利用できない場合も、OpenRouter の有料モデルへは切り替えない。
Google 側は無料枠のプロジェクトの API キーを使用する。
LiteLLM の manifest から Google プロジェクトの課金状態は制御できないため、
有料枠のプロジェクトのキーは設定しない。

接続先は `https://litellm.internal.kentaro1043.com/v1`。
既存の内部サービスと同じ Traefik Ingress と `homelab-ca` の TLS 証明書を使用する。
内部 DNS でこのホスト名を Traefik に向け、クライアントで homelab CA を信頼させる。
クラスタ内からは `http://litellm.litellm.svc.cluster.local:4000/v1` でも接続できる。
Google AI Studio は外部 API のため、クラスタ内へのインストールは不要。

## Secret の準備と Flux への追加

API キーが未設定の Pod で既存の Flux apps の Ready 判定を妨げないよう、
初期状態では `k8s/apps/homelab/kustomization.yaml` に登録していない。
以下はリポジトリのルートで実行する。

1. 作業用ファイル `k8s/apps/base/litellm/secrets/litellm-secrets.yaml` を編集する。
   `secrets/` 内の平文ファイルは既存の `.gitignore` で除外されるため、コミットしない。
   別の checkout で新しく作成する場合の雛形は以下のとおり。

   ```yaml
   apiVersion: v1
   kind: Secret
   metadata:
     name: litellm-secrets
     namespace: litellm
   type: Opaque
   stringData:
     LITELLM_MASTER_KEY: REPLACE_WITH_RANDOM_SK_KEY
     LITELLM_SALT_KEY: REPLACE_WITH_RANDOM_SALT_KEY
     UI_PASSWORD: REPLACE_WITH_RANDOM_UI_PASSWORD
     GEMINI_API_KEY: REPLACE_WITH_GOOGLE_AI_STUDIO_API_KEY
     OPENROUTER_API_KEY: REPLACE_WITH_OPENROUTER_API_KEY
   ```

2. 作業用ファイルの `GEMINI_API_KEY` を [Google AI Studio](https://aistudio.google.com/apikey) の
   API キーに、`OPENROUTER_API_KEY` を [OpenRouter](https://openrouter.ai/settings/keys) の
   API キーに置き換える。`LITELLM_MASTER_KEY` には `sk-` で始まるランダムな値を設定する。
   例えば `openssl rand -hex 32` の出力に `sk-` を付ける。
   `LITELLM_SALT_KEY` と `UI_PASSWORD` にも、それぞれ別のランダムな値を設定する。
   `LITELLM_SALT_KEY` は DB 内の認証情報の暗号化に使用するため、運用開始後は変更しない。
   DB の接続情報は CloudNativePG が `litellm-postgres-app` Secret に自動生成する。
   `DATABASE_URL` を手動で作成する必要はない。

3. 既存の `.sops.yaml` の age 公開鍵で暗号化する。

   ```sh
   sops --encrypt k8s/apps/base/litellm/secrets/litellm-secrets.yaml > k8s/apps/base/litellm/secrets/litellm-secrets.enc.yaml
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
kubectl -n litellm wait --for=condition=Ready cluster/litellm-postgres --timeout=600s
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
  -d '{"model":"gemini-3.8-flash","messages":[{"role":"user","content":"こんにちは"}]}'

curl --fail-with-body http://localhost:4000/v1/chat/completions \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  -H 'Content-Type: application/json' \
  -d '{"model":"gemma-4-31b-it","messages":[{"role":"user","content":"こんにちは"}]}'
```

`/v1/models` は設定の確認、`/v1/chat/completions` は実際の外部 API 呼び出しとなる。
probe は外部 API を呼び出さない `/health/liveliness` と `/health/readiness` を使う。

## 管理 UI と使用量

`https://litellm.internal.kentaro1043.com/ui` を開き、ユーザー名 `admin` と
Secret の `UI_PASSWORD` で初期ログインする。UI は LiteLLM の同じコンテナが配信する。

- Virtual Keys でアプリ別のキーを発行し、クライアントの Master Key を置き換える。
- Usage でモデル・キー別の使用量を確認する。
- Logs で個別リクエストのトークン数、成功・失敗、応答時間を確認する。

使用量・エラーログは DB に保存する。リクエストとレスポンスの本文保存は無効。
詳細ログは30日保持し、1日ごとに古いログを削除する。
使用量表示はこの Proxy を経由したリクエストが対象で、プロバイダ全体の無料枠残量ではない。
費用表示は LiteLLM の見積もりであり、特に Google の Free Tier の実際の請求額とは異なる場合がある。
モデルと無料経路の設定は引き続き `config/config.yaml` で管理する。

初期ログイン後は Internal Users で個人用の `proxy_admin` アカウントを作成できる。
そのアカウントでログインできることを確認してから、`general_settings` に
`disable_env_credential_login: true` を追加すると、環境変数による共通ログインを無効化できる。

## PostgreSQL の運用

既存の CloudNativePG Operator が `litellm-postgres` を管理し、`nfs-homelab` に5Giを確保する。
DB 名・所有ユーザーは `litellm`、接続先は `litellm-postgres-rw`。
単一インスタンス構成で、自動バックアップはこの manifest には含めていない。
DB の復旧に備える場合は、データに加え `LITELLM_SALT_KEY` も保管する。

LiteLLM は起動時にマイグレーションを実行し、失敗時は起動を中断する。
`Recreate` で旧 Pod を停止してから起動するため、更新時には短い停止が発生する。
DB の初期作成中は Secret や接続先の準備を待ち、準備後に起動する。
イメージ更新前には DB をバックアップする。

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
- [Google AI Studio: Gemma](https://ai.google.dev/gemma/docs/core/gemma_on_gemini_api)
- [LiteLLM: OpenRouter](https://docs.litellm.ai/docs/providers/openrouter)
- [LiteLLM: Routing](https://docs.litellm.ai/docs/routing)
- [LiteLLM: 管理 UI](https://docs.litellm.ai/docs/proxy/ui)
- [LiteLLM: 使用量ログ](https://docs.litellm.ai/docs/proxy/ui_logs)
- [CloudNativePG: アプリケーション接続](https://cloudnative-pg.io/docs/devel/applications/)
