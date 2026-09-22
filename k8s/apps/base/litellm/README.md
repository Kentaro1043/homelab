# LiteLLM

Google AI Studio・OpenRouter・Groq・Ollama Cloud・Cohere を OpenAI 互換 API として公開する。
LiteLLM v1.101.0、1 replica と CloudNativePG の PostgreSQL を使用する。
API は Master Key または UI で発行した Virtual Key で認証する。

| クライアントから指定するモデル | 接続先 |
| --- | --- |
| `gemini-3.8-flash` | Google AI Studio |
| `gemini-3.5-flash-lite` | Google AI Studio |
| `gemma-4-31b-it` | OpenRouter → Ollama Cloud → Google AI Studio |
| `gemma-4-26b-a4b-it` | OpenRouter 優先 / Google AI Studio 予備 |
| `qwen3.8-27b` | Groq 優先 / OpenRouter 無料版 予備 |
| `glm-5.2` | OpenRouter 無料版 |
| `gpt-oss-20b` | Groq → Ollama Cloud |
| `gpt-oss-120b` | Groq → Ollama Cloud |
| `nemotron-3-nano-30b` | Ollama Cloud |
| `nemotron-3-super-120b-a12b` | OpenRouter → Ollama Cloud |
| `nemotron-3-ultra-550b-a55b` | OpenRouter → Ollama Cloud |
| `nemotron-3-nano-omni-30b-a3b-reasoning` | OpenRouter 無料版 |
| `nemotron-3.5-lightning` | OpenRouter 無料版 |
| `nemotron-3.5-content-safety` | OpenRouter 無料版（安全性分類） |
| `north-mini-code` | OpenRouter 無料版 → Cohere 直接接続 |

モデル名にはバージョンを含め、異なるバージョン間の自動切り替えは行わない。
同じモデルの複数プロバイダは同じ `model_name` に登録し、`order` の小さい接続先を優先する。
Gemma 31B は OpenRouter → Ollama Cloud → Google AI Studio、26B は OpenRouter → Google AI Studio。
接続障害・レート制限やクールダウン時には、同じモデルの次の接続先を使用する。
GPT-OSS は Groq → Ollama Cloud、Nemotron 3 Super / Ultra は OpenRouter → Ollama Cloud。
North Mini Code は OpenRouter → Cohere の順に使用し、接続先を同じ場所にまとめる。
Cohere のモデルIDは `north-mini-code-1-0`（1.0）を明示する。
既存クライアント向けの公開名 `north-mini-code` は継続して使用する。
Cohere は Trial API キーを使用する。North Mini Code は Trial / Production のどちらも
レート制限までは無料だが、他の Cohere モデルには自動切り替えしない。
Nemotron 3 Nano 30B と Nano Omni 30B は別モデルとして扱い、自動切り替えしない。
Gemini モデルは Google AI Studio のみを使用する。
OpenRouter の Gemma は `google/gemma-4-31b-it:free` と `google/gemma-4-26b-a4b-it:free` を使用する。
無料モデルが利用できない場合も、OpenRouter の有料モデルへは切り替えない。
Qwen3.8 27B は Groq を優先し、利用できない場合は同じバージョンの
`openrouter/qwen/qwen3.8-27b:free` に切り替える。
GLM は `openrouter/z-ai/glm-5.2:free` を使用する。
Groq は Free Plan の API キーを使用する。Groq には `:free` のモデルIDはなく、
無料利用はアカウントのプランに依存するため、manifest では課金状態を制御できない。
Groq の Qwen は Preview モデル。レート制限は Groq Console の Limits で確認する。
Google 側は無料枠のプロジェクトの API キーを使用する。
LiteLLM の manifest から Google プロジェクトの課金状態は制御できないため、
有料枠のプロジェクトのキーは設定しない。

