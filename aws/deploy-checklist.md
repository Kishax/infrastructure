# Kishax Web-MC双方向通信システム デプロイチェックリスト

## 事前確認事項

### 1. AWSアカウント設定
- [ ] 適切なIAMユーザー/ロールでの認証設定
- [ ] CloudFormation実行権限の確認
- [ ] SQS、Lambda、API Gateway、ECSの作成権限確認

### 2. 既存システム影響確認
- [ ] 現在のDiscord Bot動作確認
- [ ] 既存SQSキューの稼働状況確認
- [ ] ECS タスクの稼働状況確認

## CloudFormationテンプレート確認

### 3. テンプレート検証
- [ ] CloudFormation テンプレートの構文確認
```bash
aws cloudformation validate-template --template-body file://cloudformation-template.yaml
```

- [ ] パラメータファイルの確認
```bash
# cloudformation-parameters.json の内容確認
cat cloudformation-parameters.json
```

### 4. 新規リソース確認
- [ ] WebToMcQueue の設定
- [ ] McToWebQueue の設定
- [ ] 新しいAPI Gatewayエンドポイント（/web-to-mc, /mc-to-web）
- [ ] Lambda関数の拡張機能

## SSMパラメータ設定

### 5. 新規パラメータ作成
以下のSSMパラメータを設定する必要があります：

**必須パラメータ:**
- `/kishax/sqs/web-to-mc-queue-url` - Web→MC通信用SQS URL
- `/kishax/sqs/mc-to-web-queue-url` - MC→Web通信用SQS URL

**任意パラメータ（既存のものも含む）:**
- `/kishax/sqs/queue-url` - Discord Bot用（既存）
- `/kishax/web/mc-socket-host` - フォールバック用Socket通信（既存）
- `/kishax/web/mc-socket-port` - フォールバック用Socket通信（既存）

### 6. デプロイ後の自動パラメータ設定
CloudFormationデプロイ後、以下のスクリプトでパラメータを自動設定：

```bash
# スタック名を環境変数として設定
export STACK_NAME=kishax-infrastructure-v2

# SQS URLをSSMパラメータに設定
aws ssm put-parameter --name "/kishax/sqs/web-to-mc-queue-url" \
    --value "$(aws cloudformation describe-stacks --stack-name $STACK_NAME \
    --query 'Stacks[0].Outputs[?OutputKey==`WebToMcQueueUrl`].OutputValue' --output text)" \
    --type "String" --overwrite

aws ssm put-parameter --name "/kishax/sqs/mc-to-web-queue-url" \
    --value "$(aws cloudformation describe-stacks --stack-name $STACK_NAME \
    --query 'Stacks[0].Outputs[?OutputKey==`McToWebQueueUrl`].OutputValue' --output text)" \
    --type "String" --overwrite
```

## Lambda関数更新

### 7. Lambda関数コード更新
- [ ] Lambdaコードをzip化
```bash
cd aws/lambda/sqs-forwarder
zip -r lambda-function.zip index.js package.json
```

- [ ] Lambda関数更新
```bash
aws lambda update-function-code --function-name kishax-infrastructure-lambda \
    --zip-file fileb://lambda-function.zip
```

## ECS タスクとWeb環境更新

### 8. 環境変数設定
**kishax-web ECSタスク:**
- [ ] `NEXT_PUBLIC_API_GATEWAY_URL` - API Gateway URL
- [ ] `MC_TO_WEB_QUEUE_URL` - SQSポーリング用
- [ ] `AWS_REGION` - AWSリージョン設定

**mc-plugins設定:**
- [ ] AWS認証情報設定（IAMロールまたは環境変数）
- [ ] SQSキューURL設定
- [ ] リージョン設定

## テスト実行

### 9. 統合テスト実行
- [ ] 統合テスト環境セットアップ
```bash
cd aws/integration-test
./gradlew clean test
```

- [ ] Web-MC双方向通信テスト
```bash
./gradlew test --tests "*WebMcCommunicationTest*"
```

- [ ] MC認証エンドツーエンドテスト
```bash
./gradlew test --tests "*McAuthEndToEndTest*"
```

### 10. 手動テスト項目
- [ ] Web画面からMC認証フローテスト
- [ ] MC側からWeb認証完了レスポンステスト
- [ ] 既存Discord Bot機能に影響がないことを確認
- [ ] エラーハンドリング動作確認

## 稼働監視設定

### 11. CloudWatch設定
- [ ] 新規SQSキューのメトリクス確認
- [ ] Lambda関数のエラーログ監視
- [ ] API Gatewayのアクセスログ確認

### 12. アラート設定
- [ ] SQS DLQ（Dead Letter Queue）監視
- [ ] Lambda関数エラー率監視
- [ ] ECS タスクヘルスチェック

## ロールバック準備

### 13. ロールバック手順確認
- [ ] 既存CloudFormationスタックのバックアップ
- [ ] 設定変更のロールバック手順書作成
- [ ] 緊急時連絡体制確認

## デプロイ後確認

### 14. 本番環境動作確認
- [ ] 全APIエンドポイントのヘルスチェック
- [ ] SQSメッセージフロー確認
- [ ] 既存機能の動作確認
- [ ] パフォーマンス確認

### 15. ドキュメント更新
- [ ] システム構成図更新
- [ ] API仕様書更新
- [ ] 運用手順書更新

## 完了チェック
- [ ] すべてのテストがパス
- [ ] 監視設定完了
- [ ] ドキュメント更新完了
- [ ] ステークホルダーへの完了報告

---

## 緊急連絡先
- システム管理者: [連絡先]
- AWS担当者: [連絡先]  
- 開発チーム: [連絡先]

## 参考リンク
- CloudFormationテンプレート: `aws/cloudformation-template.yaml`
- 統合テスト: `aws/integration-test/`
- Lambda関数: `aws/lambda/sqs-forwarder/`