# アプリケーション層のEC2デプロイ計画書

**作成日**: 2025-12-13  
**対象環境**: Production (EC2-based)  
**前提**: Terraformインフラ構築完了済み

---

## 📋 概要

本ドキュメントは、Terraformで構築したEC2インフラ上に、各アプリケーション（MC Server, API, Web, Discord Bot）をDocker Composeでデプロイする手順と設定をまとめたものです。

---

## 🏗️ アプリケーション配置構成

### インスタンス別の役割

| インスタンス | アプリケーション | Docker Compose | ポート | データベース | Redis |
|------------|----------------|---------------|--------|------------|-------|
| **i-a (MC Server)** | Minecraft Server (Java) | `apps/mc/compose.yml` | 25565, 25577 | RDS MySQL | ローカル（コンテナ内） |
| **i-b (API Server)** | Backend API + SQS Bridge + Discord Bot | `apps/api/compose.yaml`<br/>`apps/discord/compose.yaml` | 8080 | RDS PostgreSQL | **ホスト側（2つ）** |
| **i-c (Web Server)** | Next.js Web | `apps/web/compose.yaml` | 3000 | RDS PostgreSQL | i-b のホストRedis |
| **i-d (Jump Server)** | なし（踏み台のみ） | - | - | - | - |

---

## 🔑 重要なアーキテクチャ変更点

### 1. Redis構成の変更（i-b）

**旧環境（開発/compose.yaml内）**:
- 各アプリケーションのcompose.yaml内でRedisコンテナを起動
- アプリケーション間で独立したRedisインスタンス

**新環境（本番/EC2）**:
- **i-b（API Server EC2）のホスト側に2つのRedisインスタンスを配置**
  - **Redis #1**: MC Server（i-a）用
  - **Redis #2**: Web + Discord Bot（i-c）用
- 各Redisは異なるポートで稼働（例: 6379, 6380）
- 理由: コスト最適化（ElastiCache不使用）、ネットワーク遅延削減

### 2. データベース接続

**変更内容**:
- 開発環境のローカルPostgreSQL/MySQL → RDS PostgreSQL/MySQL
- 接続先をRDSエンドポイントに変更
- 各アプリケーションの`.env`で`DATABASE_URL`を設定

### 3. compose.yaml の修正が必要な箇所

各compose.yamlから以下を削除/コメントアウト:
1. **PostgreSQL/MySQLコンテナ定義**（RDS使用のため）
2. **Redisコンテナ定義**（i-bのホストRedis使用のため）
3. **depends_on**の該当サービス
4. **volumes**の該当ボリューム

---

## 📦 i-b (API Server) のRedis構成

### Redis #1: MC Server用（ポート 6379）

**用途**: MC Serverからのリアルタイム通信  
**接続元**: i-a (MC Server)  
**設定ファイル**: `/etc/redis/redis-mc.conf`

```conf
# /etc/redis/redis-mc.conf
port 6379
bind 0.0.0.0
protected-mode no
daemonize yes
pidfile /var/run/redis/redis-mc.pid
logfile /var/log/redis/redis-mc.log
dir /var/lib/redis/mc
dbfilename dump-mc.rdb
appendonly yes
appendfilename "appendonly-mc.aof"
maxmemory 512mb
maxmemory-policy allkeys-lru
```

**systemdサービス**: `/etc/systemd/system/redis-mc.service`

```ini
[Unit]
Description=Redis Server for MC (Port 6379)
After=network.target

[Service]
Type=forking
User=redis
Group=redis
ExecStart=/usr/bin/redis-server /etc/redis/redis-mc.conf
ExecStop=/usr/bin/redis-cli -p 6379 shutdown
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

### Redis #2: Web + Discord用（ポート 6380）

**用途**: Web/Discord BotからのRedis Pub/Sub、セッション管理  
**接続元**: i-b (Discord Bot - localhost), i-c (Web Server - remote)  
**設定ファイル**: `/etc/redis/redis-web.conf`

```conf
# /etc/redis/redis-web.conf
port 6380
bind 0.0.0.0
protected-mode no
daemonize yes
pidfile /var/run/redis/redis-web.pid
logfile /var/log/redis/redis-web.log
dir /var/lib/redis/web
dbfilename dump-web.rdb
appendonly yes
appendfilename "appendonly-web.aof"
maxmemory 256mb
maxmemory-policy allkeys-lru
```

**systemdサービス**: `/etc/systemd/system/redis-web.service`

```ini
[Unit]
Description=Redis Server for Web (Port 6380)
After=network.target

