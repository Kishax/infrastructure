# KishaX Infrastructure

KishaX の統合インフラストラクチャプロジェクト

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     Kishax Infrastructure                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────┐    ┌──────────────┐    ┌─────────────────────┐ │
│  │ Discord Bot │←───│ SQS Discord  │←───│   API Gateway       │ │
│  │   (ECS)     │    │   Queue      │    │  + Lambda Proxy     │ │
│  └─────────────┘    └──────────────┘    └─────────────────────┘ │
│  ┌─────────────┐                                 ↑              │
│  │   RDS       │                                 │              │
│  │ PostgresSQL │                                 │              │
│  └─────────────┘                                 │              │
│        ↑                                         │              │
│        │                                         │              │
│        ↓                                         │              │
│  ┌─────────────┐                                 │              │
│  │   Web App   │                                 │              │
│  │   (ECS)     │ ─────────────┐                  │              │
│  └─────────────┘              │                  │              │
│                               │                  │              │
│         ┌─────────────────────┤                  │              │
│         │                     │                  │              │
│         │      MC ←→ Web      │                  │              │
│         │    SQS双方向通信    │                  │              │
│         ↑                     ↓                  │              │
│  ┌─────────────┐    ┌──────────────┐             │              │
│  │    SQS      │    │     SQS      │             │              │
│  │ MC→Web Queue│    │ Web→MC Queue │             │              │
│  └─────────────┘    └──────────────┘             │              │
│         ↑                     ↓                  │              │
│         │                     │                  │              │
│         └─────────────────────┤                  │              │
│                               │                  │              │
│                               │                  │              │
│  ┌─────────────┐              │                  │              │
│  │ MC Plugins  │──────────────┘                  │              │
│  │ (Velocity + │                                 │              │
│  │  Spigot)    │─────────────────────────────────┘              │
│  └─────────────┘                                                │
│                                                                 │
│  ┌─────────────┐    ┌──────────────┐                            │
│  │ Gather Bot  │───→│  Slack API   │                            │
│  │   (ECS)     │    │              │                            │
│  └─────────────┘    └──────────────┘                            │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Tree

```
kishax/
├── apps/                   # アプリケーション層
│   ├── discord-bot/       # Discord Bot (ECS)
│   ├── gather-bot/        # Gather Bot (ECS)
│   ├── mc-plugins/        # Minecraft プラグイン (Velocity + Spigot)
│   └── web/               # Web アプリケーション (ECS)
└── aws/                   # AWS共通リソース・ポリシー
```
## Services

このプロジェクトは4つの主要アプリケーションとAWSインフラから構成されています：

- **Discord Bot**: MinecraftイベントのDiscord通知 (Java/ECS)
- **Gather Bot**: Gather.town監視とSlack通知 (Node.js/ECS)  
- **Minecraft Plugins**: Velocity/Spigotプラグイン (Java)
- **Web Application**: プレイヤー認証・管理 (Next.js/ECS)

## MC ↔ Web Communication System

### 通信フロー

**Web → MC (コマンド送信):**
1. Web App → SQS (`web-to-mc-queue-v2`) 直接送信
2. MC Plugins が SQS をポーリングしてコマンドを受信・実行

**MC → Web (イベント通知):**
1. MC Plugins → SQS (`mc-to-web-queue-v2`) 直接送信
2. Web App が SQS をポーリングしてイベントを受信・処理

**MC → Discord (通知):**
1. MC Plugins → API Gateway (`/discord`) → Lambda → SQS (`discord-queue-v2`)
2. Discord Bot が SQS をポーリングして通知を送信

### メッセージタイプ

**Web → MC:**
- `web_mc_auth_confirm`: プレイヤー認証確認
- `web_mc_teleport`: テレポートコマンド
- `web_mc_server_switch`: サーバー切り替え
- `web_mc_message`: メッセージ送信

**MC → Web:**
- `mc_web_auth_response`: 認証レスポンス
- `mc_web_player_status`: プレイヤーステータス変更
- `mc_web_server_info`: サーバー情報更新

### AWS リソース

**SQS キュー:**
- `kishax-web-to-mc-queue-v2` + DLQ (Web→MC通信用)
- `kishax-mc-to-web-queue-v2` + DLQ (MC→Web通信用) 
- `kishax-discord-queue-v2` + DLQ (Discord Bot用)

**API Gateway エンドポイント:**
- `POST /discord` - MC→Discord 通知送信
- `POST /server-status` - サーバーステータス通知
- `POST /player-request` - プレイヤーリクエスト
- `POST /broadcast` - ブロードキャストメッセージ
- その他運用エンドポイント

**Lambda:**
- `kishax-infrastructure-lambda` - API Gateway → SQS 転送処理

## QuickStart

### First Setup
```bash
make setup-first-time
make setup-prerequisites
```

### Deploy
```bash
# 全サービスデプロイ
make deploy-all

# 個別サービスデプロイ  
make deploy-discord-bot
make deploy-gather-bot
make deploy-web
```

## Dev-Guide

- **AWS インフラ**: [aws/README.md](./aws/README.md)  
- **デプロイメント**: [aws/DEPLOY.md](./aws/DEPLOY.md)

## Infrastructure Summary

### ECS Services (Fargate)
- **Discord Bot**: `kishax-discord-bot-service-v2` (256CPU/512MB)
- **Gather Bot**: `kishax-gather-bot-service-v2` (256CPU/512MB)  
- **Web App**: `kishax-web-service-v2` (1024CPU/2048MB)

### Networking
- **ALB**: `kishax-alb-v2` (Internet-facing)
- **Target Group**: `kishax-web-tg-v2` (Health check: `/api/health`)
- **Security Groups**: ECS用とALB用で分離
- **SSL**: HTTPS強制リダイレクト対応

### Monitoring & Logging
- **CloudWatch Logs**: 各サービス毎に分離 (30日保持)
- **SQS DLQ**: 最大3回リトライ後にDead Letter Queueへ

### Configuration Management
- **SSM Parameter Store**: 全ての機密情報を暗号化保存
  - `/kishax/discord/*` - Discord Bot設定
  - `/kishax/web/*` - Web アプリ設定  
  - `/kishax/sqs/*` - SQS関連設定
  - `/kishax/gather/*` - Gather Bot設定
  - `/kishax/slack/*` - Slack通知設定

---

**Last Update**: 2025-08-27
