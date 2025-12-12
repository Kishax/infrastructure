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
   aws configure sso --profile AdministratorAccess-126112056177
   aws sso login --profile AdministratorAccess-126112056177
   
   # 認証確認
   aws sts get-caller-identity --profile AdministratorAccess-126112056177
   ```

2. **Terraform インストール** (v1.5以上)
   ```bash
   brew install terraform  # macOS
   # または
   # https://www.terraform.io/downloads
   
   # バージョン確認
   terraform version
   ```

---

### ⚙️ 事前準備（初回のみ）

**重要**: `terraform init` を実行する前に、以下のAWSリソースを作成する必要があります。

#### 1. Route53 Hosted Zone IDの確認

```bash
# kishax.net のHosted Zone IDを取得
aws route53 list-hosted-zones \
  --profile AdministratorAccess-126112056177 \
  --query 'HostedZones[?Name==`kishax.net.`].Id' \
  --output text

# 出力例: /hostedzone/Z0603702PAMJA0IKZNZP
# terraform.tfvars に設定: route53_zone_id = "Z0603702PAMJA0IKZNZP"
```

#### 2. ACM証明書の作成（CloudFront用、us-east-1必須）

```bash
# 証明書リクエスト
aws acm request-certificate \
  --domain-name kishax.net \
  --subject-alternative-names "*.kishax.net" \
  --validation-method DNS \
  --region us-east-1 \
  --profile AdministratorAccess-126112056177

# 出力されたCertificateArnをメモ
# 例: arn:aws:acm:us-east-1:126112056177:certificate/c690a318-xxxx

# DNS検証レコードを取得
aws acm describe-certificate \
  --certificate-arn <YOUR_CERTIFICATE_ARN> \
  --region us-east-1 \
  --profile AdministratorAccess-126112056177 \
  --query 'Certificate.DomainValidationOptions[0].ResourceRecord'

# 出力例:
# {
#   "Name": "_xxx.kishax.net.",
#   "Type": "CNAME",
#   "Value": "_yyy.acm-validations.aws."
# }

# Route53にDNS検証レコードを追加
aws route53 change-resource-record-sets \
  --hosted-zone-id <YOUR_HOSTED_ZONE_ID> \
  --profile AdministratorAccess-126112056177 \
  --change-batch '{
    "Changes": [{
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "<検証レコードのName>",
        "Type": "CNAME",
        "TTL": 300,
        "ResourceRecords": [{"Value": "<検証レコードのValue>"}]
      }
    }]
  }'

# 証明書の検証完了を待つ（数分かかる場合あり）
aws acm describe-certificate \
  --certificate-arn <YOUR_CERTIFICATE_ARN> \
  --region us-east-1 \
  --profile AdministratorAccess-126112056177 \
  --query 'Certificate.Status' \
  --output text
# 出力が "ISSUED" になればOK

# terraform.tfvars に設定: acm_certificate_arn = "arn:aws:acm:us-east-1:..."
```

#### 3. S3バケット作成（Terraform State用）

```bash
# S3バケット作成
aws s3api create-bucket \
  --bucket kishax-terraform-state \
  --region ap-northeast-1 \
  --create-bucket-configuration LocationConstraint=ap-northeast-1 \
  --profile AdministratorAccess-126112056177

# バージョニング有効化（State履歴管理）
aws s3api put-bucket-versioning \
  --bucket kishax-terraform-state \
  --versioning-configuration Status=Enabled \
  --profile AdministratorAccess-126112056177

# 暗号化設定
aws s3api put-bucket-encryption \
  --bucket kishax-terraform-state \
  --server-side-encryption-configuration '{
    "Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]
  }' \
  --profile AdministratorAccess-126112056177

# バケットの存在確認
aws s3 ls s3://kishax-terraform-state --profile AdministratorAccess-126112056177
```

#### 4. DynamoDB テーブル作成（Terraform Lock用）

```bash
# DynamoDBテーブル作成
aws dynamodb create-table \
  --table-name kishax-terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region ap-northeast-1 \
  --profile AdministratorAccess-126112056177

# テーブルの状態確認（STATUSがACTIVEになるまで待つ）
aws dynamodb describe-table \
  --table-name kishax-terraform-locks \
  --region ap-northeast-1 \
  --profile AdministratorAccess-126112056177 \
  --query 'Table.TableStatus' \
  --output text