[Service]
Type=forking
User=redis
Group=redis
ExecStart=/usr/bin/redis-server /etc/redis/redis-web.conf
ExecStop=/usr/bin/redis-cli -p 6380 shutdown
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

### Redis起動手順（i-b）

```bash
# Redisユーザー作成
sudo useradd -r -s /bin/false redis

# ディレクトリ作成
sudo mkdir -p /etc/redis /var/lib/redis/{mc,web} /var/run/redis /var/log/redis
sudo chown -R redis:redis /var/lib/redis /var/run/redis /var/log/redis

# 設定ファイル配置（上記内容を記述）
sudo vi /etc/redis/redis-mc.conf
sudo vi /etc/redis/redis-web.conf

# systemdサービス配置
sudo vi /etc/systemd/system/redis-mc.service
sudo vi /etc/systemd/system/redis-web.service

# サービス有効化と起動
sudo systemctl daemon-reload
sudo systemctl enable redis-mc redis-web
sudo systemctl start redis-mc redis-web

# 状態確認
sudo systemctl status redis-mc redis-web
redis-cli -p 6379 ping  # PONG
redis-cli -p 6380 ping  # PONG
```

---

## 🔧 各インスタンスのデプロイ手順

### i-a: MC Server

#### 1. 前提条件
- Docker, Docker Compose インストール済み（User Dataで完了）
- RDS MySQL作成済み

#### 2. compose.ymlの修正

**元のcompose.yml**から以下を削除:
- `mysql`サービス定義
- `redis`サービス定義（MC Serverは自前のRedisコンテナを使用→ **要検討**: i-bのRedis使用に変更するか）
- `volumes`の`mysql_data`, `redis_data`
- `depends_on`の`mysql`, `redis`

**修正後のcompose.yml** (`apps/mc/compose-ec2.yml`):

```yaml
services:
  kishax-server:
    build: .
    container_name: kishax-minecraft
    restart: unless-stopped
    environment:
      # MySQL Configuration (RDS)
      MYSQL_HOST: ${MYSQL_HOST}  # RDS MySQL Endpoint
      MYSQL_DATABASE: ${MYSQL_DATABASE:-mc}
      MYSQL_PORT: 3306
      MYSQL_USER: ${MYSQL_USER}
      MYSQL_PASSWORD: ${MYSQL_PASSWORD}
      
      # Spigot/Velocity Configuration
      SPIGOT_MEMORY: ${SPIGOT_MEMORY:-6G}  # t3.largeで余裕あり
      VELOCITY_MEMORY: ${VELOCITY_MEMORY:-1G}
      CONFIRM_URL: ${CONFIRM_URL:-http://10.0.36.61:8080/mc/auth}  # i-b API
      HOME_SERVER_NAME: ${HOME_SERVER_NAME:-spigot}
      HOME_SERVER_IP: ${HOME_SERVER_IP:-127.0.0.1}
      
      # AWS Configuration
      AWS_REGION: ${AWS_REGION:-ap-northeast-1}
      MC_WEB_SQS_ACCESS_KEY_ID: ${MC_WEB_SQS_ACCESS_KEY_ID}
      MC_WEB_SQS_SECRET_ACCESS_KEY: ${MC_WEB_SQS_SECRET_ACCESS_KEY}
      TO_WEB_QUEUE_URL: ${TO_WEB_QUEUE_URL}
      TO_MC_QUEUE_URL: ${TO_MC_QUEUE_URL}
      TO_DISCORD_QUEUE_URL: ${TO_DISCORD_QUEUE_URL}
      
      # Redis Configuration (i-b host Redis)
      REDIS_URL: ${REDIS_URL:-redis://10.0.36.61:6379}
      REDIS_CONNECTION_TIMEOUT: ${REDIS_CONNECTION_TIMEOUT:-5000}
      REDIS_COMMAND_TIMEOUT: ${REDIS_COMMAND_TIMEOUT:-3000}
      
      # Queue Configuration
      QUEUE_MODE: ${QUEUE_MODE:-MC}
      SQS_WORKER_ENABLED: ${SQS_WORKER_ENABLED:-true}
      SQS_WORKER_POLLING_INTERVAL_SECONDS: ${SQS_WORKER_POLLING_INTERVAL_SECONDS:-5}
      SQS_WORKER_MAX_MESSAGES: ${SQS_WORKER_MAX_MESSAGES:-10}
      SQS_WORKER_WAIT_TIME_SECONDS: ${SQS_WORKER_WAIT_TIME_SECONDS:-20}
      SQS_WORKER_VISIBILITY_TIMEOUT_SECONDS: ${SQS_WORKER_VISIBILITY_TIMEOUT_SECONDS:-30}
      
      # Auth API Configuration
      AUTH_API_URL: ${AUTH_API_URL:-http://10.0.36.61:8080}
      AUTH_API_KEY: ${AUTH_API_KEY}
      
      # Logging Configuration
      LOG_LEVEL: ${LOG_LEVEL:-INFO}
    
    volumes:
      - minecraft_data:/mc/spigot/world
      - minecraft_data_nether:/mc/spigot/world_nether
      - minecraft_data_the_end:/mc/spigot/world_the_end
      - velocity_data:/mc/velocity
      - server_images:/mc/server/images
    ports:
      - "25565:25565"  # Spigot server port
      - "25577:25577"  # Velocity proxy port
    stdin_open: true
    tty: true

volumes:
  minecraft_data:
  minecraft_data_nether:
  minecraft_data_the_end:
  velocity_data:
  server_images:
```

