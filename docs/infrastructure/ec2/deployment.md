# Kishax EC2 Infrastructure デプロイメント手順書

**作成日**: 2025-12-13  
**バージョン**: 1.0.0  
**対象環境**: Production (ap-northeast-1)

---

## 📋 目次

1. [前提条件](#前提条件)
2. [デプロイメント概要](#デプロイメント概要)
3. [準備作業](#準備作業)
4. [デプロイ手順](#デプロイ手順)
   - [Phase 1: i-b (API Server + Redis)](#phase-1-i-b-api-server--redis)
   - [Phase 2: i-c (Web Server)](#phase-2-i-c-web-server)
   - [Phase 3: i-a (MC Server)](#phase-3-i-a-mc-server)
5. [動作確認](#動作確認)
6. [運用コマンド](#運用コマンド)
7. [トラブルシューティング](#トラブルシューティング)

---

## 前提条件

### 必須要件

- ✅ AWS CLI v2以上
- ✅ AWS SSO設定完了（`AdministratorAccess-126112056177`プロファイル）
- ✅ Session Manager Plugin インストール済み
- ✅ Terraformで全リソースが作成済み
- ✅ Git submodulesが最新状態

### 確認コマンド

```bash
# AWS SSO ログイン
make login
# または
aws sso login --profile AdministratorAccess-126112056177

# 認証確認
aws sts get-caller-identity --profile AdministratorAccess-126112056177

# Terraform状態確認
cd terraform
terraform output
```

---

## デプロイメント概要

### デプロイ順序

依存関係を考慮し、以下の順序でデプロイします：

```
1. i-b (API Server + Redis) ← 他のサービスが依存
   ↓
2. i-c (Web Server) ← i-bのRedis/APIに依存
   ↓
3. i-a (MC Server) ← i-bのRedis/APIに依存
```

### 各インスタンスの役割

| インスタンス | 役割 | タイプ | 状態 |
|------------|------|--------|------|
| **i-b** | API Server + Redis + Discord Bot | t3.small Spot | 24/7稼働 |
| **i-c** | Web Server | t2.micro Spot | 24/7稼働 |
| **i-a** | MC Server | t3.large On-Demand | 22:00-27:00 |
| **i-d** | RDS Jump Server | t2.micro On-Demand | 停止中 |

---

## 準備作業

### 0. Terraform適用時の注意事項

⚠️ **Spotインスタンス再作成時のエラー対処**

`terraform apply`でSpotインスタンス（i-b, i-c）を再作成する場合、以下のエラーが発生することがあります：

```
Error: multiple EC2 Instances matched; use additional constraints to reduce matches to a single EC2 Instance
```

**原因**: 古いSpotインスタンスの削除完了前に、新しいSpotインスタンスが作成されたため。

**対処法**: 古いインスタンスを手動で強制終了してから、再度`terraform apply`を実行

```bash
# 1. エラーメッセージから古いインスタンスIDを確認
# （例: i-0c179bef38c95181c）

# 2. 古いインスタンスを強制終了
aws ec2 terminate-instances \
  --instance-ids i-0c179bef38c95181c \
  --profile AdministratorAccess-126112056177

# 3. インスタンスの状態を確認（terminated になるまで待つ）
aws ec2 describe-instances \
  --instance-ids i-0c179bef38c95181c \
  --profile AdministratorAccess-126112056177 \
  --query 'Reservations[0].Instances[0].State.Name' \
  --output text

# 4. terminated になったら terraform apply を再実行
cd /Users/tk/git/Kishax/infrastructure/terraform
terraform apply
```

---

### 1. Terraform出力情報を取得

```bash
cd /Users/tk/git/Kishax/infrastructure/terraform

# 全出力を確認
terraform output

# 必要な情報を環境変数にエクスポート
export RDS_POSTGRES_ENDPOINT=$(terraform output -raw postgres_endpoint)
export RDS_MYSQL_ENDPOINT=$(terraform output -raw mysql_endpoint)
export TO_WEB_QUEUE_URL=$(terraform output -raw to_web_queue_url)
export TO_MC_QUEUE_URL=$(terraform output -raw to_mc_queue_url)
export TO_DISCORD_QUEUE_URL=$(terraform output -raw discord_queue_url)
```

### 2. 機密情報の取得

#### SQS認証情報（Terraformで自動作成済み）

✅ **SQS用のIAMユーザーとアクセスキーはTerraformで自動作成されます**

Terraform適用時に以下が自動的に作成されます：
- IAMユーザー: `kishax-production-sqs-access`
- アクセスキーとシークレットキー
- SSM Parameter Store:
  - `/kishax/production/sqs/access-key-id`
  - `/kishax/production/sqs/secret-access-key`

**SQS認証情報の取得**（`.env`ファイル生成時に使用）：
```bash
# SQS Access Key IDを取得
export MC_WEB_SQS_ACCESS_KEY_ID=$(aws ssm get-parameter \
  --profile AdministratorAccess-126112056177 \
  --name "/kishax/production/sqs/access-key-id" \
  --query "Parameter.Value" \
  --output text)

# SQS Secret Access Keyを取得
export MC_WEB_SQS_SECRET_ACCESS_KEY=$(aws ssm get-parameter \
  --profile AdministratorAccess-126112056177 \
  --name "/kishax/production/sqs/secret-access-key" \
  --with-decryption \
  --query "Parameter.Value" \
  --output text)

# 確認
echo "Access Key ID: $MC_WEB_SQS_ACCESS_KEY_ID"
echo "Secret Access Key: ${MC_WEB_SQS_SECRET_ACCESS_KEY:0:10}..." # 最初の10文字のみ表示
```

> **Note**: 旧環境でSQS用のIAMユーザーがある場合は、事前に削除してください：
> ```bash
> # 旧IAMユーザーの確認
> aws iam list-users --profile AdministratorAccess-126112056177 | grep sqs
> 
> # 削除（例）
> aws iam delete-access-key --user-name OLD_SQS_USER --access-key-id XXXX --profile AdministratorAccess-126112056177
> aws iam delete-user-policy --user-name OLD_SQS_USER --policy-name POLICY_NAME --profile AdministratorAccess-126112056177
> aws iam delete-user --user-name OLD_SQS_USER --profile AdministratorAccess-126112056177
> ```

#### その他の機密情報（.envファイルに直接記載）

以下の機密情報は**各インスタンスの`.env`ファイルに直接記載**してください：

- **Discord Bot Token**: Discord Developer Portalから取得
- **RDSパスワード**: `terraform.tfvars`から取得
  - PostgreSQL: `postgres_password`の値
  - MySQL: `mysql_password`の値
- **OAuth Client Secrets**: 各プロバイダーのDeveloper Consoleから取得
  - Google、Discord、Twitter
- **Auth API Key**: 新規生成（例: `openssl rand -base64 32`）
- **NEXTAUTH_SECRET**: 新規生成（例: `openssl rand -base64 32`）
- **Email SMTP Password**: メールプロバイダーから取得

**セキュリティ対策**:
```bash
# .envファイルのパーミッション設定
chmod 600 /opt/*/. env
chown ec2-user:ec2-user /opt/*/.env

# .gitignoreに.envが含まれていることを確認
grep -r "^\.env$" /opt/*/.gitignore
```

### 3. EC2インスタンスIDを取得

```bash
# i-d (Jump Server)
export INSTANCE_ID_D=$(terraform output -raw jump_server_instance_id)

# i-b (API Server)
export INSTANCE_ID_B=$(terraform output -raw api_server_instance_id)

# i-c (Web Server)
export INSTANCE_ID_C=$(terraform output -raw web_server_instance_id)

# i-a (MC Server)
export INSTANCE_ID_A=$(terraform output -raw mc_server_instance_id)

# 確認
echo "i-d: $INSTANCE_ID_D"
echo "i-b: $INSTANCE_ID_B"
echo "i-c: $INSTANCE_ID_C"
echo "i-a: $INSTANCE_ID_A"
```

### 4. EC2インスタンスのPrivate IPを取得

```bash
# i-b (API Server) Private IP
export INSTANCE_ID_B_PRIVATE_IP=$(aws ec2 describe-instances \
  --instance-ids $INSTANCE_ID_B \
  --profile AdministratorAccess-126112056177 \
  --query 'Reservations[0].Instances[0].PrivateIpAddress' \
  --output text)

# i-c (Web Server) Private IP
export INSTANCE_ID_C_PRIVATE_IP=$(aws ec2 describe-instances \
  --instance-ids $INSTANCE_ID_C \
  --profile AdministratorAccess-126112056177 \
  --query 'Reservations[0].Instances[0].PrivateIpAddress' \
  --output text)

# i-a (MC Server) Private IP
export INSTANCE_ID_A_PRIVATE_IP=$(aws ec2 describe-instances \
  --instance-ids $INSTANCE_ID_A \
  --profile AdministratorAccess-126112056177 \
  --query 'Reservations[0].Instances[0].PrivateIpAddress' \
  --output text)

# 確認
echo "i-b Private IP: $INSTANCE_ID_B_PRIVATE_IP"
echo "i-c Private IP: $INSTANCE_ID_C_PRIVATE_IP"
echo "i-a Private IP: $INSTANCE_ID_A_PRIVATE_IP"
```

---

## EC2インスタンスへのアクセス方法

### 方法1: Jump Server経由のSSH Port Forwarding（推奨）

セキュリティ上、SSHキーをJump Serverに配置せず、ローカルから直接操作できます。

#### i-b (API Server)への接続

```bash
# ターミナル1: Port Forwardingセッション開始
aws ssm start-session \
  --profile AdministratorAccess-126112056177 \
  --target $INSTANCE_ID_D \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters "{\"host\":[\"${INSTANCE_ID_B_PRIVATE_IP}\"],\"portNumber\":[\"22\"],\"localPortNumber\":[\"2222\"]}"

# ターミナル2: SSHで接続（別ターミナルで実行）
ssh -i /Users/tk/git/Kishax/infrastructure/minecraft.pem -p 2222 ec2-user@localhost
```

#### i-c (Web Server)への接続

```bash
# ターミナル1: Port Forwardingセッション開始
aws ssm start-session \
  --profile AdministratorAccess-126112056177 \
  --target $INSTANCE_ID_D \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters "{\"host\":[\"${INSTANCE_ID_C_PRIVATE_IP}\"],\"portNumber\":[\"22\"],\"localPortNumber\":[\"2223\"]}"

# ターミナル2: SSHで接続
ssh -i /Users/tk/git/Kishax/infrastructure/minecraft.pem -p 2223 ec2-user@localhost
```

#### i-a (MC Server)への接続

```bash
# ターミナル1: Port Forwardingセッション開始
aws ssm start-session \
  --profile AdministratorAccess-126112056177 \
  --target $INSTANCE_ID_D \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters "{\"host\":[\"${INSTANCE_ID_A_PRIVATE_IP}\"],\"portNumber\":[\"22\"],\"localPortNumber\":[\"2224\"]}"

# ターミナル2: SSHで接続
ssh -i /Users/tk/git/Kishax/infrastructure/minecraft.pem -p 2224 ec2-user@localhost
```

### 方法2: 直接SSM Session Manager接続（非推奨）

SSM Agent設定が正しければ直接接続も可能ですが、Port Forwardingの方が安定しています。

```bash
# 直接接続（設定によっては動作しない場合あり）
aws ssm start-session \
  --profile AdministratorAccess-126112056177 \
  --target $INSTANCE_ID_B
```

> **Note**: Jump Server (i-d)は停止状態の場合があるため、使用前に起動してください：
> ```bash
> aws ec2 start-instances \
>   --instance-ids $INSTANCE_ID_D \
>   --profile AdministratorAccess-126112056177
> 
> # 起動完了を待つ（1-2分）
> sleep 120
> ```

---

## デプロイ手順

## Phase 1: i-b (API Server + Redis)

### 🎯 目標
- Redis 2つ起動（MC用、Web/Discord用）
- SQS Redis Bridge起動
- MC Auth API起動
- Discord Bot起動

### 1-1. EC2にJump Server経由でSSH接続

```bash
# Jump Server (i-d) を起動（停止している場合）
aws ec2 start-instances \
  --instance-ids $INSTANCE_ID_D \
  --profile AdministratorAccess-126112056177

# 起動完了を待つ（1-2分）
sleep 120

# ターミナル1: Port Forwardingセッション開始
aws ssm start-session \
  --profile AdministratorAccess-126112056177 \
  --target $INSTANCE_ID_D \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters "{\"host\":[\"${INSTANCE_ID_B_PRIVATE_IP}\"],\"portNumber\":[\"22\"],\"localPortNumber\":[\"2222\"]}"

# ターミナル2: SSHで接続（新しいターミナルを開いて実行）
ssh -i /Users/tk/git/Kishax/infrastructure/minecraft.pem -p 2222 ec2-user@localhost
```

> **Note**: Port Forwardingセッションは別ターミナルで起動したまま、新しいターミナルでSSH接続します。

### 1-2. 必要なソフトウェアのインストール確認

```bash
# Dockerインストール確認
docker --version

# Docker Composeインストール確認
docker compose version

# 未インストールの場合、User Dataが実行されているか確認
sudo cat /var/log/cloud-init-output.log | grep -A 10 "docker"

# 必要に応じて手動インストール
sudo yum install -y docker
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker ec2-user

# Docker Compose v2インストール
sudo mkdir -p /usr/local/lib/docker/cli-plugins
sudo curl -SL https://github.com/docker/compose/releases/download/v2.24.0/docker-compose-linux-x86_64 \
  -o /usr/local/lib/docker/cli-plugins/docker-compose
sudo chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

# セッション再接続（グループ反映のため）
exit
```

### 1-3. アプリケーションコードの配置

```bash
# 再接続
aws ssm start-session \
  --profile AdministratorAccess-126112056177 \
  --target $INSTANCE_ID_B

# ディレクトリ作成
sudo mkdir -p /opt/api
sudo chown ec2-user:ec2-user /opt/api
cd /opt/api

# Gitリポジトリクローン
git clone https://github.com/Kishax/api.git .

# または、既存の認証情報を使用
# git clone git@github.com:Kishax/api.git .
```

### 1-4. 環境変数ファイル生成

```bash
cd /opt/api

# .envファイル生成
cat > .env << EOF
# ===================================
# API Server Configuration (i-b, EC2)
# ===================================

# Database Configuration (RDS PostgreSQL)
# terraform.tfvarsのpostgres_passwordを使用
DATABASE_URL=jdbc:postgresql://${RDS_POSTGRES_ENDPOINT}:5432/kishax?user=postgres&password=YOUR_POSTGRES_PASSWORD_HERE

# AWS SQS Configuration
AWS_REGION=ap-northeast-1
MC_WEB_SQS_ACCESS_KEY_ID=${MC_WEB_SQS_ACCESS_KEY_ID}
MC_WEB_SQS_SECRET_ACCESS_KEY=${MC_WEB_SQS_SECRET_ACCESS_KEY}
TO_WEB_QUEUE_URL=${TO_WEB_QUEUE_URL}
TO_MC_QUEUE_URL=${TO_MC_QUEUE_URL}
TO_DISCORD_QUEUE_URL=${TO_DISCORD_QUEUE_URL}

# Redis Configuration (Docker network内)
REDIS_URL=redis://redis-mc:6379
REDIS_CONNECTION_TIMEOUT=5000
REDIS_COMMAND_TIMEOUT=3000

# Redis Configuration for Discord Bot (Docker network内)
REDIS_URL_DISCORD=redis://redis-web:6380

# Queue Mode
QUEUE_MODE=WEB
SQS_WORKER_ENABLED=true

# Authentication API Configuration
AUTH_API_ENABLED=true
AUTH_API_PORT=8080
AUTH_API_KEY=$(openssl rand -hex 32)

# Discord Bot Configuration
# Discord Developer Portalから取得
DISCORD_TOKEN=YOUR_DISCORD_BOT_TOKEN_HERE
DISCORD_CHANNEL_ID=YOUR_CHANNEL_ID
DISCORD_CHAT_CHANNEL_ID=YOUR_CHAT_CHANNEL_ID
DISCORD_ADMIN_CHANNEL_ID=YOUR_ADMIN_CHANNEL_ID
DISCORD_RULE_CHANNEL_ID=YOUR_RULE_CHANNEL_ID
DISCORD_RULE_MESSAGE_ID=YOUR_RULE_MESSAGE_ID
DISCORD_GUILD_ID=YOUR_GUILD_ID
DISCORD_PRESENCE_ACTIVITY=Kishaxサーバー
BE_DEFAULT_EMOJI_NAME=steve

# SQS Configuration for Discord
AWS_SQS_MAX_MESSAGES=10
AWS_SQS_WAIT_TIME_SECONDS=20
SQS_WORKER_POLLING_INTERVAL=5
SQS_WORKER_MAX_MESSAGES=10
SQS_WORKER_WAIT_TIME=20
SQS_WORKER_VISIBILITY_TIMEOUT=300

# Application Configuration
SHUTDOWN_GRACE_PERIOD=10

# Logging Configuration
LOG_LEVEL=INFO
EOF

# .envファイルを編集して実際の値に置き換え
# 1. YOUR_POSTGRES_PASSWORD_HERE を terraform.tfvars の postgres_password の値に置き換え
# 2. YOUR_DISCORD_BOT_TOKEN_HERE を Discord Developer Portal から取得した値に置き換え
# 3. YOUR_*_ID を Discord から取得した実際のIDに置き換え

# 例: viエディタで編集
vi .env

# .envファイルのパーミッション設定
chmod 600 .env
chown ec2-user:ec2-user .env

# 確認（機密情報が含まれるので注意）
cat .env
```

> **重要**: 
> - `YOUR_POSTGRES_PASSWORD_HERE`: `terraform.tfvars` の `postgres_password` の値を使用
> - `YOUR_DISCORD_BOT_TOKEN_HERE`: Discord Developer Portalから取得
> - Discord各種ID: Discordサーバーから取得
> - `AUTH_API_KEY`: 自動生成される（`openssl rand -hex 32`）

### 1-5. アプリケーションビルドとデプロイ

```bash
cd /opt/api

# Docker Composeでビルド
docker compose -f compose.yaml build

# サービス起動
docker compose -f compose.yaml up -d

# 起動確認
docker compose -f compose.yaml ps

# ログ確認
docker compose -f compose.yaml logs -f
```

### 1-6. 動作確認

```bash
# Redis接続確認
docker exec -it kishax-redis-mc redis-cli ping
docker exec -it kishax-redis-web redis-cli -p 6380 ping

# MC Auth API確認
curl http://localhost:8080/health

# コンテナログ確認
docker logs kishax-sqs-redis-bridge
docker logs kishax-mc-auth
docker logs kishax-discord-bot

# 全サービスのステータス確認
docker compose -f compose.yaml ps
```

---

## Phase 2: i-c (Web Server)

### 🎯 目標
- Web Serverの起動
- CloudFront経由でアクセス可能にする

### 2-1. EC2にJump Server経由でSSH接続

```bash
# ターミナル1: Port Forwardingセッション開始
aws ssm start-session \
  --profile AdministratorAccess-126112056177 \
  --target $INSTANCE_ID_D \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters "{\"host\":[\"${INSTANCE_ID_C_PRIVATE_IP}\"],\"portNumber\":[\"22\"],\"localPortNumber\":[\"2223\"]}"

# ターミナル2: SSHで接続（新しいターミナルを開いて実行）
ssh -i /Users/tk/git/Kishax/infrastructure/minecraft.pem -p 2223 ec2-user@localhost
```

### 2-2. 必要なソフトウェアのインストール確認

```bash
# Dockerインストール確認
docker --version
docker compose version

# 未インストールの場合はi-bと同様にインストール
```

### 2-3. アプリケーションコードの配置

```bash
# ディレクトリ作成
sudo mkdir -p /opt/web
sudo chown ec2-user:ec2-user /opt/web
cd /opt/web

# Gitリポジトリクローン
git clone https://github.com/Kishax/web.git .
```

### 2-4. 環境変数ファイル生成

```bash
cd /opt/web

# .envファイル生成
cat > .env << EOF
# ===================================
# Web Server Configuration (i-c, EC2)
# ===================================

# Database Configuration (RDS PostgreSQL)
# terraform.tfvarsのpostgres_passwordを使用
DATABASE_URL=postgresql://postgres:YOUR_POSTGRES_PASSWORD_HERE@${RDS_POSTGRES_ENDPOINT}:5432/kishax

# AWS SQS Configuration
AWS_REGION=ap-northeast-1
MC_WEB_SQS_ACCESS_KEY_ID=${MC_WEB_SQS_ACCESS_KEY_ID}
MC_WEB_SQS_SECRET_ACCESS_KEY=${MC_WEB_SQS_SECRET_ACCESS_KEY}
TO_WEB_QUEUE_URL=${TO_WEB_QUEUE_URL}
TO_MC_QUEUE_URL=${TO_MC_QUEUE_URL}
TO_DISCORD_QUEUE_URL=${TO_DISCORD_QUEUE_URL}

# Redis Configuration (i-b上のRedis #2)
REDIS_URL=redis://${INSTANCE_ID_B_PRIVATE_IP}:6380
REDIS_CONNECTION_TIMEOUT=5000
REDIS_COMMAND_TIMEOUT=3000

# Queue Mode
QUEUE_MODE=WEB
SQS_WORKER_ENABLED=false

# NextAuth Configuration
NEXTAUTH_URL=https://kishax.net
NEXTAUTH_SECRET=$(openssl rand -base64 32)

# OAuth Providers (各プロバイダーのDeveloper Consoleから取得)
GOOGLE_CLIENT_ID=YOUR_GOOGLE_CLIENT_ID
GOOGLE_CLIENT_SECRET=YOUR_GOOGLE_CLIENT_SECRET
DISCORD_CLIENT_ID=YOUR_DISCORD_CLIENT_ID
DISCORD_CLIENT_SECRET=YOUR_DISCORD_CLIENT_SECRET
TWITTER_CLIENT_ID=YOUR_TWITTER_CLIENT_ID
TWITTER_CLIENT_SECRET=YOUR_TWITTER_CLIENT_SECRET

# Email Configuration (SMTP)
EMAIL_HOST=YOUR_SMTP_HOST
EMAIL_PORT=587
EMAIL_USER=YOUR_SMTP_USER
EMAIL_PASS=YOUR_SMTP_PASSWORD
EMAIL_FROM=noreply@kishax.net

# Application Configuration
NODE_ENV=production
PORT=80

# Logging Configuration
LOG_LEVEL=info
EOF

# .envファイルを編集して実際の値に置き換え
# 1. YOUR_POSTGRES_PASSWORD_HERE を terraform.tfvars の postgres_password の値に置き換え
# 2. YOUR_GOOGLE_* を Google Cloud Console から取得した値に置き換え
# 3. YOUR_DISCORD_* を Discord Developer Portal から取得した値に置き換え
# 4. YOUR_TWITTER_* を Twitter Developer Portal から取得した値に置き換え
# 5. YOUR_SMTP_* をメールプロバイダーから取得した値に置き換え

# 例: viエディタで編集
vi .env

# .envファイルのパーミッション設定
chmod 600 .env
chown ec2-user:ec2-user .env

# 確認（機密情報が含まれるので注意）
cat .env
```

> **重要**: 
> - `YOUR_POSTGRES_PASSWORD_HERE`: `terraform.tfvars` の `postgres_password` の値を使用
> - `NEXTAUTH_SECRET`: 自動生成される（`openssl rand -base64 32`）
> - OAuth Client ID/Secret: 各プロバイダーのDeveloper Consoleから取得
> - SMTP設定: 使用するメールプロバイダーの設定を使用

### 2-5. アプリケーションビルドとデプロイ

```bash
cd /opt/web

# Docker Composeでビルド
docker compose -f compose.yaml build

# サービス起動
docker compose -f compose.yaml up -d

# 起動確認
docker compose -f compose.yaml ps
docker compose -f compose.yaml logs -f
```

### 2-6. 動作確認

```bash
# ローカルからの接続確認
curl http://localhost:80

# i-b上のRedisへの接続確認
redis-cli -h $INSTANCE_ID_B_PRIVATE_IP -p 6380 ping

# コンテナログ確認
docker logs kishax-web

# CloudFront経由での確認（別ターミナルから）
# curl https://kishax.net
```

---

## Phase 3: i-a (MC Server)

### 🎯 目標
- Minecraft Server起動
- Route53 DNSの動的更新
- ポート25565でのアクセス確認

### 3-1. EC2にJump Server経由でSSH接続

```bash
# ターミナル1: Port Forwardingセッション開始
aws ssm start-session \
  --profile AdministratorAccess-126112056177 \
  --target $INSTANCE_ID_D \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters "{\"host\":[\"${INSTANCE_ID_A_PRIVATE_IP}\"],\"portNumber\":[\"22\"],\"localPortNumber\":[\"2224\"]}"

# ターミナル2: SSHで接続（新しいターミナルを開いて実行）
ssh -i /Users/tk/git/Kishax/infrastructure/minecraft.pem -p 2224 ec2-user@localhost
```

### 3-2. 必要なソフトウェアのインストール確認

```bash
# Dockerインストール確認
docker --version
docker compose version

# Java（Paper Server用）
java -version
```

### 3-3. アプリケーションコードの配置

```bash
# ディレクトリ作成
sudo mkdir -p /opt/minecraft
sudo chown ec2-user:ec2-user /opt/minecraft
cd /opt/minecraft

# Gitリポジトリクローン
git clone https://github.com/Kishax/minecraft-server.git .
```

### 3-4. 環境変数ファイル生成

```bash
cd /opt/minecraft

# .envファイル生成
cat > .env << EOF
# ===================================
# Minecraft Server Configuration (i-a, EC2)
# ===================================

# Database Configuration (RDS MySQL)
# terraform.tfvarsのmysql_passwordを使用
DB_HOST=${RDS_MYSQL_ENDPOINT}
DB_PORT=3306
DB_NAME=minecraft
DB_USER=admin
DB_PASSWORD=YOUR_MYSQL_PASSWORD_HERE

# AWS SQS Configuration
AWS_REGION=ap-northeast-1
MC_WEB_SQS_ACCESS_KEY_ID=${MC_WEB_SQS_ACCESS_KEY_ID}
MC_WEB_SQS_SECRET_ACCESS_KEY=${MC_WEB_SQS_SECRET_ACCESS_KEY}
TO_WEB_QUEUE_URL=${TO_WEB_QUEUE_URL}
TO_MC_QUEUE_URL=${TO_MC_QUEUE_URL}
TO_DISCORD_QUEUE_URL=${TO_DISCORD_QUEUE_URL}

# Redis Configuration (i-b上のRedis #1)
REDIS_HOST=${INSTANCE_ID_B_PRIVATE_IP}
REDIS_PORT=6379
REDIS_CONNECTION_TIMEOUT=5000

# Queue Mode
QUEUE_MODE=MC

# Minecraft Server Configuration
MC_SERVER_PORT=25565
MC_MAX_PLAYERS=20
MC_VIEW_DISTANCE=10
MC_SIMULATION_DISTANCE=10

# Authentication API Configuration
# AUTH_API_KEYはi-bで生成した値と同じものを使用
AUTH_API_URL=http://${INSTANCE_ID_B_PRIVATE_IP}:8080
AUTH_API_KEY=COPY_FROM_I_B_AUTH_API_KEY

# Logging Configuration
LOG_LEVEL=INFO
EOF

# .envファイルを編集して実際の値に置き換え
# 1. YOUR_MYSQL_PASSWORD_HERE を terraform.tfvars の mysql_password の値に置き換え
# 2. COPY_FROM_I_B_AUTH_API_KEY を i-b の .env の AUTH_API_KEY の値に置き換え

# 例: viエディタで編集
vi .env

# .envファイルのパーミッション設定
chmod 600 .env
chown ec2-user:ec2-user .env

# 確認（機密情報が含まれるので注意）
cat .env
```

> **重要**: 
> - `YOUR_MYSQL_PASSWORD_HERE`: `terraform.tfvars` の `mysql_password` の値を使用
> - `COPY_FROM_I_B_AUTH_API_KEY`: i-b の `/opt/api/.env` の `AUTH_API_KEY` の値をコピー

### 3-5. Route53 DNS更新スクリプト確認

```bash
# User Dataで自動実行されるはずだが、確認
sudo cat /var/log/cloud-init-output.log | grep -A 20 "Route53"

# 手動実行する場合（必要に応じて）
# スクリプトはUser Dataで配置済み
sudo /usr/local/bin/update-route53.sh
```

### 3-6. アプリケーションビルドとデプロイ

```bash
cd /opt/minecraft

# Docker Composeでビルド
docker compose -f compose.yml build

# サービス起動
docker compose -f compose.yml up -d

# 起動確認
docker compose -f compose.yml ps
docker compose -f compose.yml logs -f
```

### 3-7. 動作確認

```bash
# Minecraftサーバーログ確認
docker logs kishax-minecraft-server

# ポート確認
sudo netstat -tlnp | grep 25565

# i-b上のRedisへの接続確認
redis-cli -h $INSTANCE_ID_B_PRIVATE_IP -p 6379 ping

# DNS確認（別ターミナルから）
# dig mc.kishax.net
# nslookup mc.kishax.net
```

---

## 動作確認

### 全体的なヘルスチェック

```bash
# 各EC2インスタンスのステータス
aws ec2 describe-instance-status \
  --profile AdministratorAccess-126112056177 \
  --instance-ids $INSTANCE_ID_A $INSTANCE_ID_B $INSTANCE_ID_C

# RDSのステータス
aws rds describe-db-instances \
  --profile AdministratorAccess-126112056177 \
  --query "DBInstances[*].[DBInstanceIdentifier,DBInstanceStatus]" \
  --output table

# SQSキューのメッセージ数
aws sqs get-queue-attributes \
  --profile AdministratorAccess-126112056177 \
  --queue-url $TO_WEB_QUEUE_URL \
  --attribute-names ApproximateNumberOfMessages

# CloudFrontディストリビューションの状態
aws cloudfront list-distributions \
  --profile AdministratorAccess-126112056177 \
  --query "DistributionList.Items[?Comment=='Kishax Web Distribution'].{Id:Id,Status:Status,DomainName:DomainName}"
```

### エンドツーエンドテスト

```bash
# 1. Web経由でのアクセス
curl https://kishax.net

# 2. MC Server接続テスト（Minecraftクライアントから）
# mc.kishax.net:25565 に接続

# 3. Discord Bot確認
# Discordチャンネルでコマンドテスト
```

---

## 運用コマンド

### サービス再起動

#### i-b (API Server)

```bash
# SSM接続
aws ssm start-session --profile AdministratorAccess-126112056177 --target $INSTANCE_ID_B

# 全サービス再起動
cd /opt/api
docker compose -f compose.yaml restart

# 個別サービス再起動
docker compose -f compose.yaml restart sqs-redis-bridge
docker compose -f compose.yaml restart mc-auth
docker compose -f compose.yaml restart discord-bot
docker compose -f compose.yaml restart redis-mc
docker compose -f compose.yaml restart redis-web
```

#### i-c (Web Server)

```bash
# SSM接続
aws ssm start-session --profile AdministratorAccess-126112056177 --target $INSTANCE_ID_C

# サービス再起動
cd /opt/web
docker compose -f compose.yaml restart
```

#### i-a (MC Server)

```bash
# SSM接続
aws ssm start-session --profile AdministratorAccess-126112056177 --target $INSTANCE_ID_A

# サービス再起動
cd /opt/minecraft
docker compose -f compose.yml restart
```

### ログ確認

```bash
# リアルタイムログ（i-b）
docker compose -f compose.yaml logs -f

# 特定サービスのログ
docker logs kishax-redis-mc --tail 100 -f
docker logs kishax-sqs-redis-bridge --tail 100 -f
docker logs kishax-mc-auth --tail 100 -f
docker logs kishax-discord-bot --tail 100 -f

# ログ保存
docker compose -f compose.yaml logs > /tmp/api-server-logs.txt
```

### サービス停止・起動

```bash
# 停止
docker compose -f compose.yaml down

# 起動（既存イメージ使用）
docker compose -f compose.yaml up -d

# 再ビルドして起動
docker compose -f compose.yaml up -d --build
```

### EC2インスタンスの起動・停止

```bash
# i-a（MC Server）の停止（27:00以降）
aws ec2 stop-instances \
  --profile AdministratorAccess-126112056177 \
  --instance-ids $INSTANCE_ID_A

# i-a（MC Server）の起動（22:00前）
aws ec2 start-instances \
  --profile AdministratorAccess-126112056177 \
  --instance-ids $INSTANCE_ID_A

# i-d（Jump Server）の起動（DB管理時）
aws ec2 start-instances \
  --profile AdministratorAccess-126112056177 \
  --instance-ids $(terraform output -raw jump_server_instance_id)
```

---

## トラブルシューティング

### 問題1: Dockerコンテナが起動しない

**症状**: `docker compose up -d`が失敗する

**確認手順**:
```bash
# Dockerデーモンの状態確認
sudo systemctl status docker

# ディスク容量確認
df -h

# Dockerログ確認
sudo journalctl -u docker -n 50

# コンテナログ確認
docker compose -f compose.yaml logs
```

**解決策**:
```bash
# Dockerデーモン再起動
sudo systemctl restart docker

# 未使用イメージ・コンテナの削除
docker system prune -a -f
```

### 問題2: Redisに接続できない

**症状**: アプリケーションログに`Connection refused`エラー

**確認手順**:
```bash
# Redisコンテナの状態確認
docker ps | grep redis

# Redisポート確認
sudo netstat -tlnp | grep "6379\|6380"

# Redis接続テスト
docker exec -it kishax-redis-mc redis-cli ping
docker exec -it kishax-redis-web redis-cli -p 6380 ping

# セキュリティグループ確認（i-b）
aws ec2 describe-security-groups \
  --profile AdministratorAccess-126112056177 \
  --group-ids $(terraform output -raw api_server_security_group_id)
```

**解決策**:
```bash
# Redisコンテナ再起動
docker compose -f compose.yaml restart redis-mc redis-web

# セキュリティグループのインバウンドルール確認
# Terraform設定を見直し、必要に応じて修正
```

### 問題3: RDSに接続できない

**症状**: Database connection timeout

**確認手順**:
```bash
# RDSエンドポイント確認
echo $RDS_POSTGRES_ENDPOINT
echo $RDS_MYSQL_ENDPOINT

# RDSステータス確認
aws rds describe-db-instances \
  --profile AdministratorAccess-126112056177 \
  --query "DBInstances[*].[DBInstanceIdentifier,DBInstanceStatus,Endpoint.Address]"

# セキュリティグループ確認
terraform output rds_security_group_id

# 接続テスト（Jump Serverから）
# psql -h $RDS_POSTGRES_ENDPOINT -U postgres -d kishax
# mysql -h $RDS_MYSQL_ENDPOINT -u admin -p minecraft
```

**解決策**:
```bash
# RDSセキュリティグループのインバウンドルール確認
# EC2のプライベートIPからの接続を許可しているか確認
# Terraform設定を修正して再apply
```

### 問題4: SQSメッセージが処理されない

**症状**: キューにメッセージが溜まる

**確認手順**:
```bash
# SQSキューの状態確認
aws sqs get-queue-attributes \
  --profile AdministratorAccess-126112056177 \
  --queue-url $TO_WEB_QUEUE_URL \
  --attribute-names All \
  --output json

# SQS Worker（sqs-redis-bridge）のログ確認
docker logs kishax-sqs-redis-bridge --tail 100

# 環境変数確認
docker exec kishax-sqs-redis-bridge env | grep SQS
```

**解決策**:
```bash
# SQS認証情報が正しいか確認
aws ssm get-parameter \
  --profile AdministratorAccess-126112056177 \
  --name "/kishax/production/sqs/access-key-id" \
  --with-decryption

# .envファイルを修正して再起動
docker compose -f compose.yaml restart sqs-redis-bridge
```

### 問題5: Route53のDNS更新が失敗

**症状**: `mc.kishax.net`が古いIPを指している

**確認手順**:
```bash
# 現在のRoute53レコード確認
aws route53 list-resource-record-sets \
  --profile AdministratorAccess-126112056177 \
  --hosted-zone-id $(terraform output -raw route53_zone_id) \
  --query "ResourceRecordSets[?Name=='mc.kishax.net.']"

# EC2のPublic IP確認
curl -s http://169.254.169.254/latest/meta-data/public-ipv4

# IAMロールの権限確認
aws iam get-role-policy \
  --profile AdministratorAccess-126112056177 \
  --role-name $(terraform output -raw mc_server_iam_role_name) \
  --policy-name route53-update-policy
```

**解決策**:
```bash
# User Dataログ確認
sudo cat /var/log/cloud-init-output.log | grep -A 20 "Route53"

# 手動でDNS更新スクリプト実行
sudo /usr/local/bin/update-route53.sh

# IAMロールにRoute53更新権限を追加（Terraform）
# terraform apply
```

### 問題6: CloudFront経由でアクセスできない

**症状**: `https://kishax.net`が502エラー

**確認手順**:
```bash
# CloudFrontディストリビューションの状態確認
aws cloudfront get-distribution \
  --profile AdministratorAccess-126112056177 \
  --id $(terraform output -raw cloudfront_distribution_id)

# オリジン（i-c）の状態確認
curl http://$INSTANCE_ID_C_PUBLIC_IP

# i-cのセキュリティグループ確認
aws ec2 describe-security-groups \
  --profile AdministratorAccess-126112056177 \
  --group-ids $(terraform output -raw web_server_security_group_id)
```

**解決策**:
```bash
# i-cのWebサーバーが起動しているか確認
docker compose -f compose.yaml ps

# セキュリティグループでHTTP (80)を許可
# Terraform設定を修正して再apply

# CloudFrontキャッシュ削除
aws cloudfront create-invalidation \
  --profile AdministratorAccess-126112056177 \
  --distribution-id $(terraform output -raw cloudfront_distribution_id) \
  --paths "/*"
```

### 問題7: Discord Botが応答しない

**症状**: Discordコマンドが動作しない

**確認手順**:
```bash
# Discord Botコンテナの状態確認
docker ps | grep discord

# Discord Botログ確認
docker logs kishax-discord-bot --tail 100

# Discord Bot Token確認
aws ssm get-parameter \
  --profile AdministratorAccess-126112056177 \
  --name "/kishax/production/discord/bot-token" \
  --with-decryption \
  --query "Parameter.Value" \
  --output text

# Redis接続確認
docker exec kishax-discord-bot redis-cli -h redis-web -p 6380 ping
```

**解決策**:
```bash
# .envファイルのDISCORD_TOKENを確認
cat /opt/api/.env | grep DISCORD_TOKEN

# Discord Botコンテナ再起動
docker compose -f compose.yaml restart discord-bot

# ログを見ながら起動
docker compose -f compose.yaml up discord-bot
```

---

## 次のステップ

### 1. モニタリング設定

- CloudWatch Logs設定
- CloudWatch Alarms設定
- コスト監視ダッシュボード

### 2. バックアップ設定

- RDSスナップショット自動化
- S3バックアップ設定（画像ファイル等）

### 3. CI/CDパイプライン構築

- GitHub Actionsでのビルド自動化
- デプロイ自動化

### 4. パフォーマンス最適化

- Redis永続化設定最適化
- Docker image最適化
- アプリケーションチューニング

---

## 参考ドキュメント

- [application-in-ec2.md](./application-in-ec2.md) - アプリケーション層の詳細設定
- [deployment-report.md](./deployment-report.md) - インフラ実装レポート
- [AWS SSM Session Manager](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager.html)
- [Docker Compose Documentation](https://docs.docker.com/compose/)

---

**デプロイ成功をお祈りしています！🚀**
