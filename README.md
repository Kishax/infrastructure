# KishaX Infrastructure

KishaX の統合インフラストラクチャプロジェクト

## Architecture

```
[Minecraft Server] → [API Gateway] → [Lambda] → [SQS] → [Discord Bot]
[Web App] ←→ [RDS PostgreSQL]
[Gather Bot] → [Slack API]
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

---

**Last Update**: 2025-08-25