#### 3. .envファイル作成

```bash
# SSM Session Manager経由でi-aに接続
aws ssm start-session --target i-05d3718a77cb2f3da --profile AdministratorAccess-126112056177

# minecraftユーザーに切り替え
sudo su - minecraft
cd /opt/minecraft

# .envファイル作成
cat > .env << 'EOF'
# MySQL Configuration (RDS)
MYSQL_HOST=<RDS MySQL Endpoint from terraform output>
MYSQL_DATABASE=mc
MYSQL_USER=admin
MYSQL_PASSWORD=<terraform.tfvarsから取得>

# Spigot/Velocity Memory
SPIGOT_MEMORY=6G
VELOCITY_MEMORY=1G

# API Configuration
CONFIRM_URL=http://10.0.36.61:8080/mc/auth
AUTH_API_URL=http://10.0.36.61:8080
AUTH_API_KEY=<SSM Parameter Storeから取得または新規生成>

# AWS SQS Configuration
AWS_REGION=ap-northeast-1
MC_WEB_SQS_ACCESS_KEY_ID=<SSM: /kishax/production/sqs/access-key-id>
MC_WEB_SQS_SECRET_ACCESS_KEY=<SSM: /kishax/production/sqs/secret-access-key>
TO_WEB_QUEUE_URL=<terraform output: to_web_queue_url>
TO_MC_QUEUE_URL=<terraform output: to_mc_queue_url>
TO_DISCORD_QUEUE_URL=<terraform output: discord_queue_url>

# Redis Configuration (i-b)
REDIS_URL=redis://10.0.36.61:6379

# Queue Configuration
QUEUE_MODE=MC
SQS_WORKER_ENABLED=true

# Logging
LOG_LEVEL=INFO
EOF

chmod 600 .env
```

#### 4. デプロイ

```bash
# compose.ymlをコピー
cp /path/to/apps/mc/compose-ec2.yml docker-compose.yml

# 起動
docker-compose up -d

# ログ確認
docker-compose logs -f
```

---

### i-b: API Server

#### 0. 事前準備：アプリケーションのビルド

i-bでは **Javaアプリケーション（Maven）** を動かすため、事前にJARファイルをビルドする必要があります。

**ビルド方法**:

