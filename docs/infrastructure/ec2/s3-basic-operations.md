# AWS S3 基本操作ガイド

## 概要

このドキュメントでは、AWS S3バケット（特に`kishax-production-world-backups`）に対する基本的な操作方法をまとめます。

## 前提条件

### AWS CLI のインストール確認
```bash
aws --version
# aws-cli/2.x.x Python/3.x.x Darwin/24.6.0 botocore/2.x.x
```

### 認証情報の設定
```bash
# SSO ログイン
aws sso login --profile AdministratorAccess-126112056177

# プロファイル確認
aws sts get-caller-identity --profile AdministratorAccess-126112056177
```

### 環境変数の設定（オプション）
```bash
# プロファイルを環境変数で設定（毎回 --profile を指定する必要がなくなる）
export AWS_PROFILE=AdministratorAccess-126112056177
export AWS_REGION=ap-northeast-1

# 確認
echo $AWS_PROFILE
```

---

## 1. バケット一覧の確認

### 全バケットの一覧表示
```bash
aws s3 ls

# 出力例:
# 2024-12-01 10:00:00 kishax-production-docker-images
# 2024-12-01 10:00:00 kishax-production-image-maps
# 2024-12-15 10:00:00 kishax-production-world-backups
```

### 特定バケットの内容確認
```bash
# バケットのトップレベルを表示
aws s3 ls s3://kishax-production-world-backups/

# 出力例:
#                            PRE backups/
#                            PRE deployment/
#                            PRE migration/
```

---

## 2. ディレクトリ（プレフィックス）操作

> **注意**: S3には実際の「ディレクトリ」という概念はありません。  
> `/` で区切られた文字列（プレフィックス）でディレクトリ構造を模倣しています。

### 2.1 ディレクトリの作成

S3では、ディレクトリは自動的に作成されます（ファイルをアップロードすると自動的にプレフィックスが作られます）。

#### 方法1: 空のマーカーファイルを作成（明示的にディレクトリを作る場合）
```bash
# 空ファイルを作成してアップロード
touch .keep
aws s3 cp .keep s3://kishax-production-world-backups/backups/20241215/.keep
rm .keep

# または、一行で
echo "" | aws s3 cp - s3://kishax-production-world-backups/backups/20241215/.keep
```

#### 方法2: ファイルをアップロードする（プレフィックスは自動作成）
```bash
# ファイルをアップロード（backups/20241215/ が自動作成される）
aws s3 cp world.tar.gz s3://kishax-production-world-backups/backups/20241215/world.tar.gz
```

### 2.2 ディレクトリ内の一覧表示

```bash
# トップレベルのディレクトリ一覧
aws s3 ls s3://kishax-production-world-backups/

# 特定ディレクトリの内容
aws s3 ls s3://kishax-production-world-backups/backups/

# 深い階層の表示
aws s3 ls s3://kishax-production-world-backups/backups/20241215/

# 再帰的に全ファイルを表示
aws s3 ls s3://kishax-production-world-backups/backups/ --recursive

# 人間が読みやすい形式で表示
aws s3 ls s3://kishax-production-world-backups/backups/ --recursive --human-readable

# サマリー付きで表示
aws s3 ls s3://kishax-production-world-backups/backups/ --recursive --summarize --human-readable

# 出力例:
# Total Objects: 1234
# Total Size: 5.2 GB
```

---

## 3. ファイル操作

### 3.1 単一ファイルのアップロード（cp）

```bash
# 基本的なアップロード
aws s3 cp <ローカルファイル> s3://kishax-production-world-backups/<パス>

# 実例: バックアップファイルをアップロード
aws s3 cp ./world-backup.tar.gz s3://kishax-production-world-backups/backups/20241215/world-backup.tar.gz

# 進捗を表示
aws s3 cp ./world-backup.tar.gz s3://kishax-production-world-backups/backups/20241215/world-backup.tar.gz \
  --no-progress=false

# メタデータを付与してアップロード
aws s3 cp ./world-backup.tar.gz s3://kishax-production-world-backups/backups/20241215/world-backup.tar.gz \
  --metadata "server=latest,date=20241215,version=1"

# ストレージクラスを指定（Glacier等）
aws s3 cp ./old-backup.tar.gz s3://kishax-production-world-backups/migration/old-backup.tar.gz \
  --storage-class GLACIER
```

### 3.2 ディレクトリ全体のアップロード（sync）

