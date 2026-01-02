# EC2自動スケジューリング設定

**作成日**: 2026-01-02
**バージョン**: 1.0.0
**対象環境**: Production (ap-northeast-1)

---

## 📋 目次

1. [概要](#概要)
2. [アーキテクチャ](#アーキテクチャ)
3. [スケジュール設定](#スケジュール設定)
4. [Lambda関数](#lambda関数)
5. [EventBridge Scheduler](#eventbridge-scheduler)
6. [手動操作](#手動操作)
7. [トラブルシューティング](#トラブルシューティング)

---

## 概要

22:00-27:00（翌3:00）の間、以下のインスタンスを自動起動・停止します：

- **i-a (MC Server)**: t3.large On-Demand
- **i-b (API Server + Redis)**: t3.small Spot
- **i-c (Web Server)**: t2.micro Spot

### 自動化の流れ

```
22:00 JST → EventBridge Scheduler → Lambda → EC2 Start
27:00 JST → EventBridge Scheduler → Lambda → EC2 Stop
```

---

## アーキテクチャ

### コンポーネント

1. **Lambda関数**: `kishax-production-ec2-scheduler`
   - 機能: EC2インスタンスの起動・停止
   - ランタイム: Python 3.12
   - タイムアウト: 60秒
   - メモリ: 128MB

2. **EventBridge Scheduler**:
   - `kishax-production-start-instances`: 22:00 JST起動
   - `kishax-production-stop-instances`: 03:00 JST停止

3. **IAM Role**:
   - Lambda実行ロール: EC2起動・停止権限
   - Schedulerロール: Lambda呼び出し権限

### ファイル構成

```
terraform/
├── modules/
│   ├── lambda/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── ec2-scheduler.py
│   └── eventbridge/
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
└── main.tf
```

---

## スケジュール設定

### 起動スケジュール

- **時刻**: 22:00 JST (毎日)
- **対象インスタンス**: i-a, i-b, i-c
- **Cron式**: `cron(0 13 * * ? *)` (UTC)
- **タイムゾーン**: Asia/Tokyo

### 停止スケジュール

- **時刻**: 03:00 JST (毎日 = 前日27:00)
- **対象インスタンス**: i-a, i-b, i-c
- **Cron式**: `cron(0 18 * * ? *)` (UTC)
- **タイムゾーン**: Asia/Tokyo

---

## Lambda関数

### 関数詳細

```python
# ec2-scheduler.py
def lambda_handler(event, context):
    """
    EC2インスタンスの起動・停止を実行

    入力パラメータ:
    {
        "action": "start" | "stop",
        "instance_ids": ["i-xxxxx", "i-yyyyy", ...]
    }
    """
```

### IAM権限

Lambda実行ロールに付与されている権限：

- `ec2:StartInstances`
- `ec2:StopInstances`
- `ec2:DescribeInstances`
- `ec2:DescribeInstanceStatus`
- `logs:CreateLogGroup`
- `logs:CreateLogStream`
- `logs:PutLogEvents`

### CloudWatch Logs

- **ロググループ**: `/aws/lambda/kishax-production-ec2-scheduler`
- **保持期間**: 14日間

---

## EventBridge Scheduler

### Scheduler設定

#### Start Scheduler

```hcl
resource "aws_scheduler_schedule" "start_instances" {
  name                         = "kishax-production-start-instances"
  schedule_expression          = "cron(0 13 * * ? *)"
  schedule_expression_timezone = "Asia/Tokyo"

  target {
    arn = lambda_function_arn
    input = {
      action = "start"
      instance_ids = [i-a, i-b, i-c]
    }
  }
}
```

#### Stop Scheduler

```hcl
resource "aws_scheduler_schedule" "stop_instances" {
  name                         = "kishax-production-stop-instances"
  schedule_expression          = "cron(0 18 * * ? *)"
  schedule_expression_timezone = "Asia/Tokyo"

  target {
    arn = lambda_function_arn
    input = {
      action = "stop"
      instance_ids = [i-a, i-b, i-c]
    }
  }
}
```

---

## 手動操作

### Lambda関数を直接実行

```bash
# 手動起動
aws lambda invoke \
  --function-name kishax-production-ec2-scheduler \
  --payload '{"action":"start","instance_ids":["i-xxxxx","i-yyyyy","i-zzzzz"]}' \
  --profile AdministratorAccess-126112056177 \
  response.json

# 手動停止
aws lambda invoke \
  --function-name kishax-production-ec2-scheduler \
  --payload '{"action":"stop","instance_ids":["i-xxxxx","i-yyyyy","i-zzzzz"]}' \
  --profile AdministratorAccess-126112056177 \
  response.json

# レスポンス確認
cat response.json
```

### EventBridge Schedulerの一時無効化

```bash
# Startスケジュールを無効化
aws scheduler update-schedule \
  --name kishax-production-start-instances \
  --state DISABLED \
  --profile AdministratorAccess-126112056177

# Stopスケジュールを無効化
aws scheduler update-schedule \
  --name kishax-production-stop-instances \
  --state DISABLED \
  --profile AdministratorAccess-126112056177

# 再有効化
aws scheduler update-schedule \
  --name kishax-production-start-instances \
  --state ENABLED \
  --profile AdministratorAccess-126112056177
```

### インスタンスIDの確認

```bash
cd /Users/tk/git/Kishax/infrastructure/terraform

# インスタンスID一覧を取得
terraform output mc_server_instance_id
terraform output api_server_instance_id
terraform output web_server_instance_id
```

---

## トラブルシューティング

### Lambda実行ログの確認

```bash
# 最新のログストリームを確認
aws logs describe-log-streams \
  --log-group-name /aws/lambda/kishax-production-ec2-scheduler \
  --order-by LastEventTime \
  --descending \
  --max-items 5 \
  --profile AdministratorAccess-126112056177

# ログ内容を確認
aws logs tail /aws/lambda/kishax-production-ec2-scheduler \
  --follow \
  --profile AdministratorAccess-126112056177
```

### Scheduler実行履歴の確認

```bash
# EventBridge Schedulerの実行履歴は、CloudWatch Logsで確認
aws logs filter-log-events \
  --log-group-name /aws/lambda/kishax-production-ec2-scheduler \
  --start-time $(date -u -d '1 hour ago' +%s)000 \
  --profile AdministratorAccess-126112056177
```

### インスタンスの状態確認

```bash
# インスタンスIDを環境変数に設定
export MC_INSTANCE_ID=$(terraform output -raw mc_server_instance_id)
export API_INSTANCE_ID=$(terraform output -raw api_server_instance_id)
export WEB_INSTANCE_ID=$(terraform output -raw web_server_instance_id)

# 状態確認
aws ec2 describe-instances \
  --instance-ids $MC_INSTANCE_ID $API_INSTANCE_ID $WEB_INSTANCE_ID \
  --query 'Reservations[*].Instances[*].{ID:InstanceId,State:State.Name,Name:Tags[?Key==`Name`].Value|[0]}' \
  --output table \
  --profile AdministratorAccess-126112056177
```

### よくある問題

#### 1. インスタンスが起動しない

**原因**: Spotインスタンスの容量不足

```bash
# Spot Requestの状態確認
aws ec2 describe-spot-instance-requests \
  --filters "Name=instance-id,Values=$INSTANCE_ID" \
  --profile AdministratorAccess-126112056177
```

**対処法**: 一時的にOn-Demandインスタンスに切り替える、または時間をおいて再試行

#### 2. Lambda関数がタイムアウト

**原因**: 多数のインスタンスを同時起動している

**対処法**: タイムアウト時間を延長（現在60秒）

```bash
aws lambda update-function-configuration \
  --function-name kishax-production-ec2-scheduler \
  --timeout 120 \
  --profile AdministratorAccess-126112056177
```

#### 3. 権限エラー

**原因**: IAM Roleの権限不足

**対処法**: Terraform stateとIAM Roleを確認

```bash
cd /Users/tk/git/Kishax/infrastructure/terraform

# Lambda RoleのARNを確認
terraform output ec2_scheduler_function_arn

# IAM Policyを確認
aws iam list-role-policies \
  --role-name kishax-production-ec2-scheduler-lambda-role \
  --profile AdministratorAccess-126112056177
```

---

## コスト

### Lambda料金

- **実行回数**: 2回/日 × 30日 = 60回/月
- **実行時間**: ~1秒/回
- **料金**: 無料枠内（月100万リクエスト、40万GB秒まで無料）

### EventBridge Scheduler料金

- **スケジュール数**: 2個
- **実行回数**: 60回/月（各30回）
- **料金**: 無料（月1,400万回まで無料）

**総コスト**: $0.00/月（無料枠内）

---

## 関連ドキュメント

- [EC2デプロイメント手順書](./deployment.md)
- [.env管理手順](./env-files-management.md)
- [Terraform設定](../../terraform/README.md)
