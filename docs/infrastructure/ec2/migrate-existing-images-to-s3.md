# 既存画像マップのS3移行ガイド

## 概要

ローカルファイルシステムに保存されている既存の画像マップをS3バケットに移行するための手順書です。

## 前提条件

- ✅ S3画像ストレージ機能の実装が完了していること
- ✅ MySQL設定（`s3_image_storage_settings.sql`）がインポート済みであること
- ✅ IAM権限（S3アクセス）が設定されていること
- ✅ 既存画像が`/opt/mc/spigot/world/data/images/YYYYMMDD/[UUID].ext`形式で保存されていること

## 移行戦略

2つのアプローチがあります：

### オプション1: AWS CLI を使用した一括移行（推奨）
- **メリット**: 高速、シンプル、バッチ処理可能
- **デメリット**: ディレクトリ構造を手動で確認する必要がある
- **推奨**: 大量の画像（100枚以上）がある場合

### オプション2: スクリプトを使用した選択的移行
- **メリット**: MySQLの`images`テーブルと整合性を取りながら移行可能
- **デメリット**: 実装が複雑
- **推奨**: データベースとの整合性を厳密に保ちたい場合

---

## オプション1: AWS CLI を使用した一括移行（推奨）

### ステップ1: 既存画像の確認

**i-a (MC Server) にSSM接続**:
```bash
# ローカルマシンから
cd /Users/tk/git/Kishax/infrastructure/terraform
export INSTANCE_ID_A=$(terraform output -raw mc_server_instance_id)

aws ssm start-session \
  --target $INSTANCE_ID_A \
  --profile AdministratorAccess-126112056177
```

**i-a上で既存画像を確認**:
```bash
# 画像ディレクトリの場所を確認
IMAGE_DIR="/opt/mc/spigot/world/data/images"

# ディレクトリ構造を確認
ls -lh $IMAGE_DIR/

# 日付ディレクトリ一覧
ls -1 $IMAGE_DIR/

# 画像の総数を確認
find $IMAGE_DIR -type f \( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" \) | wc -l

# 各日付ごとの画像数を確認
for dir in $IMAGE_DIR/*/; do
  echo "$(basename $dir): $(find $dir -type f | wc -l) files"
done

# 総ファイルサイズを確認
du -sh $IMAGE_DIR
```

### ステップ2: S3バケット情報を確認

**i-a上で実行**:
```bash
# S3バケット名を環境変数から取得（.envファイルがある場合）
cd /opt/mc
cat .env | grep S3_BUCKET

# または直接指定（画像マップ専用バケット）
export S3_BUCKET="kishax-production-image-maps"
export S3_PREFIX="images/"

# S3バケットが存在するか確認
aws s3 ls s3://$S3_BUCKET/

# 既存のimagesディレクトリを確認
aws s3 ls s3://$S3_BUCKET/$S3_PREFIX
```

### ステップ3: 一括アップロード（ドライラン）

**i-a上で実行**:
```bash
# ドライラン（実際にはアップロードしない）
aws s3 sync $IMAGE_DIR/ s3://$S3_BUCKET/$S3_PREFIX --dryrun

# 出力例:
# (dryrun) upload: 20241201/abc123.png to s3://kishax-production-image-maps/images/20241201/abc123.png
# (dryrun) upload: 20241202/def456.png to s3://kishax-production-image-maps/images/20241202/def456.png
```

### ステップ4: 一括アップロード（本番実行）

**i-a上で実行**:
```bash
# 実際にアップロード
aws s3 sync $IMAGE_DIR/ s3://$S3_BUCKET/$S3_PREFIX

# 進捗を表示しながらアップロード
aws s3 sync $IMAGE_DIR/ s3://$S3_BUCKET/$S3_PREFIX --no-progress=false

# 完了メッセージが表示されるまで待つ
```

**オプション: 並列アップロードで高速化**:
```bash
# 大量の小さいファイルがある場合、並列数を増やして高速化
aws configure set default.s3.max_concurrent_requests 20

# 再度同期
aws s3 sync $IMAGE_DIR/ s3://$S3_BUCKET/$S3_PREFIX
```

### ステップ5: アップロード結果の確認