```bash
# ローカルディレクトリをS3にアップロード
aws s3 sync <ローカルディレクトリ> s3://kishax-production-world-backups/<パス>

# 実例: ワールドデータ全体をアップロード
aws s3 sync ./world/ s3://kishax-production-world-backups/deployment/202512/1/latest/world/

# ドライラン（実際にはアップロードせず、何が実行されるか確認）
aws s3 sync ./world/ s3://kishax-production-world-backups/deployment/202512/1/latest/world/ --dryrun

# 削除を含めた完全同期（S3にあってローカルにないファイルは削除）
aws s3 sync ./world/ s3://kishax-production-world-backups/deployment/202512/1/latest/world/ --delete

# 特定の拡張子のみアップロード
aws s3 sync ./world/ s3://kishax-production-world-backups/deployment/202512/1/latest/world/ \
  --exclude "*" --include "*.mca"

# 特定のファイルを除外
aws s3 sync ./world/ s3://kishax-production-world-backups/deployment/202512/1/latest/world/ \
  --exclude "*.log" --exclude "*.tmp"
```

### 3.3 複数ディレクトリのアップロード（一括）

```bash
# ワールドデータ3種類を一括アップロード
aws s3 sync ./world/ s3://kishax-production-world-backups/deployment/202512/1/latest/world/
aws s3 sync ./world_nether/ s3://kishax-production-world-backups/deployment/202512/1/latest/world_nether/
aws s3 sync ./world_the_end/ s3://kishax-production-world-backups/deployment/202512/1/latest/world_the_end/

# 並列実行で高速化（別ターミナルで実行）
aws s3 sync ./world/ s3://kishax-production-world-backups/deployment/202512/1/latest/world/ &
aws s3 sync ./world_nether/ s3://kishax-production-world-backups/deployment/202512/1/latest/world_nether/ &
aws s3 sync ./world_the_end/ s3://kishax-production-world-backups/deployment/202512/1/latest/world_the_end/ &
wait
```

---

## 4. ファイルのダウンロード

### 4.1 単一ファイルのダウンロード（cp）

```bash
# S3からローカルへダウンロード
aws s3 cp s3://kishax-production-world-backups/<パス> <ローカルファイル>

# 実例
aws s3 cp s3://kishax-production-world-backups/backups/20241215/world-backup.tar.gz ./world-backup.tar.gz

# 標準出力に出力
aws s3 cp s3://kishax-production-world-backups/deployment/202512/1/latest/__IMPORT_ENABLED__ -
```

### 4.2 ディレクトリ全体のダウンロード（sync）

```bash
# S3からローカルへディレクトリをダウンロード
aws s3 sync s3://kishax-production-world-backups/<パス> <ローカルディレクトリ>

# 実例: ワールドデータをダウンロード
aws s3 sync s3://kishax-production-world-backups/deployment/202512/1/latest/world/ ./world/

# 進捗を表示
aws s3 sync s3://kishax-production-world-backups/deployment/202512/1/latest/world/ ./world/ \
  --no-progress=false

# 削除を含めた完全同期
aws s3 sync s3://kishax-production-world-backups/deployment/202512/1/latest/world/ ./world/ --delete
```

---

## 5. ファイル・ディレクトリの削除

### 5.1 単一ファイルの削除（rm）

```bash
# ファイルを削除
aws s3 rm s3://kishax-production-world-backups/<パス>

# 実例
aws s3 rm s3://kishax-production-world-backups/migration/old-backup.tar.gz
```

### 5.2 ディレクトリ全体の削除（rm --recursive）

```bash
# ディレクトリを再帰的に削除
aws s3 rm s3://kishax-production-world-backups/<パス>/ --recursive

# 実例: 古い移行作業データを削除
aws s3 rm s3://kishax-production-world-backups/migration/202401/ --recursive

# ドライラン（実際には削除しない）
aws s3 rm s3://kishax-production-world-backups/migration/202401/ --recursive --dryrun
```

### 5.3 特定のファイルパターンのみ削除

```bash
# 特定の拡張子のみ削除
aws s3 rm s3://kishax-production-world-backups/backups/20241215/ --recursive --exclude "*" --include "*.log"

# 古いバックアップのみ削除（日付フィルタ）
aws s3 rm s3://kishax-production-world-backups/backups/202401/ --recursive
aws s3 rm s3://kishax-production-world-backups/backups/202402/ --recursive
```

