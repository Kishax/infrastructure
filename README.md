# KishaX Infrastructure

KishaX の統合インフラストラクチャプロジェクト

## Architecture

### 最新インフラ構成 (EC2ベース - 2026/01更新)
![最新インフラ図](assets/202601/1-infrastructure.png)

### 前世代インフラ構成
- [2025/12 - EC2移行直後](assets/202512/2-infrastructure.png)
- [2025/12 - EC2移行前](assets/202512/1-infrastructure.png)
- [2025/06 - ECS/Fargate環境](assets/202506/1-infrastructure.png)

## 📋 Project Structure

```
kishax/
├── apps/                   # アプリケーション層 (Git Submodules)
│   ├── api/               # 共通APIサーバー (Java + Spring Boot)
│   │   ├── compose.yaml   # Redis + SQS Bridge + API + Discord Bot
│   │   └── Dockerfile*    # 各サービス用Dockerfile
│   ├── mc/                # Minecraft Server (Velocity + Spigot)
│   │   ├── compose.yml    # MC Server + MySQL
│   │   ├── Dockerfile     # Multi-stage build
│   │   └── docker/
│   │       ├── config/servers.json        # サーバー構成定義
│   │       ├── database/                  # DB関連
│   │       ├── scripts/                   # 起動・管理スクリプト
│   │       └── templates/                 # 設定テンプレート
│   └── web/               # Web アプリケーション (Next.js 16)
│       ├── compose.yaml   # Next.js App
│       └── Dockerfile     # Standalone build
│
├── terraform/             # Infrastructure as Code
│   ├── main.tf           # メイン構成
│   ├── modules/          # 再利用可能モジュール
│   │   ├── vpc/          # VPC, Subnets, IGW, S3 Endpoint
│   │   ├── ec2/          # 4 EC2 Instances
│   │   ├── rds/          # PostgreSQL + MySQL
│   │   ├── sqs/          # 3 Queues + DLQs
│   │   ├── s3/           # Docker Images bucket
│   │   ├── cloudfront/   # CDN
│   │   ├── route53/      # DNS
│   │   ├── iam/          # Roles + Policies
│   │   └── security_groups/ # Security Groups
│   └── terraform.tfvars  # 環境変数
│
└── docs/infrastructure/ec2/  # ドキュメント
    ├── deployment.md         # デプロイメントガイド
    ├── architecture.md       # アーキテクチャ詳細
    ├── mc-requirements.md    # MC Server要件
    └── next-challenge.md     # 今後の改善案
```

## 🏗️ Infrastructure Overview

### EC2 Instances (5台構成)

| Instance | Type | Role | Subnet | Schedule | Elastic IP |
|----------|------|------|--------|----------|------------|
| **i-a** | t3.large On-Demand | MC Server | Public | 22:00-27:00 JST | ✅ |
| **i-b** | t3.small On-Demand | API + Redis | Public | 22:00-27:00 JST | ✅ |
| **i-c** | t2.micro On-Demand | Web Server | Public | 22:00-27:00 JST | ✅ |
| **i-d** | t2.micro On-Demand | Jump Server | Public | 手動 | - |
| **i-e** | t3.small On-Demand | Terraria Server | Public | 手動 | ✅ |

> **⚠️ 注意**: i-b（API）とi-c（Web）は、将来的には24/7稼働を予定していますが、現在はコスト最適化のため、i-a（MC）と同様に22:00-27:00 JSTのみ稼働しています。Lambda + EventBridgeで3インスタンス（i-a/i-b/i-c）を同時起動/停止。

**主要な変更点**:
- ✅ **全インスタンスEIP化**: 固定IPによる管理簡素化
- ✅ **Terrariaサーバー追加**: i-e（t3.small）でTShock 5.3.0運用
- ✅ **自動スケジューリング**: Lambda + EventBridgeでi-a/i-b/i-c を22:00 JST起動 → 翌3:00停止
- ✅ **Spot→On-Demand移行**: 安定性向上のためi-b/i-cをOn-Demand化

### Databases (RDS)

| Database | Engine | Instance | Purpose |
|----------|--------|----------|---------|
| PostgreSQL | v16.6 | db.t4g.micro | Web + API + Discord Bot |
| MySQL | v8.0.40 | db.t4g.micro | Minecraft Server |

### Storage

