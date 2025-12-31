# SSM Port Forwarding Scripts

全てのSSMポートフォワーディングを一括で管理するスクリプト群です。

## クイックスタート

```bash
# tmux版（推奨）
make ssm-start-all-tmux    # 起動
make ssm-stop-all-tmux     # 停止

# バックグラウンド版
make ssm-start-all         # 起動
make ssm-status            # 状態確認
make ssm-stop-all          # 停止
```

## スクリプト一覧

### tmux版（推奨）

- `start-all-port-forwarding-tmux.sh`: tmuxセッション内で全ポートフォワーディングを起動
- `stop-all-port-forwarding-tmux.sh`: tmuxセッションを停止

### バックグラウンド版

- `start-all-port-forwarding.sh`: バックグラウンドで全ポートフォワーディングを起動
- `stop-all-port-forwarding.sh`: 全ポートフォワーディングを停止
- `status-port-forwarding.sh`: ポートフォワーディングの状態を確認
- `ssm-port-forward-worker.sh`: ワーカースクリプト（内部使用）

### その他

- `upload-world-to-s3.sh`: MinecraftワールドデータをS3にアップロード

## 詳細ドキュメント

詳細な使い方やトラブルシューティングについては、以下のドキュメントを参照してください：

[📖 PORT_FORWARDING.md](../docs/infrastructure/PORT_FORWARDING.md)

## 対象ポート

- **2222**: MC Server SSH
- **2223**: API Server SSH
- **2224**: Web Server SSH
- **3307**: RDS MySQL
- **5433**: RDS PostgreSQL

