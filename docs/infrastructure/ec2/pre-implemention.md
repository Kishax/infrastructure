# Kishax Infrastructure EC2移行 - 実装前仕様書

**作成日**: 2025-12-12  
**ステータス**: 実装準備完了

---

## 📋 プロジェクト概要

### 目的
旧環境（CloudFormation + ECS/Fargate + ALB）から新環境（Terraform + EC2ベース）への移行により、コスト最適化と運用簡素化を実現する。

### コスト目標
- **旧環境**: 月額 ¥17,000
- **新環境**: 月額 ¥5,000-6,000（約65%削減）

### アーキテクチャレベル
- **旧環境**: 企業レベル（高可用性・スケーラビリティ重視）
- **新環境**: ミドルレベル（コスト・保守性重視）

---

## 🏗️ インフラ構成

### EC2インスタンス構成（4台）

#### **i-a: マイクラサーバー本体**
- **インスタンスタイプ**: `t3.large`（メモリ8GB以上）
- **稼働時間**: 22:00-27:00（5時間/日）
- **役割**: 
  - Minecraftサーバー本体
  - VM（仮想環境）内で動作
  - `apps/mc/compose.yml` をそのまま動かすイメージ
- **担当ネットワーク**: Other Network（インフラ図上部）
- **外部通信**: 
  - i-b（API）への静的IP経由HTTP通信
  - Minecraftクライアントからの接続（ポート25565）
- **ストレージ**: 
  - オリジナル画像ファイル保存先: `/path/to/images/{YYYYMMDD}/{UUID}.png`
  - 例: `/path/to/images/20251212/550e8400-e29b-41d4-a716-446655440000.png`
- **DNS更新**: 
  - 起動時に `mc.kishax.net` のAレコードを自動更新
  - IAMロール + User Dataスクリプトで実装

#### **i-b: バックエンドAPI**
- **インスタンスタイプ**: `t3.small`
- **稼働時間**: 24時間
- **役割**:
  - API（`apps/api`）
  - Redis（EC2内にインストール）
- **担当ネットワーク**: AWS Network（インフラ図下部）
- **外部通信**:
  - **閉域**: 外部インターネットからの直接アクセス不可
  - **許可**: i-a, i-c からの内部HTTP通信のみ
  - RDS PostgreSQL, RDS MySQL への接続
  - SQS との通信
- **Redis構成**:
  - i-a用とi-c用でユーザー分離（検討）
  - ElastiCache不使用（コスト削減）

#### **i-c: Web + Discord Bot**
- **インスタンスタイプ**: `t2.micro`（最小）
- **稼働時間**: 24時間
- **役割**:
  - Web（`apps/web`）
  - Discord Bot（`apps/discord`）
- **外部公開**:
  - CloudFront経由で `:80`, `:443` 公開
  - WAF保護
- **時間制限機能**:
  - i-aのオンタイム（22:00-27:00）に合わせて、フロント側で登録を制限
  - 例: 「現在の時刻はMC認証できません。22:00-27:00にアクセスしてください。」

#### **i-d: RDS踏み台サーバー**
- **インスタンスタイプ**: 最小（`t2.micro`など）
- **稼働時間**: 必要時のみ（通常は停止）
- **役割**: RDS PostgreSQL/MySQL への管理アクセス用
- **用途**: データベースメンテナンス、バックアップ復元、直接SQL実行

---

## 🗄️ データベース構成

### RDS PostgreSQL（メイン）
- **用途**: Web, API, Discord Bot
- **インスタンスタイプ**: `db.t4g.micro` または `db.t3.small`
- **Multi-AZ**: 無効（コスト削減）
- **バックアップ**: 7日間保持
- **接続元**: i-b, i-c（セキュリティグループで制御）

### RDS MySQL（マイクラ専用）
- **用途**: マイクラサーバー専用データベース
- **インスタンスタイプ**: `db.t4g.micro`
- **データ内容**:
  - ゲームデータ（プレイヤー情報、アイテムなど）
  - **分割タイル画像（BLOBデータ）**
- **接続元**: i-a（マイクラサーバー）
- **将来の移行計画**: PostgreSQLへの統合（Phase 3）

