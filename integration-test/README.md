# Player Event Tests 統合テスト

プレイヤーイベント（join/leave）の統合テストを実行するためのテストスイートです。

## 概要

このテストスイートは、Minecraftプレイヤーの参加・離脱イベントがDiscord Botまで正しく伝達されるかを検証します。

### テストフロー
```
Minecraft Plugin → API Gateway → Lambda → SQS → Discord Bot
```

## テスト内容

### 1. プレイヤー参加イベントテスト (`shouldSendPlayerJoinEventAndReceiveInSqs`)
- **目的**: プレイヤー参加イベントがDiscord Botまで正しく伝達される
- **フロー**: 
  1. `player_event` (eventType: join) メッセージを API Gateway に送信
  2. SQSからメッセージ受信を確認
  3. Discord Bot処理をシミュレート

### 2. プレイヤー離脱イベントテスト (`shouldSendPlayerLeaveEventAndReceiveInSqs`)
- **目的**: プレイヤー離脱イベントがDiscord Botまで正しく伝達される
- **フロー**:
  1. `player_event` (eventType: leave) メッセージを API Gateway に送信
  2. SQSからメッセージ受信を確認
  3. Discord Bot処理をシミュレート

### 3. 複数プレイヤーイベント処理テスト (`shouldHandleMultiplePlayerEventsViaApiGateway`)
- **目的**: 複数のプレイヤーイベントを並行処理できる
- **フロー**:
  1. join/leaveイベントを並行送信
  2. 各イベントが正しく処理される
  3. Discord Bot処理をシミュレート

## セットアップ

### 前提条件
- Java 21
- AWS CLI設定済み
- `.env`ファイル設定済み

### 環境変数
```bash
cp .env.example .env
# 以下の環境変数を設定
AWS_PROFILE=your-profile
AWS_REGION=ap-northeast-1
AWS_ACCOUNT_ID=123456789012
AWS_API_GATEWAY_ID=your-api-gateway-id
DISCORD_CHANNEL_ID=your-discord-channel-id
```

### ビルド
```bash
./gradlew clean build --info
```

## テスト実行

### 全テスト実行
```bash
make test-player-events
```

### 個別テスト実行
```bash
# プレイヤー参加イベント
make test-player-join

# プレイヤー離脱イベント
make test-player-leave

# 複数イベント処理
make test-multiple-player-events
```

### ヘルプ表示
```bash
make help
```

## テスト結果確認

### レポート表示
```bash
make test-report
```

### テスト結果クリア
```bash
make clean-test
```

## トラブルシューティング

### AWS接続確認
```bash
make debug-aws
```

### 環境セットアップ確認
```bash
make setup-test
```

### よくある問題

1. **AWS認証エラー**
   ```bash
   aws sso login --profile your-profile
   ```

2. **API Gateway接続エラー**
   - `.env`ファイルの`AWS_API_GATEWAY_ID`を確認
   - API Gatewayが正しくデプロイされているか確認

3. **SQS接続エラー**
   - SQSキューが存在するか確認
   - IAMポリシーでSQS権限があるか確認

## ファイル構成

```
aws/integration-test/
├── build.gradle                    # Gradleビルド設定
├── Makefile                        # テスト実行用Makefile
├── README.md                       # このファイル
├── src/test/java/
│   └── net/kishax/integration/
│       ├── TestConfig.java         # テスト設定
│       └── TestUtils.java          # テストユーティリティ
├── discord-bot/src/test/java/
│   └── net/kishax/integration/
│       └── DiscordBotSqsTest.java  # メインテストクラス
└── web-mc-communication/src/test/java/
    └── net/kishax/integration/
        └── BaseIntegrationTest.java # テストベースクラス
```

## 技術詳細

### 認証方式
- AWS Signature V4を使用したIAM認証
- 実際のMinecraftプラグインと同じ認証方式

### テスト分離
- `testId`を使用してテスト間のメッセージ分離を実現
- 各テストで一意のプレイヤー名・UUIDを使用

### Discord Bot処理
- 実際のDiscord APIには送信せず、ログ出力でシミュレート
- テスト用途に特化した安全な実装

