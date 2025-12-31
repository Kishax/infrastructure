# Kishax Infrastructure - 今後の改善課題

**作成日**: 2025-12-14  
**対象**: Production環境の将来的な改善

---

## 📋 概要

現在のインフラ構成は**コスト最適化**を最優先に設計されています。この資料では、将来的にセキュリティやスケーラビリティを向上させるための改善案をまとめます。

---

## 🎯 現在の構成と選択理由

### EC2インスタンス配置

| インスタンス | Subnet | 理由 |
|------------|--------|------|
| **i-a** (MC Server) | Public | Elastic IP必須、Minecraft接続 |
| **i-b** (API Server) | **Public** | **インターネットアクセス必須（Docker Hub, Discord API）、NAT Gateway回避** |
| **i-c** (Web Server) | Public | CloudFront Origin |
| **i-d** (Jump Server) | Public | SSM Agent接続のため |

### コスト最適化の選択

i-b (API Server)は本来Private Subnetに配置すべきですが、以下の理由でPublic Subnetを選択：

**Private Subnet配置時の追加コスト**:
- NAT Gateway: **$32/月** (~¥4,800)
- または VPC Endpoints (S3 + SQS + SSM): **$22/月** (~¥3,300)
  - ⚠️ ただし、Discord APIへのアクセスには不十分（インターネット必須）

**Public Subnet配置のメリット**:
- ✅ 追加コスト **$0**
- ✅ インターネットアクセス可能（Docker Hub, Discord API等）
- ✅ シンプルな構成

**セキュリティ対策**:
- Security Groupで適切に保護
  - Port 8080: MC/Webからのみ
  - Port 6379/6380: MC/Webからのみ（Redis）
  - Port 22: Jump Serverからのみ
- 外部からの直接アクセスは不可

---

## 🚀 将来の改善案

### 案1: Discord Botを独立インスタンス（i-e）に分離

#### 構成

```
┌─────────────────────────────────────────────────────────┐
│ Public Subnet 1                                         │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │
│  │  i-a (MC)   │  │  i-c (Web)  │  │  i-d (Jump) │     │
│  └─────────────┘  └─────────────┘  └─────────────┘     │
└─────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────┐
│ Public Subnet 2                                         │
│  ┌──────────────────┐                                   │
│  │  i-e (Discord)   │  ← 新規追加                        │
│  │  - Discord Bot   │                                   │
│  │  - Redis (Web)   │                                   │
│  └──────────────────┘                                   │
└─────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────┐
│ Private Subnet                                          │
│  ┌───────────────────┐                                  │
│  │  i-b (API)        │  ← Private Subnetに戻す            │
│  │  - MC Auth API    │                                  │
│  │  - SQS Bridge     │                                  │
│  │  - Redis (MC)     │                                  │
│  └───────────────────┘                                  │
└─────────────────────────────────────────────────────────┘
```

#### メリット

1. **セキュリティ向上**
   - i-b (API Server)をPrivate Subnetに戻せる
   - MC認証APIとRedisをインターネットから完全に隔離
   - Discord BotのみがPublicに公開

2. **障害の分離**
   - Discord Botの障害がAPI Serverに影響しない
   - 独立したスケーリングが可能

3. **NAT Gateway不要**
   - i-eはPublic SubnetなのでNAT Gateway不要
   - i-bはDiscord APIにアクセスしないため、VPC Endpoints（S3, SQS）のみで動作可能

#### デメリット

1. **追加コスト**
   - i-e (t2.micro Spot): **約$3.5/月**
   - VPC Endpoints (S3無料 + SQS): **約$7.2/月**
   - **合計: 約$10.7/月 (~¥1,600)**

2. **運用複雑化**
   - 管理するインスタンスが1つ増加
   - Redis接続先の変更が必要

#### 実装手順

1. **Terraformでi-eを追加**
   ```hcl
   resource "aws_spot_instance_request" "discord_server" {
     ami           = data.aws_ami.amazon_linux_2.id
     instance_type = "t2.micro"
     subnet_id     = var.public_subnet_ids[1]
     # ...
   }
   ```

2. **VPC Endpointsを追加**（i-b用）
   - S3 Gateway Endpoint（無料）
   - SQS Interface Endpoint（$7.2/月）

3. **Discord Botをi-eに移行**
   - `apps/api/discord-bot` → 独立したデプロイ
   - Redis (Web)もi-eに移動