```bash
# ローカル環境でビルド（開発マシン）
cd /path/to/apps/api

# Mavenでビルド（JARファイル生成）
mvn clean package -DskipTests

# 生成されるJARファイル
# - sqs-redis-bridge/target/sqs-redis-bridge-*-with-dependencies.jar
# - mc-auth/target/mc-auth-*-with-dependencies.jar

# JARファイルの確認
ls -lh sqs-redis-bridge/target/*.jar
ls -lh mc-auth/target/*.jar
```

**EC2へのデプロイ方法**:

方法1: **Dockerビルド時に自動ビルド**（推奨）
- Dockerfileが自動的にMavenビルドを実行
- ソースコードをEC2にコピーして`docker-compose build`

方法2: **事前ビルド済みJARをコピー**
- ローカルでビルドしたJARをEC2にSCP/rsync
- Dockerfileのビルドステップをスキップ

**注意**: Dockerfileは元々`supervisord`で2サービスを1コンテナで起動する設計ですが、compose.yamlでは分離しています。
そのため、**Dockerfileの修正が必要**です。

#### 1. compose.yamlの修正

**修正後のcompose.yaml** (`apps/api/compose-ec2.yaml`):

> **重要**: 元のDockerfileは`supervisord`で2サービスを1コンテナで起動する設計です。  
> compose.yamlで分離する場合、以下2つの対応が必要です：
> 
> **対応A**: Dockerfileを各サービス専用に分割（`Dockerfile.mc-auth`, `Dockerfile.sqs-redis-bridge`）  
> **対応B**: compose.yamlで`command`を上書きして個別起動（簡易的）
> 
> ここでは**対応B**を採用します。

