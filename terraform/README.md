# Kishax Infrastructure - Terraform

EC2ベースのコスト最適化インフラストラクチャ

## 📋 概要

このTerraform構成は、旧環境（CloudFormation + ECS/Fargate）から新環境（EC2ベース）への移行を実現します。

### 主な変更点
- **旧環境**: 月額 ¥17,000（企業レベル）
- **新環境**: 月額 ¥6,900（ミドルレベル、約60%削減）

### アーキテクチャ

#### EC2インスタンス（4台）
| インスタンス | タイプ | 稼働時間 | 役割 | 購入オプション |
|-------------|--------|---------|------|--------------|
| **i-a** | t3.large | 22:00-27:00 | Minecraftサーバー | オンデマンド |
| **i-b** | t3.small | 24時間 | API + Redis | スポット |
| **i-c** | t2.micro | 24時間 | Web + Discord Bot | スポット |
| **i-d** | t2.micro | 必要時のみ | RDS踏み台 | オンデマンド |

#### データベース
- **RDS PostgreSQL** (db.t4g.micro): Web, API, Discord Bot用
- **RDS MySQL** (db.t4g.micro): Minecraftサーバー専用

#### その他
- **SQS**: MC ↔ Web通信用キュー
- **CloudFront**: WAF付きCDN（Webアプリ配信）
- **Route53**: DNS管理
- **IAM**: 最小権限の原則に基づくロール

---

## 🚀 デプロイ手順

### 前提条件

1. **AWS CLI設定**
   ```bash
   aws configure sso --profile 126112056177_AdministratorAccess
   aws sso login --profile 126112056177_AdministratorAccess
   ```

2. **Terraform インストール** (v1.5以上)
   ```bash
   brew install terraform  # macOS
   # または
   # https://www.terraform.io/downloads
   ```

3. **必要な情報を準備**
   - Route53 Hosted Zone ID
   - ACM Certificate ARN（us-east-1リージョン、CloudFront用）
   - EC2 Key Pair（SSH接続用）
   - RDS マスターパスワード（PostgreSQL, MySQL）

### Step 1: 旧環境の削除（CloudFormation）

**注意**: データベースのバックアップを取得してから実行してください。

```bash
cd /Users/tk/git/Kishax/infrastructure

# スタック削除
aws cloudformation delete-stack \
  --stack-name kishax-infrastructure \
  --profile 126112056177_AdministratorAccess

# 削除完了を待機
aws cloudformation wait stack-delete-complete \
  --stack-name kishax-infrastructure \
  --profile 126112056177_AdministratorAccess
```

### Step 2: terraform.tfvars 作成

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

`terraform.tfvars` を編集：

```hcl
aws_region  = "ap-northeast-1"
aws_profile = "126112056177_AdministratorAccess"
environment = "production"

# Route53
route53_zone_id = "Z0123456789ABCDEFGHIJ"  # 実際のZone IDに置き換え
mc_domain_name  = "mc.kishax.net"
web_domain_name = "web.kishax.net"

# RDS PostgreSQL
postgres_username = "postgres"
postgres_password = "YOUR_SECURE_PASSWORD"  # 変更必須

# RDS MySQL  
mysql_username = "mysql"
mysql_password = "YOUR_SECURE_PASSWORD"  # 変更必須

# CloudFront
acm_certificate_arn = "arn:aws:acm:us-east-1:126112056177:certificate/xxxxx"

# EC2
ec2_key_pair_name = "kishax-ec2-key"  # 事前作成が必要
```

### Step 3: Terraform 初期化

```bash
cd terraform
terraform init
```

### Step 4: 実行計画の確認

```bash
terraform plan
```

作成されるリソースを確認：
- VPC, サブネット, IGW
- セキュリティグループ（5つ）
- IAMロール（4つ）
- RDS（PostgreSQL, MySQL）
- SQS キュー（6つ）
- EC2インスタンス（4台）
- Elastic IP
- CloudFront Distribution
- Route53レコード

### Step 5: リソース作成

```bash
terraform apply
```

`yes` を入力して実行。

**所要時間**: 約15-20分（RDS作成が最も時間がかかります）

### Step 6: 出力の確認

```bash
terraform output
```

重要な情報が表示されます：
- MC ServerのElastic IP
- RDSエンドポイント
- SQS Queue URL
- CloudFront Domain Name

---

## 📦 デプロイ後の設定

### 1. SSM Parameter Storeの設定

環境変数をSSM Parameter Storeに登録します。

```bash
# Discord Bot Token
aws ssm put-parameter \
  --name /kishax/discord/token \
  --type SecureString \
  --value "YOUR_DISCORD_BOT_TOKEN" \
  --profile 126112056177_AdministratorAccess

# その他の環境変数も同様に登録
```

### 2. EC2インスタンスへのアプリケーションデプロイ

#### i-a (MC Server)

```bash
# SSH接続
ssh -i ~/.ssh/kishax-ec2-key.pem ec2-user@<MC_SERVER_ELASTIC_IP>

# docker-compose.ymlをデプロイ
sudo su - minecraft
cd /opt/minecraft
# compose.ymlをコピー
docker-compose up -d
```