---

## 6. ファイル・ディレクトリの移動・コピー

### 6.1 S3内でのコピー

```bash
# S3内でファイルをコピー
aws s3 cp s3://kishax-production-world-backups/source/file.tar.gz \
          s3://kishax-production-world-backups/destination/file.tar.gz

# S3内でディレクトリをコピー
aws s3 cp s3://kishax-production-world-backups/source/ \
          s3://kishax-production-world-backups/destination/ --recursive

# 実例: deployment から backups へコピー
aws s3 cp s3://kishax-production-world-backups/deployment/202512/1/latest/ \
          s3://kishax-production-world-backups/backups/20241215/latest/ --recursive
```

### 6.2 S3内での移動（コピー + 削除）

```bash
# 移動（mv）
aws s3 mv s3://kishax-production-world-backups/source/file.tar.gz \
          s3://kishax-production-world-backups/destination/file.tar.gz

# ディレクトリを移動
aws s3 mv s3://kishax-production-world-backups/source/ \
          s3://kishax-production-world-backups/destination/ --recursive

# 実例: migration から backups へ移動
aws s3 mv s3://kishax-production-world-backups/migration/202512/ \
          s3://kishax-production-world-backups/backups/202512/ --recursive
```

### 6.3 バケット間でのコピー

```bash
# 別バケットへコピー
aws s3 cp s3://kishax-production-world-backups/deployment/202512/1/latest/world/ \
          s3://other-bucket/world/ --recursive

# sync で同期
aws s3 sync s3://kishax-production-world-backups/deployment/202512/1/latest/world/ \
            s3://other-bucket/world/
```

---

## 7. 詳細情報の確認

### 7.1 ファイル情報の取得

```bash
# ファイルの詳細情報を表示
aws s3api head-object \
  --bucket kishax-production-world-backups \
  --key deployment/202512/1/latest/world/level.dat

# 出力例:
# {
#     "AcceptRanges": "bytes",
#     "LastModified": "2024-12-15T10:00:00+00:00",
#     "ContentLength": 123456,
#     "ETag": "\"abc123def456\"",
#     "ContentType": "application/octet-stream",
#     "ServerSideEncryption": "AES256",
#     "Metadata": {}
# }
```

### 7.2 バケットのサイズ確認

```bash
# バケット全体のサイズ
aws s3 ls s3://kishax-production-world-backups/ --recursive --summarize --human-readable

# 特定ディレクトリのサイズ
aws s3 ls s3://kishax-production-world-backups/backups/ --recursive --summarize --human-readable

# ファイル数のみカウント
aws s3 ls s3://kishax-production-world-backups/backups/ --recursive | wc -l
```

### 7.3 ファイルの存在確認

```bash
# ファイルが存在するか確認
aws s3 ls s3://kishax-production-world-backups/deployment/202512/1/latest/__IMPORT_ENABLED__

# 存在すれば詳細表示、なければエラー
if aws s3 ls s3://kishax-production-world-backups/deployment/202512/1/latest/__IMPORT_ENABLED__; then
  echo "ファイルが存在します"
else
  echo "ファイルが存在しません"
fi
```

---

## 8. 高度な操作

### 8.1 並列アップロード設定

```bash
# AWS CLI の並列アップロード設定
aws configure set default.s3.max_concurrent_requests 20
aws configure set default.s3.max_bandwidth 50MB/s

# 確認
aws configure get default.s3.max_concurrent_requests
```

### 8.2 マルチパートアップロード設定

```bash
# 大きいファイル用の設定
aws configure set default.s3.multipart_threshold 64MB
aws configure set default.s3.multipart_chunksize 16MB

# 100MB以上のファイルに適用
aws s3 cp large-world-backup.tar.gz s3://kishax-production-world-backups/backups/20241215/
```

### 8.3 署名付きURL生成（一時的なダウンロードリンク）

```bash
# 1時間有効な署名付きURLを生成
aws s3 presign s3://kishax-production-world-backups/backups/20241215/world-backup.tar.gz \
  --expires-in 3600

# 出力例:
# https://kishax-production-world-backups.s3.ap-northeast-1.amazonaws.com/backups/...?X-Amz-...
```

### 8.4 タグの管理