**注**: オリジナル画像ファイルは i-a の `/path/to/images/` に保存され、MySQLには分割タイル画像のみBLOBとして保存される。

---

## 📦 その他のAWSリソース

### SQS
- **継続使用**: アプリケーションコード変更を避けるため維持
- **キュー**:
  - `kishax-to-mc-queue-v2` (WEB → MC)
  - `kishax-to-web-queue-v2` (MC → WEB)
  - `kishax-discord-queue-v2` (Discord Bot用)
- **管理**: Terraformで作成

### CloudFront
- **用途**: i-c（Web）へのWAF付きアクセス
- **オリジン**: i-cのパブリックIP（Elastic IP推奨）
- **キャッシュ**: 静的コンテンツのみ
- **管理**: Terraformで作成

### Route53
- **レコード**:
  - `mc.kishax.net` → i-a のパブリックIP（起動時自動更新）
  - `api.kishax.net` → i-b（内部アクセスまたはVPN経由）
  - `web.kishax.net` → CloudFront Distribution
- **管理**: Terraformで作成

### IAMロール
- **EC2インスタンス用**:
  - `kishax-ec2-mc-role` (i-a): Route53更新権限
  - `kishax-ec2-api-role` (i-b): SQS, RDS接続権限
  - `kishax-ec2-web-role` (i-c): SQS, RDS接続権限
  - `kishax-ec2-jump-role` (i-d): RDS接続権限のみ
- **詳細**: `docs/infrastructure/ec2/material-iam.md` 参照

---

## 🔒 セキュリティ構成

### セキュリティグループ

#### **i-a (MC Server)**
- **Inbound**:
  - `25565/tcp`: 0.0.0.0/0（Minecraftクライアント）
  - `22/tcp`: 管理用（特定IPのみ）
- **Outbound**:
  - `80/443/tcp`: インターネット（パッケージ更新）
  - `8080/tcp`: i-b へのHTTP通信
  - `3306/tcp`: RDS MySQL

#### **i-b (API)**
- **Inbound**:
  - `8080/tcp`: i-a, i-c のみ
  - `6379/tcp`: i-a, i-c（Redis）
  - `22/tcp`: 管理用（特定IPのみ）
- **Outbound**:
  - `5432/tcp`: RDS PostgreSQL
  - `443/tcp`: SQS, SSM

#### **i-c (Web + Discord)**
- **Inbound**:
  - `80/443/tcp`: CloudFrontのみ
  - `22/tcp`: 管理用（特定IPのみ）
- **Outbound**:
  - `8080/tcp`: i-b へのHTTP通信
  - `5432/tcp`: RDS PostgreSQL
  - `443/tcp`: Discord API, SQS, SSM

#### **i-d (Jump Server)**
- **Inbound**:
  - `22/tcp`: SSM Session Manager（インターネットゲートウェイ不要）
- **Outbound**:
  - `5432/tcp`: RDS PostgreSQL
  - `3306/tcp`: RDS MySQL

---

## 🌐 ネットワーク通信仕様

### EC2間通信
- **プロトコル**: HTTP
- **認証**: 内部APIキー（SSM Parameter Storeで管理）
- **暗号化**: TLS不要（VPC内通信）

### 外部通信
- **i-a → mc.kishax.net**: Elastic IP（固定IP）
- **i-c → web.kishax.net**: CloudFront経由（HTTPS必須）

---

## 🚀 技術スタック

### IaC
- **Terraform**: v1.5以上
- **管理リソース**:
  - EC2インスタンス（4台）
  - RDS（PostgreSQL, MySQL）
  - SQS キュー
  - CloudFront Distribution
  - Route53 レコード
  - セキュリティグループ
  - IAMロール/ポリシー
  - Elastic IP（i-a用）

### 構成管理
- **User Data**: EC2初期設定スクリプト
- **VM**: Docker Compose（各EC2内で使用）

---

## 📝 データ移行戦略