**i-a上で実行**:
```bash
# S3にアップロードされたファイル数を確認
aws s3 ls s3://$S3_BUCKET/$S3_PREFIX --recursive | wc -l

# ローカルのファイル数と比較
find $IMAGE_DIR -type f | wc -l

# 特定の日付のファイルを確認
aws s3 ls s3://$S3_BUCKET/$S3_PREFIX20241215/

# ファイルサイズの確認
aws s3 ls s3://$S3_BUCKET/$S3_PREFIX --recursive --human-readable --summarize
```

### ステップ6: S3モードに切り替え

**ローカルマシンから（MySQLポートフォワーディング経由）**:

**ターミナル1（ポートフォワーディング）**:
```bash
cd /Users/tk/git/Kishax/infrastructure/terraform
export INSTANCE_ID_D=$(terraform output -raw jump_server_instance_id)
export RDS_MYSQL_ENDPOINT=$(terraform output -raw mysql_endpoint)
export RDS_MYSQL_HOST=$(echo $RDS_MYSQL_ENDPOINT | cut -d':' -f1)
export RDS_MYSQL_PORT=$(echo $RDS_MYSQL_ENDPOINT | cut -d':' -f2)

aws ssm start-session \
  --target $INSTANCE_ID_D \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters "{\"host\":[\"$RDS_MYSQL_HOST\"],\"portNumber\":[\"$RDS_MYSQL_PORT\"],\"localPortNumber\":[\"3306\"]}" \
  --profile AdministratorAccess-126112056177
```

**ターミナル2（MySQL設定変更）**:
```bash
# MySQL接続情報
export MYSQL_HOST=localhost
export MYSQL_PORT=3306
export MYSQL_USER=admin
export MYSQL_PASSWORD='<terraform.tfvarsのmysql_passwordの値>'
export MYSQL_DATABASE=kishax_mc

# S3モードに切り替え
mysql -h $MYSQL_HOST -P $MYSQL_PORT -u $MYSQL_USER -p"$MYSQL_PASSWORD" $MYSQL_DATABASE -e "
UPDATE settings 
SET value = 's3' 
WHERE name = 'IMAGE_STORAGE_MODE';
"

# 設定確認
mysql -h $MYSQL_HOST -P $MYSQL_PORT -u $MYSQL_USER -p"$MYSQL_PASSWORD" $MYSQL_DATABASE -e "
SELECT name, value FROM settings WHERE name = 'IMAGE_STORAGE_MODE';
"
```

### ステップ7: Minecraftサーバーを再起動

**i-aにSSM接続して実行**:
```bash
cd /opt/mc

# コンテナ再起動
docker compose restart

# ログでS3モード起動を確認
docker compose logs -f | grep -i "s3\|storage"

# 以下のようなログが表示されれば成功:
# ImageStorageManager initialized with S3 storage (bucket: kishax-production-image-maps, prefix: images/)
# S3Client initialized with Instance Profile (region: ap-northeast-1)
```

### ステップ8: 動作確認

**Minecraftサーバーで確認**:
```bash
# 1. Minecraftにログイン
# 2. 既存の画像マップを額縁に設置して表示されるか確認
# 3. 新しい画像マップを作成してS3に保存されるか確認
```

**S3で確認（i-a上）**:
```bash
# 新しく作成した画像が今日の日付で保存されているか確認
TODAY=$(date +%Y%m%d)
aws s3 ls s3://$S3_BUCKET/$S3_PREFIX$TODAY/
```

**ローカルキャッシュで確認（i-a上）**:
```bash
# 既存画像を読み込んだ際、キャッシュに保存されているか確認
ls -lah /opt/mc/cache/images/
```

### ステップ9: ローカル画像のバックアップと削除（オプション）

**⚠️ 重要**: S3移行が完全に成功し、動作確認が完了してから実行してください。

**i-a上で実行**:
```bash
# バックアップを作成
tar -czf /tmp/images_backup_$(date +%Y%m%d).tar.gz $IMAGE_DIR

# バックアップをS3にアップロード
aws s3 cp /tmp/images_backup_$(date +%Y%m%d).tar.gz s3://$S3_BUCKET/backups/

# バックアップ確認
aws s3 ls s3://$S3_BUCKET/backups/

# ローカル画像を削除（慎重に！）
# rm -rf $IMAGE_DIR/*

# または、古い画像だけ削除（例: 30日以上前）
# find $IMAGE_DIR -type f -mtime +30 -delete
```