```bash
# タグを追加
aws s3api put-object-tagging \
  --bucket kishax-production-world-backups \
  --key deployment/202512/1/latest/world.tar.gz \
  --tagging 'TagSet=[{Key=Environment,Value=production},{Key=Server,Value=latest}]'

# タグを取得
aws s3api get-object-tagging \
  --bucket kishax-production-world-backups \
  --key deployment/202512/1/latest/world.tar.gz
```

---

## 9. 実践例

### 9.1 ワールドデータのバックアップ（完全版）

```bash
#!/bin/bash
# world-backup.sh

# 設定
BUCKET="kishax-production-world-backups"
DATE=$(date +%Y%m%d)
VERSION="1"
SERVER_NAME="latest"
LOCAL_WORLD_DIR="/opt/mc/spigot/${SERVER_NAME}"

# バックアップ先
S3_PREFIX="backups/${DATE:0:6}/${VERSION}/${SERVER_NAME}"

echo "=== Minecraft World Backup ==="
echo "Date: $DATE"
echo "Server: $SERVER_NAME"
echo "S3: s3://${BUCKET}/${S3_PREFIX}/"
echo ""

# 1. ワールドデータをアップロード
echo "📦 Uploading world data..."
aws s3 sync "${LOCAL_WORLD_DIR}/world/" "s3://${BUCKET}/${S3_PREFIX}/world/" --delete
aws s3 sync "${LOCAL_WORLD_DIR}/world_nether/" "s3://${BUCKET}/${S3_PREFIX}/world_nether/" --delete
aws s3 sync "${LOCAL_WORLD_DIR}/world_the_end/" "s3://${BUCKET}/${S3_PREFIX}/world_the_end/" --delete

# 2. メタデータファイルを作成
echo "📝 Creating metadata..."
cat > /tmp/backup-metadata.json <<EOF
{
  "date": "$DATE",
  "server": "$SERVER_NAME",
  "version": "$VERSION",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

aws s3 cp /tmp/backup-metadata.json "s3://${BUCKET}/${S3_PREFIX}/metadata.json"
rm /tmp/backup-metadata.json

# 3. 完了フラグを作成
echo "✅ Creating completion flag..."
echo "Backup completed at $(date)" | aws s3 cp - "s3://${BUCKET}/${S3_PREFIX}/__BACKUP_COMPLETED__"

# 4. 結果確認
echo ""
echo "✨ Backup completed!"
aws s3 ls "s3://${BUCKET}/${S3_PREFIX}/" --recursive --summarize --human-readable
```

### 9.2 ワールドデータのリストア

```bash
#!/bin/bash
# world-restore.sh

BUCKET="kishax-production-world-backups"
BACKUP_DATE="20241215"
SERVER_NAME="latest"
LOCAL_WORLD_DIR="/opt/mc/spigot/${SERVER_NAME}"

S3_PREFIX="backups/${BACKUP_DATE:0:6}/1/${SERVER_NAME}"

echo "=== Minecraft World Restore ==="
echo "Backup Date: $BACKUP_DATE"
echo "Server: $SERVER_NAME"
echo ""

# 確認
read -p "⚠️  既存のワールドデータは上書きされます。続行しますか？ (y/N): " answer
if [ "$answer" != "y" ] && [ "$answer" != "Y" ]; then
  echo "キャンセルしました"
  exit 0
fi

# ダウンロード
echo "📥 Downloading world data from S3..."
aws s3 sync "s3://${BUCKET}/${S3_PREFIX}/world/" "${LOCAL_WORLD_DIR}/world/" --delete
aws s3 sync "s3://${BUCKET}/${S3_PREFIX}/world_nether/" "${LOCAL_WORLD_DIR}/world_nether/" --delete
aws s3 sync "s3://${BUCKET}/${S3_PREFIX}/world_the_end/" "${LOCAL_WORLD_DIR}/world_the_end/" --delete

echo "✨ Restore completed!"
```

### 9.3 古いバックアップの自動削除

```bash
#!/bin/bash
# cleanup-old-backups.sh

BUCKET="kishax-production-world-backups"
DAYS_TO_KEEP=180

echo "=== Cleanup Old Backups ==="
echo "Keeping backups from the last ${DAYS_TO_KEEP} days"
echo ""

# 削除対象の日付を計算（180日前）
CUTOFF_DATE=$(date -v-${DAYS_TO_KEEP}d +%Y%m%d)
echo "Deleting backups older than: $CUTOFF_DATE"
echo ""

# backups/ 配下の YYYYMM ディレクトリを列挙
aws s3 ls "s3://${BUCKET}/backups/" | awk '{print $2}' | while read -r month_dir; do
  # YYYYMM 形式
  month="${month_dir%/}"
  
  # 削除対象かチェック（YYYYMMが古い場合）
  if [ "$month" -lt "${CUTOFF_DATE:0:6}" ]; then
    echo "🗑️  Deleting: backups/$month/"
    aws s3 rm "s3://${BUCKET}/backups/${month}/" --recursive
  else
    echo "✅ Keeping: backups/$month/"
  fi
done

echo ""
echo "✨ Cleanup completed!"
```