#### i-b (API Server)

```bash
ssh -i ~/.ssh/kishax-ec2-key.pem ec2-user@<API_SERVER_PRIVATE_IP>

sudo su - api
cd /opt/api
# compose.ymlをコピー
docker-compose up -d

# Redis確認
redis-cli ping  # PONG が返ればOK
```

#### i-c (Web + Discord Bot)

```bash
ssh -i ~/.ssh/kishax-ec2-key.pem ec2-user@<WEB_SERVER_PUBLIC_IP>

sudo su - web
cd /opt/web
# compose.ymlをコピー
docker-compose up -d

cd /opt/discord
# compose.ymlをコピー
docker-compose up -d
```

### 3. RDS接続確認

```bash
# Jump Server (i-d) を起動
aws ec2 start-instances \
  --instance-ids <JUMP_SERVER_INSTANCE_ID> \
  --profile 126112056177_AdministratorAccess

# SSM Session Managerで接続
aws ssm start-session \
  --target <JUMP_SERVER_INSTANCE_ID> \
  --profile 126112056177_AdministratorAccess

# PostgreSQL接続テスト
psql -h <POSTGRES_ENDPOINT> -U postgres -d kishax_main

# MySQL接続テスト
mysql -h <MYSQL_ENDPOINT> -u mysql -p
```

---

## 🔧 運用

### MC Server の起動/停止

```bash
# 起動
aws ec2 start-instances \
  --instance-ids <MC_SERVER_INSTANCE_ID> \
  --profile 126112056177_AdministratorAccess

# 停止
aws ec2 stop-instances \
  --instance-ids <MC_SERVER_INSTANCE_ID> \
  --profile 126112056177_AdministratorAccess
```

**注意**: 起動時にRoute53が自動更新されます（User Data）

### スポットインスタンスの中断対応

i-b, i-cはスポットインスタンスなので、稀に中断される可能性があります。

- **自動再起動**: `spot_type = "persistent"` 設定により自動で再起動
- **データ**: RDSに保存されているため、データロスなし
- **ダウンタイム**: 数分程度

### コスト監視

```bash
# 今月の累計コストを確認
make billing-month-to-date
```

---

## 📊 モジュール構成

```
terraform/
├── main.tf                    # メイン設定
├── variables.tf               # 変数定義
├── outputs.tf                 # 出力
├── terraform.tfvars.example   # 変数サンプル
└── modules/
    ├── vpc/                   # VPC, サブネット, IGW
    ├── security_groups/       # セキュリティグループ
    ├── iam/                   # IAMロール, ポリシー
    ├── rds/                   # PostgreSQL, MySQL
    ├── sqs/                   # SQSキュー
    ├── ec2/                   # EC2インスタンス（4台）
    ├── cloudfront/            # CloudFront Distribution
    └── route53/               # Route53レコード
```

---

## ⚠️ 注意事項

### セキュリティ
- **terraform.tfvars** は `.gitignore` に追加済み（パスワード情報を含むため）
- **SSH接続**: セキュリティグループで特定IPのみ許可するよう変更推奨
- **CloudFront**: WAFを有効化する場合は `cloudfront/main.tf` のコメントを解除

### データ保護
- **i-a (MC Server)** のEBSボリュームは `delete_on_termination = false` 設定
- **RDS** のスナップショットは自動作成（3日間保持）
- **最終スナップショット**: Terraform destroy時に自動作成

### コスト最適化
- **スポットインスタンス**: i-b, i-c は約70%削減
- **RDS Savings Plans**: 1年契約で40%追加削減可能
- **CloudFront**: 不要なリージョンは除外済み（PriceClass_200）

---

## 🔄 更新・変更

### インフラ変更の適用

```bash
# 変更内容の確認
terraform plan

# 適用
terraform apply
```

### 状態の確認

```bash
# リソース一覧
terraform state list

# 特定リソースの詳細
terraform state show aws_instance.mc_server
```

---

## 🗑️ 削除

**警告**: すべてのリソースが削除されます。必要なデータはバックアップしてください。

```bash
terraform destroy
```

---

## 📚 参考ドキュメント

- [pre-implement.md](../docs/infrastructure/ec2/pre-implement.md): 実装前仕様書
- [next.md](../docs/infrastructure/ec2/next.md): 要件定義
- [material-iam.md](../docs/infrastructure/ec2/material-iam.md): IAMロール設計

---

## 🆘 トラブルシューティング

### Terraform init エラー

```bash
rm -rf .terraform
terraform init
```

### RDS作成タイムアウト

RDS作成には10-15分かかります。エラーが出た場合は再実行：

```bash
terraform apply
```

### スポットインスタンスが作成されない

スポット価格が高騰している可能性があります。一時的にオンデマンドに変更：

```terraform
# ec2/main.tf
resource "aws_instance" "api_server" {  # spot_instance_request から変更
  # ...
}
```

### Route53更新が反映されない

MC Serverの起動ログを確認：

```bash
ssh ec2-user@<MC_SERVER_IP>
sudo cat /var/log/user-data.log
```

---

**作成日**: 2025-12-12  
**バージョン**: 1.0.0