Ollama Cloud は `https://ollama.com/v1` の OpenAI 互換 API を使用し、Ollama の Pod は不要。
無料クレジット対象の `gemma4:31b`、`gpt-oss:20b`、`gpt-oss:120b`、
`nemotron-3-nano:30b`、`nemotron-3-super`、`nemotron-3-ultra` のみ登録する。
Free アカウントのキーを使用し、有料クレジット購入・自動課金は有効にしない。
無料残量は Ollama のユーザーページで確認する。manifest から課金状態は制御できない。
OpenRouter の Nemotron / Cohere もすべて `:free` のみを使用する。

接続先は `https://litellm.internal.kentaro1043.com/v1`。
既存の内部サービスと同じ Traefik Ingress と `homelab-ca` の TLS 証明書を使用する。
内部 DNS でこのホスト名を Traefik に向け、クライアントで homelab CA を信頼させる。
クラスタ内からは `http://litellm.litellm.svc.cluster.local:4000/v1` でも接続できる。
Google AI Studio は外部 API のため、クラスタ内へのインストールは不要。

## Secret の準備と Flux への追加

現在は Flux apps に登録済み。キーを追加した場合は暗号化 Secret と Deployment の参照を
同じコミットで更新する。新しいキーが未設定のまま Push しない。
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
     GROQ_API_KEY: REPLACE_WITH_GROQ_API_KEY
     OLLAMA_API_KEY: REPLACE_WITH_OLLAMA_API_KEY
     COHERE_API_KEY: REPLACE_WITH_COHERE_API_KEY
   ```

2. 作業用ファイルの `GEMINI_API_KEY` を [Google AI Studio](https://aistudio.google.com/apikey) の
   API キーに、`OPENROUTER_API_KEY` を [OpenRouter](https://openrouter.ai/settings/keys) の
   API キーに置き換える。`LITELLM_MASTER_KEY` には `sk-` で始まるランダムな値を設定する。
   `GROQ_API_KEY` には [Groq Console](https://console.groq.com/keys) の API キーを設定する。
   `OLLAMA_API_KEY` には [Ollama](https://ollama.com/settings/keys) の API キーを設定する。
   `COHERE_API_KEY` には [Cohere](https://dashboard.cohere.com/api-keys) の Trial API キーを設定する。
   例えば `openssl rand -hex 32` の出力に `sk-` を付ける。
   `LITELLM_SALT_KEY` と `UI_PASSWORD` にも、それぞれ別のランダムな値を設定する。
   `LITELLM_SALT_KEY` は DB 内の認証情報の暗号化に使用するため、運用開始後は変更しない。
   DB の接続情報は CloudNativePG が `litellm-postgres-app` Secret に自動生成する。
   `DATABASE_URL` を手動で作成する必要はない。

3. 既存の `.sops.yaml` の age 公開鍵で暗号化する。

   ```sh
   sops --encrypt k8s/apps/base/litellm/secrets/litellm-secrets.yaml > k8s/apps/base/litellm/secrets/litellm-secrets.enc.yaml
   ```

4. 暗号化 Secret と設定の変更を同じコミットに含める。
   `secrets/litellm-secrets.enc.yaml` と `../base/litellm` は既に Kustomization に登録済み。

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
- [LiteLLM: Groq](https://docs.litellm.ai/docs/providers/groq)
- [Groq: モデル一覧](https://console.groq.com/docs/models)
- [Groq: Free Plan のレート制限](https://console.groq.com/docs/rate-limits)
- [LiteLLM: 管理 UI](https://docs.litellm.ai/docs/proxy/ui)
- [LiteLLM: 使用量ログ](https://docs.litellm.ai/docs/proxy/ui_logs)
- [CloudNativePG: アプリケーション接続](https://cloudnative-pg.io/docs/devel/applications/)

- [Ollama Cloud: OpenAI 互換 API](https://docs.ollama.com/api/openai-compatibility)
- [Ollama: 料金・無料枠](https://ollama.com/pricing)
- [OpenRouter: モデル一覧 API](https://openrouter.ai/api/v1/models)

- [LiteLLM: Cohere](https://docs.litellm.ai/docs/providers/cohere)
- [Cohere: North Mini Code 1.0](https://docs.cohere.com/docs/north-mini-code-1.0)
- [Cohere: レート制限](https://docs.cohere.com/docs/rate-limits)
