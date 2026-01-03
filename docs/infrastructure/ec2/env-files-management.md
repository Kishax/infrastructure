# .envファイル管理手順

**作成日**: 2026-01-02
**バージョン**: 1.0.0
**対象環境**: Production (ap-northeast-1)

---

## 📋 目次

1. [概要](#概要)
2. [S3バケット構成](#s3バケット構成)
3. [.envファイルのアップロード](#envファイルのアップロード)
4. [.envファイルの更新](#envファイルの更新)
5. [セキュリティベストプラクティス](#セキュリティベストプラクティス)
6. [トラブルシューティング](#トラブルシューティング)

---

## 概要

各EC2インスタンスの`.env`ファイルはS3バケット `kishax-production-env-files` で管理されます。

### アーキテクチャ

```
S3バケット: kishax-production-env-files
├─ i-a/mc/.env         (MC Server)
├─ i-b/api/.env        (API Server)
└─ i-c/web/.env        (Web Server)

インスタンス起動時:
1. user-dataスクリプト実行
2. GitHubからソースコードclone
3. S3から.envダウンロード
4. Dockerコンテナ起動
```

### セキュリティ

- **暗号化**: SSE-S3（サーバー側暗号化）
- **バージョニング**: 有効（誤削除防止）
- **アクセス制御**: EC2インスタンスのIAM Roleのみ読み取り可能
- **パブリックアクセス**: 完全ブロック

---

## S3バケット構成

### バケット情報

```bash
cd /Users/tk/git/Kishax/infrastructure/terraform

# バケット名を確認
terraform output s3_env_files_bucket_name
# Output: kishax-production-env-files

# バケットARNを確認
terraform output s3_env_files_bucket_arn
# Output: arn:aws:s3:::kishax-production-env-files
```

### ディレクトリ構造

```
s3://kishax-production-env-files/
├── i-a/
│   └── mc/
│       └── .env           # MC Server環境変数
├── i-b/
│   └── api/
│       └── .env           # API Server環境変数
└── i-c/
    └── web/
        └── .env           # Web Server環境変数
```

---

## .envファイルのアップロード

### 初回アップロード

#### 1. ローカルで.envファイルを準備

各アプリケーションのリポジトリから`.env.example`をコピーして作成します。

```bash
# MC Server (.env)
cd /Users/tk/git/Kishax/kishax/
cp .env.example .env
# 必要な環境変数を編集
vim .env
```

#### 2. S3にアップロード

```bash
# AWS SSO ログイン
make login
# または
aws sso login --profile AdministratorAccess-126112056177

# MC Server .env アップロード
aws s3 cp /Users/tk/git/Kishax/kishax/.env \
  s3://kishax-production-env-files/i-a/mc/.env \
  --profile AdministratorAccess-126112056177

# API Server .env アップロード
aws s3 cp /Users/tk/git/Kishax/kishax-api/.env \
  s3://kishax-production-env-files/i-b/api/.env \
  --profile AdministratorAccess-126112056177

# Web Server .env アップロード
aws s3 cp /Users/tk/git/Kishax/kishax-web/.env \
  s3://kishax-production-env-files/i-c/web/.env \
  --profile AdministratorAccess-126112056177
```

#### 3. アップロード確認

```bash
# S3バケット内のファイル一覧を確認
aws s3 ls s3://kishax-production-env-files/ --recursive \
  --profile AdministratorAccess-126112056177

# 出力例:
# 2026-01-02 12:00:00       1234 i-a/mc/.env
# 2026-01-02 12:00:10       2345 i-b/api/.env
# 2026-01-02 12:00:20       3456 i-c/web/.env
```

---

## .envファイルの更新

### 更新手順

#### 1. ローカルで.envファイルを編集

```bash
# 例: MC Server .env を更新
cd /Users/tk/git/Kishax/kishax/
vim .env
# 環境変数を編集
```

#### 2. S3に再アップロード

```bash
# 更新した.envをS3にアップロード
aws s3 cp /Users/tk/git/Kishax/kishax/.env \
  s3://kishax-production-env-files/i-a/mc/.env \
  --profile AdministratorAccess-126112056177

# バージョニングが有効なため、古いバージョンは保持されます
```

#### 3. EC2インスタンスに反映

**方法1: インスタンス再起動**

```bash
# インスタンスIDを取得
cd /Users/tk/git/Kishax/infrastructure/terraform
export MC_INSTANCE_ID=$(terraform output -raw mc_server_instance_id)

# インスタンスを再起動（user-dataが再実行され、最新.envがダウンロードされる）
aws ec2 reboot-instances \
  --instance-ids $MC_INSTANCE_ID \
  --profile AdministratorAccess-126112056177
```

**方法2: 手動ダウンロード + サービス再起動**

```bash
# SSM Session Managerでインスタンスに接続
aws ssm start-session \
  --target $MC_INSTANCE_ID \
  --profile AdministratorAccess-126112056177

# インスタンス内で実行
sudo -i
cd /opt/mc
aws s3 cp s3://kishax-production-env-files/i-a/mc/.env .env --region ap-northeast-1
chmod 600 .env
chown minecraft:minecraft .env

# Dockerコンテナ再起動
systemctl restart minecraft

# 確認
systemctl status minecraft
```

### バージョン管理

#### 過去バージョンの確認

```bash
# バージョン一覧を確認
aws s3api list-object-versions \
  --bucket kishax-production-env-files \
  --prefix i-a/mc/.env \
  --profile AdministratorAccess-126112056177

# 出力例:
# {
#     "Versions": [
#         {
#             "VersionId": "abc123...",
#             "LastModified": "2026-01-02T12:00:00.000Z",
#             "Size": 1234
#         },
#         {
#             "VersionId": "def456...",
#             "LastModified": "2026-01-01T12:00:00.000Z",
#             "Size": 1200
#         }
#     ]
# }
```

#### 過去バージョンの復元

```bash
# 特定バージョンをダウンロード
aws s3api get-object \
  --bucket kishax-production-env-files \
  --key i-a/mc/.env \
  --version-id def456... \
  /tmp/.env.old \
  --profile AdministratorAccess-126112056177

# 確認
cat /tmp/.env.old

# 必要であれば最新版として再アップロード
aws s3 cp /tmp/.env.old \
  s3://kishax-production-env-files/i-a/mc/.env \
  --profile AdministratorAccess-126112056177
```

---

## セキュリティベストプラクティス

### 1. ローカル.envファイルの管理

```bash
# .envファイルのパーミッション設定
chmod 600 .env

# .gitignoreに.envが含まれていることを確認
grep "^\.env$" .gitignore

# 誤ってgitに追加しないよう注意
git status
```

### 2. S3バケットのアクセス制御

```bash
# バケットポリシーを確認
aws s3api get-bucket-policy \
  --bucket kishax-production-env-files \
  --profile AdministratorAccess-126112056177 \
  | jq '.Policy | fromjson'

# パブリックアクセスブロック設定を確認
aws s3api get-public-access-block \
  --bucket kishax-production-env-files \
  --profile AdministratorAccess-126112056177
```

### 3. 暗号化設定の確認

```bash
# バケット暗号化設定を確認
aws s3api get-bucket-encryption \
  --bucket kishax-production-env-files \
  --profile AdministratorAccess-126112056177

# 出力例:
# {
#     "ServerSideEncryptionConfiguration": {
#         "Rules": [
#             {
#                 "ApplyServerSideEncryptionByDefault": {
#                     "SSEAlgorithm": "AES256"
#                 }
#             }
#         ]
#     }
# }
```

### 4. 機密情報の取り扱い

**.envに含めるべき情報**:
- データベース接続情報（RDSエンドポイント、パスワード）
- SQS認証情報（Access Key ID, Secret Access Key）
- OAuth Client Secrets
- API Keys
- NEXTAUTH_SECRET

**絶対に.envに含めてはいけない情報**:
- AWS IAM Credentials（インスタンスのIAM Roleを使用）
- SSH秘密鍵

---

## トラブルシューティング

### 問題1: .envファイルがダウンロードできない

**症状**: user-dataスクリプトでS3からのダウンロードが失敗

**確認**:

```bash
# インスタンスのIAM Roleを確認
aws ec2 describe-instances \
  --instance-ids $INSTANCE_ID \
  --query 'Reservations[0].Instances[0].IamInstanceProfile.Arn' \
  --profile AdministratorAccess-126112056177

# IAM RoleのポリシーをS確認
aws iam list-attached-role-policies \
  --role-name kishax-production-mc-server-role \
  --profile AdministratorAccess-126112056177
```

**対処法**:

Terraform stateを確認し、IAM Roleに`s3:GetObject`権限があることを確認

```bash
cd /Users/tk/git/Kishax/infrastructure/terraform
terraform plan
```

### 問題2: .envファイルの内容が反映されない

**症状**: .envを更新したが、アプリケーションに反映されない

**原因**: Dockerコンテナが古い.envを使用している

**対処法**:

```bash
# Dockerコンテナを再起動
systemctl restart minecraft  # MC Server
systemctl restart api        # API Server
systemctl restart web        # Web Server

# または
docker-compose down
docker-compose up -d
```

### 問題3: バージョニングで古いバージョンが残り続ける

**症状**: S3バケットの容量が増え続ける

**対処法**: ライフサイクルポリシーで古いバージョンを削除（現在は無期限保存）

```bash
# 必要に応じてTerraformで設定
# terraform/modules/s3/main.tf に以下を追加:

# resource "aws_s3_bucket_lifecycle_configuration" "env_files" {
#   bucket = aws_s3_bucket.env_files.id
#
#   rule {
#     id     = "delete-old-versions"
#     status = "Enabled"
#
#     noncurrent_version_expiration {
#       noncurrent_days = 90
#     }
#   }
# }
```

---

## 関連ドキュメント

- [EC2デプロイメント手順書](./deployment.md)
- [自動スケジューリング設定](./auto-scheduling.md)
- [Terraform設定](../../terraform/README.md)
