# Minecraft World S3 Backup Guide

**作成日**: 2025-12-31
**バージョン**: 1.0.0
**対象環境**: Production (ap-northeast-1)

---

## 📋 目次

1. [概要](#概要)
2. [バックアップの仕組み](#バックアップの仕組み)
3. [使い方](#使い方)
   - [バックアップ実行](#バックアップ実行)
   - [バックアップ一覧確認](#バックアップ一覧確認)
   - [バックアップから復元](#バックアップから復元)
   - [整合性確認](#整合性確認)
4. [高度な使い方](#高度な使い方)
5. [トラブルシューティング](#トラブルシューティング)
6. [運用ベストプラクティス](#運用ベストプラクティス)

---

## 概要

### 目的

Minecraftワールドデータを定期的にS3にバックアップし、障害やデータ破損時に復元できるようにします。

### 特徴

- ✅ **自動圧縮**: tar.gz形式で圧縮してストレージコスト削減
- ✅ **複数サーバー対応**: servers.jsonに基づいて全サーバーを自動バックアップ
- ✅ **メタデータ管理**: バックアップ日時・サイズ情報を記録
- ✅ **簡単復元**: Makefileコマンドで簡単に復元可能
- ✅ **ライフサイクル管理**: 180日経過後に自動削除（S3設定）

---

## バックアップの仕組み

### S3バケット構造

```
s3://kishax-production-world-backups/
└── backups/
    └── YYYYMMDD/              # バックアップ日付
        └── <server_name>/     # サーバー名 (例: home, latest)
            ├── world.tar.gz               # オーバーワールド (圧縮)
            ├── world_nether.tar.gz        # ネザー (圧縮)
            ├── world_the_end.tar.gz       # ジ・エンド (圧縮)
            ├── world_the_creative.tar.gz  # クリエイティブ (latestサーバーのみ)
            ├── metadata.json              # メタデータ
            └── __BACKUP_COMPLETED__       # バックアップ完了フラグ
```

**Note**: バックアップスクリプトは `world*` パターンのディレクトリを**動的に検出**します。
- 標準的なサーバー: `world`, `world_nether`, `world_the_end`
- latestサーバー: 上記3つ + `world_the_creative`
- 将来追加されるワールドも自動的にバックアップされます

### バックアップフロー

```
1. servers.json からアクティブサーバー一覧取得
   ↓
2. 各サーバーの world* ディレクトリを動的検出
   (例: world, world_nether, world_the_end, world_the_creative)
   ↓
3. 検出されたワールドを tar.gz 形式で圧縮 (圧縮レベル: デフォルト 6)
   ↓
4. S3 backups/YYYYMMDD/<server_name>/ にアップロード
   ↓
5. メタデータ JSON 作成
   ↓
6. バックアップ完了フラグ作成
```

### ライフサイクル

- **保存期間**: 180日
- **自動削除**: 180日経過後にS3ライフサイクルポリシーで自動削除
- **バージョニング**: 有効（誤削除時の復旧可能）

---

## 使い方

### 前提条件

#### EC2インスタンス (i-a) にSSH接続

```bash
# ローカルMacから実行

# 1. ターミナル1: ポートフォワーディング開始
cd /Users/tk/git/Kishax/infrastructure
make ssm-mc

# 2. ターミナル2: SSH接続
make ssh-mc
```

#### アプリケーションディレクトリに移動

```bash
# EC2 (i-a) 上で実行
cd /opt/mc  # または ~/infrastructure/apps/mc
```

---

### バックアップ実行

#### 全サーバーをバックアップ

```bash
make backup-world
```

**実行例**:
```
💾 ワールドデータをS3にバックアップします

=== 前提条件チェック ===
✅ 設定ファイル確認: /mc/config/servers.json
✅ jq インストール済み
✅ AWS CLI インストール済み
✅ S3バケットアクセス確認

=== 対象サーバー取得 ===
📋 対象サーバー数: 2
  - home
  - latest

バックアップを開始しますか？ (y/N): y

=== バックアップ: home ===
  検出されたワールド: world world_nether world_the_end
  📦 world: 圧縮中...
     サイズ: 1.2G
     ✅ 圧縮完了: 450M
  📦 world_nether: 圧縮中...
     サイズ: 320M
     ✅ 圧縮完了: 120M
  📦 world_the_end: 圧縮中...
     サイズ: 180M
     ✅ 圧縮完了: 65M
  📝 メタデータ作成中...
  ✅ メタデータ作成完了
  📤 S3アップロード中: s3://kishax-production-world-backups/backups/20251231/home/
  ✅ S3アップロード完了
  ✅ バックアップフラグ作成完了

=== バックアップ: latest ===
  検出されたワールド: world world_nether world_the_creative world_the_end
  📦 world: 圧縮中...
     サイズ: 1.5G
     ✅ 圧縮完了: 550M
  📦 world_nether: 圧縮中...
     サイズ: 280M
     ✅ 圧縮完了: 105M
  📦 world_the_creative: 圧縮中...
     サイズ: 890M
     ✅ 圧縮完了: 320M
  📦 world_the_end: 圧縮中...
     サイズ: 150M
     ✅ 圧縮完了: 55M
  📝 メタデータ作成中...
  ✅ メタデータ作成完了
  📤 S3アップロード中: s3://kishax-production-world-backups/backups/20251231/latest/
  ✅ S3アップロード完了
  ✅ バックアップフラグ作成完了

=== バックアップ結果 ===
✅ 成功: 2
❌ 失敗: 0

✅ バックアップが完了しました！

ℹ️  次のステップ:
1. S3の内容を確認:
   aws s3 ls s3://kishax-production-world-backups/backups/20251231/ --recursive --human-readable

2. バックアップから復元:
   make backup-world-restore DATE=20251231
```

#### 特定サーバーのみバックアップ

```bash
# Dockerコンテナ内で直接実行
docker exec -it kishax-minecraft /mc/scripts/backup-world-to-s3.sh --server home
```

#### ドライラン（実行内容確認）

```bash
# Dockerコンテナ内で直接実行
docker exec -it kishax-minecraft /mc/scripts/backup-world-to-s3.sh --dry-run
```

#### 圧縮レベル変更

```bash
# 最大圧縮（時間かかるが最小サイズ）
docker exec -it kishax-minecraft /mc/scripts/backup-world-to-s3.sh --compression 9

# 高速圧縮（大きめサイズ）
docker exec -it kishax-minecraft /mc/scripts/backup-world-to-s3.sh --compression 1
```

---

### バックアップ一覧確認

#### 最近20件のバックアップ日付を表示

```bash
make backup-world-list
```

**出力例**:
```
📋 S3ワールドバックアップ一覧

📦 S3 Bucket: kishax-production-world-backups
📂 Prefix: backups/

🔍 バックアップ日付一覧:
  📅 20251231
  📅 20251230
  📅 20251229
  📅 20251228
  ...

💡 詳細を確認するには:
   aws s3 ls s3://kishax-production-world-backups/backups/<YYYYMMDD>/ --recursive --human-readable
```

#### 特定日付の詳細確認

```bash
aws s3 ls s3://kishax-production-world-backups/backups/20251231/ --recursive --human-readable
```

**出力例**:
```
2025-12-31 12:34:56  450.0 MiB backups/20251231/home/world.tar.gz
2025-12-31 12:35:12  120.0 MiB backups/20251231/home/world_nether.tar.gz
2025-12-31 12:35:24   65.0 MiB backups/20251231/home/world_the_end.tar.gz
2025-12-31 12:35:30    1.2 KiB backups/20251231/home/metadata.json
2025-12-31 12:35:32       30 B backups/20251231/home/__BACKUP_COMPLETED__
```

---

### バックアップから復元

#### 基本的な復元

```bash
make backup-world-restore DATE=20251231
```

**実行例**:
```
♻️  S3バックアップから復元します

📦 S3 Bucket: kishax-production-world-backups
📅 バックアップ日付: 20251231

⚠️  警告: この操作は現在のワールドデータを上書きします！

続行しますか？ (yes/N): yes

📥 S3からバックアップをダウンロード中...

📂 対象サーバーを検出中...

📥 復元中: home
  📥 ダウンロード中: s3://kishax-production-world-backups/backups/20251231/home
  📦 展開中: world
    ✅ world 復元完了
  📦 展開中: world_nether
    ✅ world_nether 復元完了
  📦 展開中: world_the_end
    ✅ world_the_end 復元完了
  ✅ home 復元完了

✅ 全サーバーの復元が完了しました

💡 サーバーを再起動してください:
   make restart-all
```

#### 復元後のサーバー再起動

```bash
# 全サーバー再起動
make restart-all

# または個別再起動
make restart-home
make restart-latest
```

---

### 整合性確認

最新バックアップの整合性を確認します。

```bash
make backup-world-verify
```

**出力例**:
```
🔍 最新バックアップの整合性を確認します

📦 S3 Bucket: kishax-production-world-backups

🔍 最新バックアップを検索中...
📅 最新バックアップ日付: 20251231

📊 バックアップ内容:
  450.0 MiB backups/20251231/home/world.tar.gz
  120.0 MiB backups/20251231/home/world_nether.tar.gz
   65.0 MiB backups/20251231/home/world_the_end.tar.gz
    1.2 KiB backups/20251231/home/metadata.json
       30 B backups/20251231/home/__BACKUP_COMPLETED__

🔍 メタデータ確認:

  📂 home:
    ✅ world: 471859200 bytes
    ✅ world_nether: 125829120 bytes
    ✅ world_the_end: 68157440 bytes

✅ 整合性確認完了
```

---

## 高度な使い方

### cronで定期バックアップ設定

#### 毎日3:00にバックアップ

```bash
# EC2 (i-a) 上で実行
crontab -e

# 以下を追加
0 3 * * * cd /opt/mc && make backup-world >> /var/log/mc-backup.log 2>&1
```

#### ログローテーション設定

```bash
# /etc/logrotate.d/mc-backup を作成
sudo tee /etc/logrotate.d/mc-backup > /dev/null <<EOF
/var/log/mc-backup.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 0644 ec2-user ec2-user
}
EOF
```

### 手動でスクリプト実行

#### 全オプション確認

```bash
docker exec -it kishax-minecraft /mc/scripts/backup-world-to-s3.sh --help
```

#### 詳細な実行例

```bash
# homeサーバーのみ、最大圧縮、ドライラン
docker exec -it kishax-minecraft /mc/scripts/backup-world-to-s3.sh \
    --server home \
    --compression 9 \
    --dry-run
```

### S3から直接ダウンロード

```bash
# 特定日付のバックアップをローカルにダウンロード
aws s3 sync s3://kishax-production-world-backups/backups/20251231/ ./backup-20251231/ \
    --region ap-northeast-1 \
    --profile AdministratorAccess-126112056177
```

### メタデータJSON確認

```bash
# 特定サーバーのメタデータ表示
aws s3 cp s3://kishax-production-world-backups/backups/20251231/home/metadata.json - \
    --region ap-northeast-1 | jq .
```

**出力例**:
```json
{
  "server": "latest",
  "backup_date": "20251231",
  "timestamp": "2025-12-31T03:00:15Z",
  "compression_level": 6,
  "total_size_bytes": 1080374272,
  "worlds": [
    {
      "world": "world",
      "archive": "world.tar.gz",
      "size_bytes": 576716800
    },
    {
      "world": "world_nether",
      "archive": "world_nether.tar.gz",
      "size_bytes": 110100480
    },
    {
      "world": "world_the_creative",
      "archive": "world_the_creative.tar.gz",
      "size_bytes": 335544320
    },
    {
      "world": "world_the_end",
      "archive": "world_the_end.tar.gz",
      "size_bytes": 57671680
    }
  ]
}
```

**Note**: latestサーバーには `world_the_creative` が含まれています。動的検出により、将来追加されるワールド（例: `world_the_custom`）も自動的にバックアップされます。

---

## トラブルシューティング

### 問題1: バックアップが失敗する

**症状**: `❌ S3アップロード失敗`

**原因と対処法**:

#### 1. IAMロール権限不足

```bash
# EC2 (i-a) のIAMロールを確認
aws sts get-caller-identity

# 必要な権限:
# - s3:PutObject
# - s3:GetObject
# - s3:DeleteObject
# - s3:ListBucket
```

**解決策**: Terraform設定を確認してIAMロールに権限追加

```bash
cd /Users/tk/git/Kishax/infrastructure/terraform
terraform apply
```

#### 2. S3バケットが存在しない

```bash
# バケット確認
aws s3 ls s3://kishax-production-world-backups --region ap-northeast-1
```

**解決策**: Terraformでバケット作成

#### 3. ディスク容量不足

```bash
# ディスク容量確認
df -h
```

**解決策**: 一時ディレクトリ (`/tmp`) をクリーンアップ

```bash
sudo rm -rf /tmp/mc-backup-*
```

---

### 問題2: 復元が失敗する

**症状**: `❌ 指定された日付のバックアップが見つかりません`

**対処法**:

```bash
# バックアップ一覧確認
make backup-world-list

# S3を直接確認
aws s3 ls s3://kishax-production-world-backups/backups/ --region ap-northeast-1
```

---

### 問題3: 圧縮が遅い

**症状**: バックアップに30分以上かかる

**原因**: ワールドサイズが大きい、またはCPU使用率が高い

**対処法**:

#### 1. 圧縮レベルを下げる

```bash
# 圧縮レベル 3（バランス型）
docker exec -it kishax-minecraft /mc/scripts/backup-world-to-s3.sh --compression 3

# 圧縮レベル 1（高速）
docker exec -it kishax-minecraft /mc/scripts/backup-world-to-s3.sh --compression 1
```

#### 2. サーバー停止中にバックアップ

```bash
# サーバー停止
make restart-home  # または docker compose down

# バックアップ実行
make backup-world

# サーバー起動
make restart-all
```

---

### 問題4: メタデータが読めない

**症状**: `⚠️  メタデータ読み込み失敗`

**原因**: jq コマンドが見つからない

**対処法**:

```bash
# jq インストール確認
which jq

# インストールされていない場合
sudo yum install -y jq  # Amazon Linux 2
```

---

## 運用ベストプラクティス

### 1. 定期バックアップ

**推奨スケジュール**:
- **毎日**: 深夜3:00 (プレイヤーが少ない時間帯)
- **週次**: 日曜日に追加バックアップ

**cronジョブ設定**:
```bash
# 毎日 3:00
0 3 * * * cd /opt/mc && make backup-world >> /var/log/mc-backup.log 2>&1

# 日曜日 4:00（追加バックアップ）
0 4 * * 0 cd /opt/mc && make backup-world >> /var/log/mc-backup-weekly.log 2>&1
```

### 2. バックアップ確認

**毎週月曜日に先週のバックアップを確認**:

```bash
# 最新バックアップ確認
make backup-world-verify

# 先週のバックアップ一覧
make backup-world-list
```

### 3. 復元テスト

**月に1回、復元テストを実施**:

```bash
# テスト用サーバーで復元テスト
# (本番サーバーには影響しない別のEC2インスタンス)

make backup-world-restore DATE=<最新日付>
make restart-all
```

### 4. コスト管理

#### S3ストレージコスト確認

```bash
# バケット合計サイズ
aws s3 ls s3://kishax-production-world-backups/backups/ --recursive --summarize --human-readable | tail -2
```

**コスト目安**:
- S3 Standard: $0.025/GB/月 (東京リージョン)
- 1TB保存: 約$25/月
- 180日自動削除で上限あり

#### 古いバックアップ手動削除

```bash
# 90日以前のバックアップ削除（手動）
aws s3 rm s3://kishax-production-world-backups/backups/20240101/ --recursive --region ap-northeast-1
```

### 5. 障害対応手順

#### 障害発生時の復旧フロー

```
1. サーバー停止
   make restart-all (全サーバー停止)
   ↓
2. 最新バックアップ確認
   make backup-world-verify
   ↓
3. バックアップから復元
   make backup-world-restore DATE=<日付>
   ↓
4. サーバー再起動
   make restart-all
   ↓
5. 動作確認
   make mc-home (コンソールで確認)
```

---

## 参考情報

### 関連ドキュメント

- [deployment.md](./deployment.md) - EC2デプロイメント手順
- [upload-world-data-guide.md](./upload-world-data-guide.md) - 初回デプロイ時のワールドアップロード
- [s3-features-summary.md](./s3-features-summary.md) - S3機能全体概要

### 関連ファイル

| ファイル | 説明 |
|---------|------|
| [apps/mc/docker/scripts/backup-world-to-s3.sh](../../apps/mc/docker/scripts/backup-world-to-s3.sh) | バックアップスクリプト本体 |
| [apps/mc/Makefile](../../apps/mc/Makefile) | Makefileコマンド定義 |
| [terraform/modules/s3/main.tf](../../terraform/modules/s3/main.tf) | S3バケット設定 |

### S3バケット情報

- **バケット名**: `kishax-production-world-backups`
- **リージョン**: ap-northeast-1 (東京)
- **暗号化**: AES256 (自動)
- **バージョニング**: 有効
- **ライフサイクル**: backups/ は180日で削除

---

**最終更新**: 2025-12-31
**作成者**: Claude Sonnet 4.5
**バージョン**: 1.0.0