---

## 10. トラブルシューティング

### 10.1 アップロード失敗

```bash
# エラー詳細を表示
aws s3 cp ./file.tar.gz s3://kishax-production-world-backups/test/ --debug

# タイムアウトを延長
aws configure set default.s3.max_attempts 10
aws s3 cp ./large-file.tar.gz s3://kishax-production-world-backups/test/
```

### 10.2 権限エラー

```bash
# 現在のIAM権限を確認
aws sts get-caller-identity

# バケットポリシーを確認
aws s3api get-bucket-policy --bucket kishax-production-world-backups

# IAMロールの権限を確認
aws iam get-role-policy --role-name kishax-production-ec2-role --policy-name S3Access
```

### 10.3 同期が遅い場合

```bash
# 並列数を増やす
aws configure set default.s3.max_concurrent_requests 50

# 帯域制限を解除
aws configure set default.s3.max_bandwidth 0

# 再実行
aws s3 sync ./world/ s3://kishax-production-world-backups/deployment/202512/1/latest/world/
```

---

## 11. ベストプラクティス

### 11.1 アップロード前の確認

```bash
# 必ず --dryrun でテスト
aws s3 sync ./world/ s3://kishax-production-world-backups/deployment/202512/1/latest/world/ --dryrun

# 問題なければ実行
aws s3 sync ./world/ s3://kishax-production-world-backups/deployment/202512/1/latest/world/
```

### 11.2 削除前の確認

```bash
# 削除対象を確認
aws s3 ls s3://kishax-production-world-backups/migration/202401/ --recursive

# ファイル数を確認
aws s3 ls s3://kishax-production-world-backups/migration/202401/ --recursive | wc -l

# 削除
aws s3 rm s3://kishax-production-world-backups/migration/202401/ --recursive
```

### 11.3 バックアップの世代管理

```bash
# deployment/ → 常に最新（1世代のみ）
# backups/YYYYMM/ → 月次バックアップ（180日保持）
# migration/ → 移行作業用（90日保持、手動削除）

# ディレクトリ構造の例:
# s3://kishax-production-world-backups/
# ├── deployment/
# │   └── 202512/
# │       └── 1/
# │           └── latest/
# ├── backups/
# │   ├── 202410/
# │   ├── 202411/
# │   └── 202412/
# └── migration/
#     └── 202412/
```

---

## 12. よく使うコマンド一覧

```bash
# 一覧表示
aws s3 ls s3://kishax-production-world-backups/
aws s3 ls s3://kishax-production-world-backups/backups/ --recursive

# アップロード
aws s3 cp file.tar.gz s3://kishax-production-world-backups/backups/20241215/
aws s3 sync ./world/ s3://kishax-production-world-backups/deployment/202512/1/latest/world/

# ダウンロード
aws s3 cp s3://kishax-production-world-backups/backups/20241215/file.tar.gz ./
aws s3 sync s3://kishax-production-world-backups/deployment/202512/1/latest/world/ ./world/

# 削除
aws s3 rm s3://kishax-production-world-backups/migration/old-file.tar.gz
aws s3 rm s3://kishax-production-world-backups/migration/202401/ --recursive

# コピー・移動
aws s3 cp s3://kishax-production-world-backups/source/ s3://kishax-production-world-backups/dest/ --recursive
aws s3 mv s3://kishax-production-world-backups/source/ s3://kishax-production-world-backups/dest/ --recursive

# サイズ確認
aws s3 ls s3://kishax-production-world-backups/backups/ --recursive --summarize --human-readable
```

---

## 関連ドキュメント

- [S3統合機能サマリー](./s3-features-summary.md)
- [S3ワールドデータインポートシステム](../../apps/mc/docker/docs/S3_WORLD_IMPORT.md)
- [Terraform: S3バケット設定](../../../terraform/modules/s3/main.tf)