4. **i-bをPrivate Subnetに戻す**
   ```hcl
   subnet_id = var.private_subnet_ids[0]
   associate_public_ip_address = false
   ```

5. **Security Group更新**
   - i-e用の新しいSGを作成
   - i-b → i-e間の通信ルールを追加

---

### 案2: NAT Gatewayを追加してPrivate Subnet運用

#### 構成

現在のまま、NAT Gatewayを追加してi-bをPrivate Subnetに戻す。

#### メリット

1. **完全なPrivate Subnet運用**
   - i-bが完全にインターネットから隔離
   - 最もセキュアな構成

2. **シンプルな構成**
   - インスタンス数は変わらず
   - VPC Endpointsも不要

#### デメリット

1. **高額な追加コスト**
   - NAT Gateway: **$32/月 (~¥4,800)**
   - データ転送料: $0.045/GB

2. **現在の予算目標（¥5,000-6,000）を大幅超過**

#### 実装手順

1. **NAT Gatewayを追加**
   ```hcl
   resource "aws_eip" "nat" {
     domain = "vpc"
   }
   
   resource "aws_nat_gateway" "main" {
     allocation_id = aws_eip.nat.id
     subnet_id     = var.public_subnet_ids[0]
   }
   ```

2. **Private Route Tableを更新**
   ```hcl
   resource "aws_route" "private_nat" {
     route_table_id         = aws_route_table.private.id
     destination_cidr_block = "0.0.0.0/0"
     nat_gateway_id         = aws_nat_gateway.main.id
   }
   ```

3. **i-bをPrivate Subnetに戻す**

---

### 案3: Web Server (i-c) のアーキテクチャ改善

#### 現在の課題

**問題点**:
- t2.micro (1GB RAM) では Next.js 16 のビルドが不可能（メモリ不足でクラッシュ）
- 現在はローカルビルド → Dockerイメージ転送で対応（手動デプロイ）

#### 改善案

##### 案3-1: Next.js Standalone + S3静的ファイル + Lambda@Edge

**構成**:
```
ユーザー
  ↓
CloudFront
  ├── /_next/static/* → S3 (静的アセット)
  ├── /api/*          → Lambda@Edge (API Routes)
  └── /*              → Lambda@Edge (SSR) + S3 (HTML)
```

**メリット**:
- ✅ EC2不要（i-c削除可能）→ $3.5/月節約
- ✅ 自動スケーリング
- ✅ ビルド問題完全解消（GitHub Actions等でビルド）
- ✅ 高速配信（グローバルエッジ）
- ✅ デプロイ自動化

**デメリット**:
- ❌ Lambda@Edgeの制限
  - パッケージサイズ50MB制限
  - 実行時間30秒制限
- ❌ 初期セットアップが複雑
- ❌ next-auth v5のサーバーサイド処理が動作しない可能性
- ❌ Redis接続がLambda@Edgeから不可（VPC Lambda必要）

**追加コスト**:
- Lambda@Edge: 約$5-10/月（トラフィック次第）
- S3 + CloudFront: 現在と同等
- **差額**: +$1.5~6.5/月（i-c削除分と相殺で実質±$0）

##### 案3-2: CI/CDビルド + S3 + EC2 (t2.small)

**構成**:
```
GitHub Actions (ビルド)
  ↓ Dockerイメージ
ECR/Docker Hub
  ↓ デプロイ
i-c (t2.small, 2GB RAM)
```

**メリット**:
- ✅ ビルド問題解消（GitHub Actionsでビルド）
- ✅ 自動デプロイ可能
- ✅ EC2ランタイムのみ（メモリ不足なし）
- ✅ 現在の構成を大きく変更しない

**デメリット**:
- ❌ t2.small追加コスト: 約$15/月 (~¥2,300)
- ❌ または、On-Demand t2.microで再起動リスク継続

**追加コスト**:
- t2.small On-Demand: $16.7/月 → 現在より+$13.2/月 (~¥2,000)
- t2.small Spot: $5/月 → 現在より+$1.5/月 (~¥230)

##### 案3-3: Fargate Spot (0.25 vCPU, 0.5GB)

**構成**:
```
GitHub Actions (ビルド)
  ↓ コンテナイメージ
ECR
  ↓ デプロイ
Fargate Spot (ECS)
  ↓
CloudFront
```

**メリット**:
- ✅ メモリ不足問題解消
- ✅ 自動デプロイ
- ✅ Spotでコスト削減（~70% off）
- ✅ 完全マネージド（EC2管理不要）