```yaml
services:
  # SQS Redis Bridge Service
  sqs-redis-bridge:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: kishax-sqs-redis-bridge
    environment:
      - ENVIRONMENT=production
      # AWS Configuration
      - AWS_REGION=${AWS_REGION:-ap-northeast-1}
      - MC_WEB_SQS_ACCESS_KEY_ID=${MC_WEB_SQS_ACCESS_KEY_ID}
      - MC_WEB_SQS_SECRET_ACCESS_KEY=${MC_WEB_SQS_SECRET_ACCESS_KEY}
      - TO_WEB_QUEUE_URL=${TO_WEB_QUEUE_URL}
      - TO_MC_QUEUE_URL=${TO_MC_QUEUE_URL}
      - TO_DISCORD_QUEUE_URL=${TO_DISCORD_QUEUE_URL}
      # Redis Configuration (ホスト側Redis #1)
      - REDIS_URL=${REDIS_URL:-redis://host.docker.internal:6379}
      - REDIS_CONNECTION_TIMEOUT=${REDIS_CONNECTION_TIMEOUT:-5000}
      - REDIS_COMMAND_TIMEOUT=${REDIS_COMMAND_TIMEOUT:-3000}
      # Queue Configuration
      - QUEUE_MODE=${QUEUE_MODE:-WEB}
      - SQS_WORKER_ENABLED=true
      - SQS_WORKER_POLLING_INTERVAL_SECONDS=${SQS_WORKER_POLLING_INTERVAL_SECONDS:-5}
      - SQS_WORKER_MAX_MESSAGES=${SQS_WORKER_MAX_MESSAGES:-10}
      - SQS_WORKER_WAIT_TIME_SECONDS=${SQS_WORKER_WAIT_TIME_SECONDS:-20}
      - SQS_WORKER_VISIBILITY_TIMEOUT_SECONDS=${SQS_WORKER_VISIBILITY_TIMEOUT_SECONDS:-30}
      # Logging Configuration
      - LOG_LEVEL=${LOG_LEVEL:-INFO}
    extra_hosts:
      - "host.docker.internal:host-gateway"
    command: ["java", "-jar", "/app/sqs-redis-bridge.jar"]
    restart: unless-stopped

  # MC Authentication Service
  mc-auth:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: kishax-mc-auth
    ports:
      - "8080:8080"
    environment:
      - ENVIRONMENT=production
      # Authentication API Configuration
      - AUTH_API_ENABLED=true
      - AUTH_API_PORT=8080
      - AUTH_API_KEY=${AUTH_API_KEY}
      # Database Configuration (RDS PostgreSQL)
      - DATABASE_URL=${DATABASE_URL}
      # Logging Configuration
      - LOG_LEVEL=${LOG_LEVEL:-INFO}
    command: ["java", "-jar", "/app/mc-auth.jar"]
    restart: unless-stopped

  # Discord Bot Service
  discord-bot:
    build:
      context: ../discord
      dockerfile: Dockerfile
    container_name: kishax-discord-bot
    environment:
      # AWS Configuration
      - AWS_REGION=${AWS_REGION}
      - MC_WEB_SQS_ACCESS_KEY_ID=${MC_WEB_SQS_ACCESS_KEY_ID}
      - MC_WEB_SQS_SECRET_ACCESS_KEY=${MC_WEB_SQS_SECRET_ACCESS_KEY}
      # SQS Queue URLs
      - TO_WEB_QUEUE_URL=${TO_WEB_QUEUE_URL}
      - TO_MC_QUEUE_URL=${TO_MC_QUEUE_URL}
      - TO_DISCORD_QUEUE_URL=${TO_DISCORD_QUEUE_URL}
      # Redis Configuration (ホスト側Redis #2)
      - REDIS_URL=${REDIS_URL:-redis://host.docker.internal:6380}
      - REDIS_CONNECTION_TIMEOUT=${REDIS_CONNECTION_TIMEOUT:-5000}
      - REDIS_COMMAND_TIMEOUT=${REDIS_COMMAND_TIMEOUT:-3000}
      # Discord Configuration
      - DISCORD_TOKEN=${DISCORD_TOKEN}
      - DISCORD_CHANNEL_ID=${DISCORD_CHANNEL_ID}
      - DISCORD_CHAT_CHANNEL_ID=${DISCORD_CHAT_CHANNEL_ID}
      - DISCORD_ADMIN_CHANNEL_ID=${DISCORD_ADMIN_CHANNEL_ID}
      - DISCORD_RULE_CHANNEL_ID=${DISCORD_RULE_CHANNEL_ID}
      - DISCORD_RULE_MESSAGE_ID=${DISCORD_RULE_MESSAGE_ID}
      - DISCORD_PRESENCE_ACTIVITY=${DISCORD_PRESENCE_ACTIVITY:-Kishaxサーバー}
      - DISCORD_GUILD_ID=${DISCORD_GUILD_ID}
      - BE_DEFAULT_EMOJI_NAME=${BE_DEFAULT_EMOJI_NAME:-steve}
      # SQS Configuration for Discord
      - AWS_SQS_MAX_MESSAGES=${AWS_SQS_MAX_MESSAGES:-10}
      - AWS_SQS_WAIT_TIME_SECONDS=${AWS_SQS_WAIT_TIME_SECONDS:-20}
      # Queue Mode Configuration
      - QUEUE_MODE=${QUEUE_MODE:-DISCORD}
      - SQS_WORKER_ENABLED=${SQS_WORKER_ENABLED:-false}
      - SQS_WORKER_POLLING_INTERVAL=${SQS_WORKER_POLLING_INTERVAL:-5}
      - SQS_WORKER_MAX_MESSAGES=${SQS_WORKER_MAX_MESSAGES:-10}
      - SQS_WORKER_WAIT_TIME=${SQS_WORKER_WAIT_TIME:-20}
      - SQS_WORKER_VISIBILITY_TIMEOUT=${SQS_WORKER_VISIBILITY_TIMEOUT:-300}
      # Application Configuration
      - SHUTDOWN_GRACE_PERIOD=${SHUTDOWN_GRACE_PERIOD:-10}
    extra_hosts:
      - "host.docker.internal:host-gateway"
    restart: unless-stopped
```

**補足: Dockerfileの分割（推奨）**

本番環境では、各サービス専用のDockerfileを作成することを推奨します：

**`Dockerfile.sqs-redis-bridge`**:
```dockerfile
FROM eclipse-temurin:21-jdk AS builder
RUN apt-get update && apt-get install -y maven && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY . .
RUN mvn clean package -DskipTests

FROM eclipse-temurin:21-jre
WORKDIR /app
COPY --from=builder /app/sqs-redis-bridge/target/sqs-redis-bridge-*-with-dependencies.jar sqs-redis-bridge.jar
RUN groupadd -r appuser && useradd -r -g appuser appuser && chown -R appuser:appuser /app
USER appuser
CMD ["java", "-jar", "/app/sqs-redis-bridge.jar"]
```