```

#### 5. EC2 Key Pair作成（SSH接続用）

```bash
# キーペア作成（既に作成済みの場合はスキップ）
aws ec2 create-key-pair \
  --key-name minecraft \
  --profile AdministratorAccess-126112056177 \
  --query 'KeyMaterial' \
  --output text > ~/.ssh/minecraft.pem

# パーミッション設定
chmod 400 ~/.ssh/minecraft.pem

# terraform.tfvars に設定: ec2_key_pair_name = "minecraft"
```

---

### 📝 terraform.tfvars の作成

事前準備が完了したら、`terraform.tfvars` を作成します。

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

`terraform.tfvars` を編集：

```hcl
aws_region  = "ap-northeast-1"
aws_profile = "AdministratorAccess-126112056177"
environment = "production"

# VPC
vpc_cidr = "10.0.0.0/16"

# Route53（ステップ1で取得）
route53_zone_id = "Z0603702PAMJA0IKZNZP"
mc_domain_name  = "mc.kishax.net"
web_domain_name = "kishax.net"

# RDS PostgreSQL（パスワードは強固なものに変更）
postgres_instance_class    = "db.t4g.micro"
postgres_allocated_storage = 20
postgres_db_name           = "kishax_main"
postgres_username          = "postgres"
postgres_password          = "YOUR_SECURE_PASSWORD_HERE"

# RDS MySQL（パスワードは強固なものに変更）
mysql_instance_class    = "db.t4g.micro"
mysql_allocated_storage = 20
mysql_db_name           = "kishax_mc"
mysql_username          = "mysql"
mysql_password          = "YOUR_SECURE_PASSWORD_HERE"

# CloudFront（ステップ2で取得）
acm_certificate_arn = "arn:aws:acm:us-east-1:126112056177:certificate/c690a318-xxxx"

# EC2（ステップ5で作成）
ec2_key_pair_name = "minecraft"
```

---

### 🔧 Terraform初期化と実行

### 🔧 Terraform初期化と実行

#### Step 1: バックエンド初期化

```bash
cd terraform

# Terraform初期化（S3バックエンド設定）
terraform init

# 出力例:
# Successfully configured the backend "s3"!
# Terraform has been successfully initialized!
```

**注**: 初回実行時、ローカルのStateファイルをS3に移行するか聞かれた場合は `yes` を入力してください。

#### Step 2: 実行計画の確認

```bash
# 実行計画を生成
terraform plan -out=tfplan

# 作成されるリソース数を確認
# Plan: XX to add, 0 to change, 0 to destroy.
```

**確認ポイント**:
- VPC, サブネット（4つ）
- セキュリティグループ（5つ）
- IAMロール（4つ）
- RDS（PostgreSQL, MySQL）
- SQS（6つ）
- EC2（4台）
- Elastic IP（1つ）
- CloudFront Distribution
- Route53レコード（2つ）

#### Step 3: リソース作成

```bash
# 実行（yes を入力）
terraform apply tfplan

# または、planなしで直接実行
terraform apply
```

**所要時間**: 約15-20分（RDS作成が最も時間がかかります）

#### Step 4: 出力の確認

```bash
# 重要な情報を表示
terraform output

# 特定の出力のみ表示
terraform output mc_server_elastic_ip
terraform output postgres_endpoint
```

**保存推奨の出力**:
- `mc_server_elastic_ip`: Minecraftサーバーの固定IP
- `postgres_endpoint`: PostgreSQL接続先
- `mysql_endpoint`: MySQL接続先
- `to_mc_queue_url`, `to_web_queue_url`: SQSキューURL

---

### 🔄 既存環境からの移行（初回のみ）

#### 旧CloudFormationスタックの確認と削除

```bash
# スタックの存在確認
aws cloudformation describe-stacks \
  --stack-name kishax-infrastructure \
  --profile AdministratorAccess-126112056177 \
  --query 'Stacks[0].StackStatus' \
  --output text

# スタック削除（RDSのバックアップを取得してから実行）
aws cloudformation delete-stack \
  --stack-name kishax-infrastructure \
  --profile AdministratorAccess-126112056177

# 削除完了を待機（10-20分程度）
aws cloudformation wait stack-delete-complete \
  --stack-name kishax-infrastructure \
  --profile AdministratorAccess-126112056177
```

**注意**: スタック削除後、Terraform applyを実行してください。

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