---

## オプション2: スクリプトを使用した選択的移行

MySQLの`images`テーブルと整合性を取りながら移行する場合は、このスクリプトを使用します。

### 移行スクリプトの作成

**i-a上で作成**:
```bash
cd /opt/mc
cat > migrate_images_to_s3.sh << 'EOF'
#!/bin/bash
set -e

# 設定
IMAGE_DIR="/opt/mc/spigot/world/data/images"
S3_BUCKET="kishax-production-image-maps"
S3_PREFIX="images/"
MYSQL_HOST="<RDS_MYSQL_HOST>"
MYSQL_PORT="3306"
MYSQL_USER="admin"
MYSQL_PASSWORD="<MYSQL_PASSWORD>"
MYSQL_DATABASE="kishax_mc"

# カラーコード
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== 既存画像マップのS3移行スクリプト ===${NC}"
echo ""

# MySQLから画像情報を取得
echo -e "${YELLOW}MySQLから画像情報を取得中...${NC}"
IMAGES=$(mysql -h $MYSQL_HOST -P $MYSQL_PORT -u $MYSQL_USER -p"$MYSQL_PASSWORD" $MYSQL_DATABASE -N -e "
SELECT imuuid, ext, DATE_FORMAT(date, '%Y%m%d') as date_str
FROM images
WHERE imuuid IS NOT NULL AND ext IS NOT NULL
ORDER BY date;
")

if [ -z "$IMAGES" ]; then
    echo -e "${RED}画像情報が見つかりませんでした。${NC}"
    exit 1
fi

# 統計情報
TOTAL_COUNT=$(echo "$IMAGES" | wc -l)
SUCCESS_COUNT=0
SKIP_COUNT=0
ERROR_COUNT=0

echo -e "${GREEN}移行対象: ${TOTAL_COUNT}枚${NC}"
echo ""

# 各画像を処理
while IFS=$'\t' read -r UUID EXT DATE_STR; do
    LOCAL_PATH="${IMAGE_DIR}/${DATE_STR}/${UUID}.${EXT}"
    S3_KEY="${S3_PREFIX}${DATE_STR}/${UUID}.${EXT}"
    
    # ローカルファイルの存在確認
    if [ ! -f "$LOCAL_PATH" ]; then
        echo -e "${YELLOW}[SKIP] ${LOCAL_PATH} が見つかりません${NC}"
        ((SKIP_COUNT++))
        continue
    fi
    
    # S3に既に存在するか確認
    if aws s3 ls "s3://${S3_BUCKET}/${S3_KEY}" >/dev/null 2>&1; then
        echo -e "${YELLOW}[SKIP] ${S3_KEY} は既にS3に存在します${NC}"
        ((SKIP_COUNT++))
        continue
    fi
    
    # S3にアップロード
    if aws s3 cp "$LOCAL_PATH" "s3://${S3_BUCKET}/${S3_KEY}" >/dev/null 2>&1; then
        echo -e "${GREEN}[OK] ${S3_KEY}${NC}"
        ((SUCCESS_COUNT++))
    else
        echo -e "${RED}[ERROR] ${LOCAL_PATH} のアップロードに失敗${NC}"
        ((ERROR_COUNT++))
    fi
done <<< "$IMAGES"

# 結果サマリー
echo ""
echo -e "${GREEN}=== 移行完了 ===${NC}"
echo "総数: ${TOTAL_COUNT}枚"
echo -e "${GREEN}成功: ${SUCCESS_COUNT}枚${NC}"
echo -e "${YELLOW}スキップ: ${SKIP_COUNT}枚${NC}"
echo -e "${RED}エラー: ${ERROR_COUNT}枚${NC}"

exit 0
EOF

chmod +x migrate_images_to_s3.sh
```

### スクリプトの編集

```bash
# スクリプトを編集してMySQLの接続情報を設定
vi migrate_images_to_s3.sh

# 以下を実際の値に置き換え:
# - MYSQL_HOST
# - MYSQL_PASSWORD
```

### スクリプトの実行