**`Dockerfile.mc-auth`**:
```dockerfile
FROM eclipse-temurin:21-jdk AS builder
RUN apt-get update && apt-get install -y maven && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY . .
RUN mvn clean package -DskipTests

FROM eclipse-temurin:21-jre
WORKDIR /app
COPY --from=builder /app/mc-auth/target/mc-auth-*-with-dependencies.jar mc-auth.jar
RUN groupadd -r appuser && useradd -r -g appuser appuser && chown -R appuser:appuser /app
USER appuser
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
  CMD curl -f http://localhost:8080/health || exit 1
CMD ["java", "-jar", "/app/mc-auth.jar"]
```

compose.yamlで使用：
```yaml
services:
  sqs-redis-bridge:
    build:
      context: .
      dockerfile: Dockerfile.sqs-redis-bridge
    # ... rest of config
  
  mc-auth:
    build:
      context: .
      dockerfile: Dockerfile.mc-auth
    # ... rest of config
```

#### 2. .envファイル作成

```bash
# Jump Server経由でi-bに接続（Private subnet）
# 方法1: SSM Port Forward経由
aws ssm start-session --target i-0705b4674660068d2 --profile AdministratorAccess-126112056177

# 方法2: Jump Server (i-d)経由でSSH（Key Pairが必要）
# まずi-dに接続
aws ssm start-session --target i-08b0ec0e9684fc2f2 --profile AdministratorAccess-126112056177
# i-dからi-bへSSH
ssh -i /path/to/minecraft.pem ec2-user@10.0.36.61

# apiユーザーに切り替え
sudo su - api
cd /opt/api

# .envファイル作成
cat > .env << 'EOF'
# Database Configuration (RDS PostgreSQL)
DATABASE_URL=jdbc:postgresql://<RDS PostgreSQL Endpoint>:5432/kishax?user=postgres&password=<terraform.tfvarsから取得>

# AWS SQS Configuration
AWS_REGION=ap-northeast-1
MC_WEB_SQS_ACCESS_KEY_ID=<SSM: /kishax/production/sqs/access-key-id>
MC_WEB_SQS_SECRET_ACCESS_KEY=<SSM: /kishax/production/sqs/secret-access-key>
TO_WEB_QUEUE_URL=<terraform output>
TO_MC_QUEUE_URL=<terraform output>
TO_DISCORD_QUEUE_URL=<terraform output>

# Redis Configuration (localhost)
REDIS_URL=redis://127.0.0.1:6379

# Queue Mode
QUEUE_MODE=WEB

# Authentication API
AUTH_API_KEY=<新規生成またはSSMから>

# Discord Bot Configuration
DISCORD_TOKEN=<Discord Bot Token>
DISCORD_CHANNEL_ID=<Channel ID>
DISCORD_CHAT_CHANNEL_ID=<Chat Channel ID>
DISCORD_ADMIN_CHANNEL_ID=<Admin Channel ID>
DISCORD_RULE_CHANNEL_ID=<Rule Channel ID>
DISCORD_RULE_MESSAGE_ID=<Rule Message ID>
DISCORD_GUILD_ID=<Guild ID>
DISCORD_PRESENCE_ACTIVITY=Kishaxサーバー
BE_DEFAULT_EMOJI_NAME=steve

# Logging
LOG_LEVEL=INFO
EOF

chmod 600 .env
```

#### 3. デプロイ

```bash
# compose.yamlをコピー
cp /path/to/apps/api/compose-ec2.yaml docker-compose.yml

# オプション1: ソースコードからビルド（初回）
docker-compose build

# オプション2: 事前ビルド済みJARを使用
# （ローカルでビルドしたJARをEC2にコピー済みの場合）
# Dockerfileでビルドスキップ条件が満たされる

# 起動
docker-compose up -d

# ログ確認
docker-compose logs -f

# 各サービスの状態確認
docker-compose ps
# mc-auth, sqs-redis-bridge, discord-bot が全てUpであることを確認

# 個別サービスのログ確認
docker-compose logs -f mc-auth
docker-compose logs -f sqs-redis-bridge
docker-compose logs -f discord-bot
```