| Service | Bucket/Table | Purpose |
|---------|--------------|---------|
| S3 | kishax-prod-docker-images | Docker Image保存 (30日ライフサイクル) |
| S3 | kishax-prod-world-backups | MCワールドバックアップ (deployment/ + workspace/) |
| S3 | kishax-prod-image-maps | MC画像マップ用 |
| S3 | kishax-prod-terraria-backups | Terrariaワールドバックアップ |
| S3 | kishax-terraform-state | Terraform状態管理 |
| DynamoDB | kishax-terraform-locks | Terraform State Lock |

**S3バックアップ戦略**:
- `deployment/`: 本番デプロイ用（圧縮tar.gz、バージョン管理あり）
- `workspace/`: 実験用作業スペース（非圧縮、差分同期、1世代のみ）
- 詳細: [world-s3-architecture.md](docs/infrastructure/ec2/world-s3-architecture.md)

### Messaging & Queues

| Queue | Purpose | Connected Services |
|-------|---------|-------------------|
| to-mc-queue | Web → MC通信 | i-a, i-c |
| to-web-queue | MC → Web通信 | i-a, i-c |
| discord-queue | Discord通知 | i-a, i-b, i-c |

**SQS認証**: IAM Userのアクセスキー（SSM Parameter Storeに保管）

### Content Delivery & Automation

- **CloudFront**: kishax.net (HTTPS)
  - Origin: i-c (Port 80)
  - ACM証明書: *.kishax.net
  - キャッシュ最適化

- **Lambda + EventBridge**: EC2自動スケジューリング
  - 22:00 JST: 3インスタンス自動起動（i-a/i-b/i-c）
  - 翌日3:00 JST: 3インスタンス自動停止（i-a/i-b/i-c）
  - コスト最適化: 稼働時間を5時間/日に制限

## 🎮 MC Server: servers.json管理システム

### 特徴

MC Serverは`apps/mc/docker/config/servers.json`による**完全自動化システム**を採用：

1. **動的メモリ配分**: OVERALL_MEMORYから自動計算
2. **複数Spigotサーバー対応**: memory_ratioで有効/無効
3. **プラグインプリセット**: preset/customで柔軟に管理
4. **自動設定生成**: velocity.toml, velocity-kishax-config.ymlを自動生成
5. **DB自動登録**: statusテーブルにサーバー情報を自動登録

### servers.json 構造

```json
{
  "memory": { "overall": "8.0", "buffer": 0.1, "mc_wantage": 1.0 },
  "plugin_presets": { "essential": [...], "full": [...] },
  "proxies": [{ "name": "velocity-main", "memory_ratio": 0.1, ... }],
  "spigots": [{ 
    "name": "spigot-main", 
    "memory_ratio": 0.9,
    "is_home": true,
    "minecraft_version": "1.21.8",
    "kishax_spigot_jar": "Kishax-Spigot-1.21.8.jar",
    ...
  }],
  "plugins": { ... }
}
```

### メモリ計算式

```
MC全体メモリ (O-MC) = (OVERALL_MEMORY - Buffer) × mc_wantage
各サーバーメモリ = O-MC × memory_ratio + (残りメモリ / サーバー数)
```

### 自動化スクリプト

| Script | Purpose |
|--------|---------|
| setup-directories.sh | テンプレートからディレクトリ生成 |
| calculate-memory.sh | メモリ自動計算 |
| generate-velocity-config.sh | Velocity設定自動生成 |
| deploy-plugins.sh | プラグイン自動配置 |
| register-servers-to-db.sh | statusテーブル自動登録 |

## 🌐 Web Application (i-c) - ✅ Deployed

### Tech Stack

- **Framework**: Next.js 16 (App Router)
- **Auth**: next-auth v5.0.0-beta.30
- **Database**: Prisma + PostgreSQL
- **Redis**: ioredis (i-b:6380)

### Deployment

- **ビルド方法**: ローカルビルド (ARM64 Mac → x86_64 EC2)
- **転送方法**: S3経由 (SSH転送は遅いため)
- **実行**: Docker Compose (pre-built image)
- **公開**: CloudFront経由 (HTTPS)

### 環境変数管理

- `SEED_ENV=production`: 本番環境でシード投入スキップ
- `DATABASE_URL`: URL encoding必須 (`#` → `%23`, `$` → `%24`)
- `REDIS_URL`: i-bのプライベートIP使用
- `INTERNAL_API_KEY`: openssl生成の32 byte hex

## 🔐 Security

### IAM Roles (Least Privilege)

- **mc_server_role**: SQS, S3, CloudWatch, SSM
- **api_server_role**: SQS, S3, CloudWatch, SSM
- **web_server_role**: SQS, S3, CloudWatch, SSM
- **jump_server_role**: SSM Session Manager

### Security Groups