```bash
# ドライランテスト（実際にはアップロードしない）
# スクリプト内のaws s3 cpコマンドに--dryrunを追加してテスト

# 本番実行
./migrate_images_to_s3.sh

# ログを保存する場合
./migrate_images_to_s3.sh | tee migration_$(date +%Y%m%d_%H%M%S).log
```

---

## トラブルシューティング

### 問題1: AWS CLIの認証エラー

```bash
# IAMインスタンスプロファイルの確認
aws sts get-caller-identity

# エラーが出る場合、EC2インスタンスプロファイルが正しく設定されているか確認
curl http://169.254.169.254/latest/meta-data/iam/security-credentials/
```

### 問題2: アップロード速度が遅い

```bash
# 並列数を増やす
aws configure set default.s3.max_concurrent_requests 20
aws configure set default.s3.max_bandwidth 50MB/s

# 再実行
aws s3 sync $IMAGE_DIR/ s3://$S3_BUCKET/$S3_PREFIX
```

### 問題3: 一部のファイルがアップロードされない

```bash
# エラーログを確認
aws s3 sync $IMAGE_DIR/ s3://$S3_BUCKET/$S3_PREFIX 2>&1 | tee sync_errors.log

# ファイルパーミッションを確認
find $IMAGE_DIR -type f ! -perm -u=r -ls

# 不正なファイル名を確認（特殊文字など）
find $IMAGE_DIR -type f -name "*[^a-zA-Z0-9._-]*"
```

### 問題4: MySQLのimagesテーブルとファイルの不整合

```bash
# データベース内の画像UUIDリストを取得
mysql -h $MYSQL_HOST -P $MYSQL_PORT -u $MYSQL_USER -p"$MYSQL_PASSWORD" $MYSQL_DATABASE -e "
SELECT CONCAT(DATE_FORMAT(date, '%Y%m%d'), '/', imuuid, '.', ext) as path
FROM images
WHERE imuuid IS NOT NULL
ORDER BY date;
" > db_images.txt

# ローカルファイルリストを取得
find $IMAGE_DIR -type f | sed "s|$IMAGE_DIR/||" > local_images.txt

# 差分を確認
diff db_images.txt local_images.txt
```

---

## ロールバック手順

S3移行後に問題が発生した場合のロールバック手順：

### 1. S3モードからローカルモードに戻す

```bash
# MySQLで設定を戻す
mysql -h $MYSQL_HOST -P $MYSQL_PORT -u $MYSQL_USER -p"$MYSQL_PASSWORD" $MYSQL_DATABASE -e "
UPDATE settings 
SET value = 'local' 
WHERE name = 'IMAGE_STORAGE_MODE';
"
```

### 2. Minecraftサーバーを再起動

```bash
cd /opt/mc
docker compose restart
```

### 3. バックアップから復元（必要な場合）

```bash
# S3からバックアップをダウンロード
aws s3 cp s3://$S3_BUCKET/backups/images_backup_YYYYMMDD.tar.gz /tmp/

# 解凍して復元
cd /opt/mc/spigot/world/data/
tar -xzf /tmp/images_backup_YYYYMMDD.tar.gz
```

---

## 推奨フロー

初めてS3移行を行う場合の推奨手順：

1. ✅ **オプション1（AWS CLI一括移行）を使用**
2. ✅ **小規模テスト**: 特定の日付のみ先に移行してテスト
3. ✅ **動作確認**: Minecraftで既存画像が正しく表示されるか確認
4. ✅ **S3モード有効化**: 問題なければ本番でS3モードに切り替え
5. ✅ **全画像移行**: すべての既存画像をS3に移行
6. ✅ **最終確認**: 新規画像作成と既存画像表示の両方をテスト
7. ✅ **ローカル画像削除**: 完全に問題なければローカル画像を削除（バックアップ後）

---

## 参考資料

- [S3_IMAGE_STORAGE.md](../apps/mc/docker/docs/S3_IMAGE_STORAGE.md) - 詳細設計
- [deployment.md](./deployment.md#3-6-s3画像ストレージ設定minecraft-image-maps) - S3設定手順
- [AWS CLI S3 sync](https://docs.aws.amazon.com/cli/latest/reference/s3/sync.html) - AWS公式ドキュメント