---

### i-c: Web Server

#### 1. Web compose.yamlの修正

**修正後** (`apps/web/compose-ec2.yaml`):

```yaml
services:
  web:
    build:
      context: .
      dockerfile: Dockerfile
      args:
        NODE_ENV: production
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=production
      # Database Configuration (RDS PostgreSQL)
      - DATABASE_URL=${DATABASE_URL}
      # NextAuth Configuration
      - NEXTAUTH_URL=${NEXTAUTH_URL:-https://kishax.net}
      - NEXTAUTH_SECRET=${NEXTAUTH_SECRET}
      # OAuth Configuration
      - GOOGLE_CLIENT_ID=${GOOGLE_CLIENT_ID}
      - GOOGLE_CLIENT_SECRET=${GOOGLE_CLIENT_SECRET}
      - DISCORD_CLIENT_ID=${DISCORD_CLIENT_ID}
      - DISCORD_CLIENT_SECRET=${DISCORD_CLIENT_SECRET}
      - TWITTER_CLIENT_ID=${TWITTER_CLIENT_ID}
      - TWITTER_CLIENT_SECRET=${TWITTER_CLIENT_SECRET}
      # Email Configuration
      - EMAIL_HOST=${EMAIL_HOST}
      - EMAIL_PORT=${EMAIL_PORT:-587}
      - EMAIL_USER=${EMAIL_USER}
      - EMAIL_PASS=${EMAIL_PASS}
      - EMAIL_FROM=${EMAIL_FROM}
      # Redis Configuration (i-b host Redis #2)
      - REDIS_URL=${REDIS_URL:-redis://10.0.36.61:6380}
      # Internal API Key
      - INTERNAL_API_KEY=${INTERNAL_API_KEY}
    restart: unless-stopped
```

#### 2. .envファイル作成

```bash
# SSM Session Manager経由でi-cに接続
aws ssm start-session --target i-0c179bef38c95181c --profile AdministratorAccess-126112056177

# webユーザーに切り替え
sudo su - web
cd /opt/web

# Web用.envファイル
cat > .env << 'EOF'
# Database (RDS PostgreSQL)
DATABASE_URL=postgresql://postgres:<password>@<RDS Endpoint>:5432/kishax

# NextAuth
NEXTAUTH_URL=https://kishax.net
NEXTAUTH_SECRET=<32文字以上のランダム文字列>

# OAuth Providers
GOOGLE_CLIENT_ID=<Google Console>
GOOGLE_CLIENT_SECRET=<Google Console>
DISCORD_CLIENT_ID=<Discord Developer Portal>
DISCORD_CLIENT_SECRET=<Discord Developer Portal>
TWITTER_CLIENT_ID=<Twitter Developer Portal>
TWITTER_CLIENT_SECRET=<Twitter Developer Portal>

# Email
EMAIL_HOST=<SMTP Host>
EMAIL_PORT=587
EMAIL_USER=<SMTP User>
EMAIL_PASS=<SMTP Password>
EMAIL_FROM=noreply@kishax.net

# Redis (i-b Redis #2)
REDIS_URL=redis://10.0.36.61:6380

# Internal API Key
INTERNAL_API_KEY=<新規生成>
EOF

chmod 600 .env
```

#### 3. デプロイ

```bash
# Web起動
cd /opt/web
cp /path/to/apps/web/compose-ec2.yaml docker-compose.yml
docker-compose up -d

# ログ確認
docker-compose logs -f
```

---

## 🔐 環境変数の管理

### SSM Parameter Store の活用

**保存する値**:
```bash
# SQS認証情報
/kishax/production/sqs/access-key-id
/kishax/production/sqs/secret-access-key

# Discord Bot Token
/kishax/production/discord/bot-token

# OAuth Secrets
/kishax/production/oauth/google-client-secret
/kishax/production/oauth/discord-client-secret
/kishax/production/oauth/twitter-client-secret

# Email Configuration
/kishax/production/email/smtp-password

# API Keys
/kishax/production/api/auth-key
/kishax/production/api/internal-key

# NextAuth Secret
/kishax/production/nextauth/secret
```