- **i-a**: 25565, 25577 (MC), 22 (SSH from Jump)
- **i-b**: 8080 (API from i-a/i-c), 6379 (Redis from i-a), 6380 (Redis from i-c), 22 (SSH from Jump)
- **i-c**: 80 (HTTP), 22 (SSH from Jump)
- **i-d**: SSM only (no inbound)

### Access Methods

- **Jump Server経由**: SSM Session Manager + Port Forwarding
- **RDS接続**: Jump Server経由のポートフォワーディング
- **EC2アクセス**: Jump Server経由のSSHトンネル

## 🚀 Deployment

### Prerequisites

```bash
# AWS SSO ログイン
make login

# Terraform初期化
cd terraform
terraform init
terraform plan
terraform apply
```

### デプロイ順序

```
1. i-b (API Server + Redis) ← 他が依存
   ↓
2. i-c (Web Server)         ← i-bのRedis/APIに依存 ✅
   ↓
3. i-a (MC Server)          ← i-bのRedis/APIに依存 ✅
   ↓
4. i-e (Terraria Server)    ← 独立（手動起動/停止） ✅
```

詳細は [`docs/infrastructure/ec2/deployment.md`](docs/infrastructure/ec2/deployment.md) を参照。

## 📊 Cost Estimate

| Resource | Spec | Monthly Cost (JPY) | Note |
|----------|------|--------------------|------|
| i-a (MC) | t3.large On-Demand | ¥500 | 5時間/日のみ稼働 |
| i-b (API) | t3.small On-Demand | ¥200 | 5時間/日のみ稼働 |
| i-c (Web) | t2.micro On-Demand | ¥100 | 5時間/日のみ稼働 |
| i-d (Jump) | t2.micro On-Demand | ¥200 | 必要時のみ起動 |
| i-e (Terraria) | t3.small On-Demand | ¥200 | 必要時のみ起動 |
| RDS PostgreSQL | db.t4g.micro | ¥1,200 | 24/7稼働 |
| RDS MySQL | db.t4g.micro | ¥1,200 | 24/7稼働 |
| Elastic IP | 4個 (i-a/b/c/e) | ¥200 | 関連付け済み |
| CloudFront | CDN + HTTPS | ¥300 | - |
| S3 + その他 | Storage + Transfer | ¥500 | World Backups含む |
| Lambda + EventBridge | EC2 Scheduler | ¥50 | 月180回実行 |
| **合計** | | **¥4,650/月** | 目標達成 |

> **⚠️ 注意**: 現在はコスト最適化のため、i-a/i-b/i-cを5時間/日運用していますが、将来的にi-b/i-cを24/7稼働に変更する場合、月額コストは約¥6,000-7,000に上昇します。

## 📚 Documentation

- [Deployment Guide](docs/infrastructure/ec2/deployment.md) - 詳細デプロイ手順
- [Architecture Details](docs/infrastructure/ec2/architecture.md) - アーキテクチャ詳細
- [MC Requirements](docs/infrastructure/ec2/mc-requirements.md) - MC Server要件
- [Next Challenges](docs/infrastructure/ec2/next-challenge.md) - 今後の改善案

## 🔄 Recent Updates

### 2026-01-04
- ✅ **全インスタンスEIP化**: 固定IP管理による安定性向上
- ✅ **Terrariaサーバー追加**: i-e（t3.small）でTShock 5.3.0運用開始
- ✅ **自動スケジューリング拡張**: i-a/i-b/i-cを同時起動/停止（22:00-27:00 JST）
- ✅ **コスト最適化**: 月額¥4,650達成（将来的に24/7化予定）
- ✅ **S3ワールドバックアップシステム**: deployment/ + workspace/の2層構造実装
- ✅ **Spot→On-Demand移行**: i-b/i-cの安定性向上
- ✅ **SSM Session Manager移行**: SSH接続廃止、Terraform差分解消
- ✅ **アーキテクチャ図更新**: 2026/01版作成

### 2025-12-14
- ✅ i-c (Web Server) デプロイ完了
- ✅ MC Server: servers.json動的管理システム実装
- ✅ ディレクトリ構造リファクタリング完了
- ✅ S3 Docker Images導入（クロスアーキテクチャビルド対応）
- ✅ CloudFront設定修正（Next.js routing対応）

### 2025-12-12
- ✅ i-b を Public Subnet に移動（コスト最適化）
- ✅ Security Group整理（Redis専用ポート分離）
- ✅ S3 VPC Gateway Endpoint追加

---

**Maintained by**: Kishax Development Team
**Last Update**: 2026-01-04