### Phase 1: 今回の実装（EC2移行）
```
旧環境（ECS/Fargate） → 新環境（EC2 + RDS PostgreSQL + RDS MySQL）
```
- CloudFormationスタック削除
- Terraformで新規作成
- RDS MySQL を新規作成（マイクラサーバー用）
- **画像ファイル**: i-a の `/path/to/images/` に保存
- **分割タイル画像**: MySQL BLOB として保存

### Phase 2: 画像のS3移行（将来・別PR）
```
1. S3バケット作成（ライフサイクルポリシー設定）
2. オリジナル画像を i-a → S3 に移行
3. アプリケーションコード更新（環境判定ロジック追加）
   - AWS環境フラグ: 環境変数 `STORAGE_MODE=s3` または `local`
   - ローカル開発: ファイルシステム使用
   - AWS本番: S3使用
4. 分割タイル画像も段階的にS3移行検討
```

**利点**:
- DBサイズ削減
- CloudFront連携で画像配信高速化
- 高可用性・耐久性

### Phase 3: MySQL → PostgreSQL統合（最終段階・別PR）
```
1. 画像データがS3移行済みであることを確認
2. MySQLスキーマをPostgreSQLに変換
3. データ移行スクリプト実行
4. Javaプラグインの接続設定変更
5. RDS MySQL削除
```

---

## 🛠️ 実装の進め方

### 1. 既存リソース削除
```bash
# CloudFormationスタック削除
aws cloudformation delete-stack \
  --stack-name kishax-infrastructure \
  --profile AdministratorAccess-126112056177
```

### 2. Terraform初期化
```bash
# ディレクトリ構成作成
mkdir -p terraform/{modules,environments/production}
```

### 3. リソース作成順序
1. VPC, サブネット（既存利用または新規）
2. セキュリティグループ
3. IAMロール/ポリシー
4. RDS PostgreSQL, MySQL
5. SQS キュー
6. EC2インスタンス（User Dataスクリプト含む）
7. Elastic IP（i-a用）
8. CloudFront Distribution
9. Route53 レコード

### 4. コミット方針
- **各リソース追加ごとに個別コミット**
- コミットメッセージは過去のGit履歴に基づく
- 例: `feat: VPCとサブネットのTerraform定義を追加`, `fix: セキュリティグループのルール修正`

---

## ⚠️ 注意事項・制約

### 環境変数（SSM Parameter Store）
- 実装中にSSM周りで停止する可能性あり → **相談必須**
- 既存のSSMパラメータを新環境用に整理

### MySQL画像データ
- 現時点では既存実装を維持（BLOB保存）
- S3移行は別PRで段階的に実施
- **AWS環境判定ロジック**: 環境変数で切り替え可能にする
  ```java
  String storageMode = System.getenv("STORAGE_MODE"); // "s3" or "local"
  if ("s3".equals(storageMode)) {
      // S3から読み込み
  } else {
      // ローカルファイルシステムから読み込み
  }
  ```

### 不明点があれば
- 実装途中で「わからない」と明示的に回答
- 推測で進めず、確認を取る

---

## 📊 コスト試算

| リソース | スペック | 月額コスト（USD） |
|---------|---------|-----------------|
| i-a (MC Server) | t3.large, 5h/day | $15 |
| i-b (API) | t3.small, 24h | $15 |
| i-c (Web) | t2.micro, 24h | $8 |
| i-d (Jump) | t2.micro, 2h/month | $0.5 |
| RDS PostgreSQL | db.t4g.micro | $12 |
| RDS MySQL | db.t4g.micro | $12 |
| SQS | 標準キュー | $1 |
| CloudFront | 少量トラフィック | $5 |
| Elastic IP | i-a用（稼働時） | $1 |
| **合計** | | **$69.5 (約¥10,000)** |

**注**: Phase 2（S3移行）でさらなるコスト削減可能（RDS MySQLストレージ削減）

---

## 📚 参考ドキュメント

- [next.md](./next.md): 新環境の要件定義
- [material-iam.md](./material-iam.md): IAMロール設定詳細
- 旧環境図: `infrastructure.png`

---

## ✅ 実装開始の承認

- [x] 要件確定
- [x] 相談事項解決
- [x] 実装方針決定
- [ ] 実装開始

**実装開始予定日**: 2025-12-12  
**担当**: AI + Human