### SSM Parameter取得スクリプト

```bash
#!/bin/bash
# get-ssm-params.sh

PROFILE="AdministratorAccess-126112056177"

get_param() {
    aws ssm get-parameter --name "$1" --with-decryption --query 'Parameter.Value' --output text --profile $PROFILE
}

echo "SQS_ACCESS_KEY_ID=$(get_param /kishax/production/sqs/access-key-id)"
echo "SQS_SECRET_ACCESS_KEY=$(get_param /kishax/production/sqs/secret-access-key)"
echo "DISCORD_TOKEN=$(get_param /kishax/production/discord/bot-token)"
# ... 他のパラメータ
```

---

## 📝 デプロイチェックリスト

### i-a (MC Server)
- [ ] RDS MySQL接続確認
- [ ] i-b Redis (port 6379)接続確認
- [ ] SQSキュー接続確認
- [ ] Minecraftサーバー起動確認（port 25565）
- [ ] Velocity起動確認（port 25577）
- [ ] 画像保存ディレクトリ権限確認（/mc/server/images）

### i-b (API Server + Discord Bot)
- [ ] Redis #1 (port 6379) 起動確認
- [ ] Redis #2 (port 6380) 起動確認
- [ ] RDS PostgreSQL接続確認
- [ ] MC Auth API起動確認（port 8080）
- [ ] SQS Redis Bridge起動確認
- [ ] Discord Bot起動確認
- [ ] Discord Bot Discord接続確認
- [ ] SQSキュー接続確認（全サービス）

### i-c (Web Server)
- [ ] RDS PostgreSQL接続確認
- [ ] i-b Redis #2 (port 6380)接続確認
- [ ] Next.js Web起動確認（port 3000）
- [ ] CloudFront経由でのアクセス確認（https://kishax.net）

---

## 🚨 トラブルシューティング

### Redis接続エラー

**症状**: `ECONNREFUSED` or `Connection timeout`

**確認事項**:
1. i-bのRedisが起動しているか
   ```bash
   sudo systemctl status redis-mc redis-web
   ```
2. Redisがbind 0.0.0.0で待機しているか
   ```bash
   redis-cli -p 6379 CONFIG GET bind
   redis-cli -p 6380 CONFIG GET bind
   ```
3. Security Groupでポート6379, 6380が許可されているか
4. 接続元EC2からtelnetテスト
   ```bash
   telnet 10.0.36.61 6379
   telnet 10.0.36.61 6380
   ```

### RDS接続エラー

**確認事項**:
1. RDSエンドポイントが正しいか（terraform output確認）
2. Security Groupでポート3306（MySQL）/5432（PostgreSQL）が許可されているか
3. RDSが利用可能状態か
   ```bash
   aws rds describe-db-instances --profile AdministratorAccess-126112056177
   ```
4. 認証情報が正しいか（terraform.tfvars確認）

### Docker起動エラー

**確認事項**:
1. Dockerサービスが起動しているか
   ```bash
   sudo systemctl status docker
   ```
2. User Dataが正常に実行されたか
   ```bash
   sudo cat /var/log/cloud-init-output.log
   ```
3. ディスク容量は十分か
   ```bash
   df -h
   ```

---

## 📅 次のステップ

1. **compose-ec2.yamlファイル作成**: 各アプリケーションの本番用compose.yamlを作成
2. **i-bのRedis構築**: 2つのRedisインスタンスをセットアップ
3. **SSM Parameter登録**: 全ての機密情報をSSMに登録
4. **.envテンプレート作成**: 各EC2インスタンス用の.envテンプレート作成
5. **デプロイスクリプト作成**: 自動デプロイスクリプトの作成
6. **監視設定**: CloudWatch Logs, Metricsの設定
7. **バックアップ設定**: Dockerボリュームのバックアップ戦略

---

**作成者**: AI Assistant  
**最終更新**: 2025-12-13