**デメリット**:
- ❌ Fargate Spotの最低構成でもEC2 t2.microより高額
  - 0.25 vCPU + 0.5GB: $0.01419/時 → $10.3/月
  - Spot割引70%: $3.1/月（ただし、可用性低い）

**追加コスト**:
- Fargate Spot最小: $3.1/月 → 現在より±$0/月
- ただし、Spot中断リスクあり

#### 比較表

| 方式 | 月額コスト | メリット | デメリット | 推奨度 |
|-----|----------|---------|----------|-------|
| **現状（ローカルビルド転送）** | $3.5 | 最安、シンプル | 手動デプロイ | ⭐⭐ |
| **案3-1: Lambda@Edge** | $3.5~10 | 自動化、スケーラブル | 複雑、制限多い | ⭐⭐⭐ |
| **案3-2: t2.small + CI/CD** | $16.7~$5 | 自動化、安定 | コスト増 | ⭐⭐⭐ |
| **案3-3: Fargate Spot** | $3.1 | 自動化、マネージド | Spot中断リスク | ⭐⭐ |

#### 推奨アプローチ（段階的移行）

**フェーズ1（現在）: 手動運用で開始**
- ✅ ローカルビルド → イメージ転送
- ✅ コスト最小（$3.5/月）
- ✅ 早期リリース優先

**フェーズ2（収益化後）: CI/CD自動化**
- 📅 GitHub Actions導入
- 📅 t2.small Spotに変更（+$1.5/月）
- 📅 または Lambda@Edge移行（実験的）

**フェーズ3（スケール時）: フルマネージド化**
- 📅 Fargate または Lambda@Edge本格採用
- 📅 グローバル配信最適化

---

## 📊 比較表

| 項目 | 現在の構成 | 案1: i-e分離 | 案2: NAT Gateway | 案3: Web改善 |
|-----|----------|-------------|-----------------|-------------|
| **月額追加コスト** | **$0** | **$10.7** (~¥1,600) | **$32+** (~¥4,800+) | **$0~13** |
| **セキュリティ** | 中 | **高** | **最高** | 中 |
| **運用複雑度** | 低 | 中 | 低 | 中 |
| **スケーラビリティ** | 中 | **高** | 中 | **高** |
| **実装工数** | - | 中 | 小 | 中～大 |
| **主な改善点** | - | API隔離 | 完全隔離 | ビルド自動化 |

---

## 🎯 推奨実装タイミング

### フェーズ1（現在）: コスト最適化優先
- ✅ 全インスタンスPublic Subnet配置
- ✅ 月額予算: ¥5,000-6,000達成

### フェーズ2（収益安定後）: セキュリティ・自動化向上
- 📅 **案1を実装**: Discord Bot分離（i-e追加）
- 📅 **案3を実装**: Web Server CI/CD自動化
- 💰 追加投資: 約¥1,600~3,000/月
- 🔒 i-bをPrivate Subnetに戻す
- 🤖 デプロイ自動化

### フェーズ3（スケール時）: さらなる改善
- Multi-AZ構成
- RDS Multi-AZ化
- Auto Scaling導入
- CloudWatch Logs集約

---

## 📝 メモ

### なぜi-bをPublic Subnetに？

現在の構成では、i-bで以下のサービスが動作：
1. MC認証API
2. SQS-Redis Bridge
3. **Discord Bot** ← インターネット（Discord API）必須
4. Redis x2

Discord BotがDiscord APIと通信するため、インターネットアクセスが必須です。Private Subnetに配置するとNAT Gateway（$32/月）が必要になり、コスト目標を超過します。

将来的に**案1**を実装すれば、Discord Botをi-eに分離し、i-bをPrivate Subnetに戻すことができます。

### なぜi-cでローカルビルド？

**課題**: t2.micro (1GB RAM) では Next.js 16 のDockerビルドが不可能（OOM Killerでクラッシュ）

**現在の対応**:
- ローカル（Macbook）でビルド → イメージ転送
- 手動デプロイだがコスト$0で実現

**将来的な改善** (案3参照):
- GitHub Actions + t2.small/Fargate
- Lambda@Edge完全移行
- CI/CD自動化

---

## 🔗 関連ドキュメント

- [requirements.md](./requirements.md) - 現在の要件定義
- [deployment.md](./deployment.md) - デプロイ手順
- [application-in-ec2.md](./application-in-ec2.md) - アプリケーション構成
