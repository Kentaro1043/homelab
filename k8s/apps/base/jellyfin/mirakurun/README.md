# Mirakurun の初期チャンネルスキャン

チャンネルスキャンはデプロイ時には実行しない。PX-S1UD と B-CAS カードリーダーを接続し、
Mirakurun が起動した後に、LAN 内の端末から一度だけ手動で実行する。

```shell
curl --fail-with-body --request PUT \
  'https://mirakurun.internal.kentaro1043.com/api/config/channels/scan?type=GR&async=true'
```

進捗は同じ API の GET で確認する。

```shell
curl --fail-with-body \
  https://mirakurun.internal.kentaro1043.com/api/config/channels/scan
```

`isScanning` が `false` になったら、検出されたチャンネルを確認する。

```shell
curl --fail-with-body \
  https://mirakurun.internal.kentaro1043.com/api/channels
```

設定は `mirakurun-state` PVC に保存されるため、Pod の再作成時にスキャンし直す必要はない。
