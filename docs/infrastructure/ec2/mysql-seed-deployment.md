# RDS シードデータ挿入手順

本番環境のRDS（MySQL / PostgreSQL）にシードデータを挿入する手順をまとめます。

- **MySQL**: `.bak/db/mc` 以下のシードファイル（Minecraft用）
- **PostgreSQL**: `.bak/db/postgres` 以下のシードファイル（Web用）

## 📋 目次

1. [事前準備](#事前準備)
2. [MySQL シード挿入](#mysql-シード挿入)
   - [シードファイル一覧](#mysqlシードファイル一覧)
   - [接続手順](#mysql接続手順)
   - [シード挿入手順](#mysqlシード挿入手順)
3. [PostgreSQL シード挿入](#postgresql-シード挿入)
   - [シードファイル一覧](#postgresqlシードファイル一覧)
   - [接続手順](#postgresql接続手順)
   - [シード挿入手順](#postgresqlシード挿入手順)
4. [トラブルシューティング](#トラブルシューティング)

---

## 事前準備

### 1. 環境変数の読み込み

```bash
cd /Users/tk/git/Kishax/infrastructure
make env-load
source .env && source .env.auto
```

### 2. AWS SSO認証

```bash
aws sso login --profile AdministratorAccess-126112056177
```

### 3. 必要なツールの確認

```bash
# MySQLクライアントがインストールされているか確認
which mysql

# インストールされていない場合
brew install mysql-client
```

---

## MySQL シード挿入

### MySQLシードファイル一覧

#### 利用可能なシードファイル

```bash
make mysql-seed-list
```

#### 主要なシードファイル

`.bak/db/mc`ディレクトリには以下のファイルが存在します：

| ファイル名 | 内容 | サイズ | 優先度 |
|-----------|------|--------|--------|
| `s3_image_storage_settings.sql` | S3画像ストレージ設定 | ~2KB | **高** |
| `status_migrated_seed.sql` | サーバーステータス情報 | ~4KB | **高** |
| `settings_202512141846.sql` | 既存設定データ | ~700B | 中 |
| `members_202512141845.sql` | メンバー情報 | ~4KB | 中 |
| `images_202512141844.sql` | 画像マップデータ | ~75KB | 低 |
| `image_tiles_202512141844.sql` | 画像タイルデータ | ~3.6MB | 低 |
| `lp_*.sql` | LuckPerms権限データ | 複数 | 低 |
| その他 | ログ、座標など | 複数 | 低 |

---

### MySQL接続手順

#### ターミナル1: ポートフォワーディング

```bash
# RDS MySQLへのSSMポートフォワーディングを開始
make ssm-mysql
```

**出力例:**
```
🔗 RDS MySQL へポートフォワーディングを開始します...
Jump Server: i-0cb71a49eb2849b3d
Target: kishax-production-mysql.xxxxx.ap-northeast-1.rds.amazonaws.com:3306
Local Port: 3307

✅ ポートフォワーディング開始 (このターミナルは占有されます)
📝 別ターミナルで 'make ssh-mysql' を実行してMySQL接続してください

Starting session with SessionId: takaya@kishax.net-xxxxx
Port 3307 opened for sessionId...
Waiting for connections...
```

**⚠️ このターミナルは占有されます。Ctrl+Cで終了するまで維持してください。**

#### ターミナル2: MySQL接続確認

```bash
# MySQL接続テスト
make ssh-mysql
```

接続できたら、以下のコマンドで現在のデータを確認：

```sql
-- データベース選択
USE kishax_mc;

-- テーブル一覧
SHOW TABLES;

-- 既存の設定確認
SELECT * FROM settings;

-- サーバーステータス確認
SELECT * FROM status;

-- 終了
EXIT;
```

---

### MySQLシード挿入手順

#### 方法1: Makefileコマンドを使用（推奨）

#### 1. S3画像ストレージ設定の挿入

```bash
# ターミナル2（ポートフォワーディング中）
make mysql-seed-s3
```

または、個別に指定：

```bash
make mysql-seed-import FILE=.bak/db/mc/s3_image_storage_settings.sql
```

#### 2. サーバーステータス情報の挿入

```bash
make mysql-seed-import FILE=.bak/db/mc/status_migrated_seed.sql
```

#### 3. その他のシード挿入

```bash
# メンバー情報
make mysql-seed-import FILE=.bak/db/mc/members_202512141845.sql

# 設定データ
make mysql-seed-import FILE=.bak/db/mc/settings_202512141846.sql
```

#### 方法2: MySQL CLIで直接実行

```bash
# ターミナル2
source .env && source .env.auto

# SQLファイルを直接実行
mysql -h 127.0.0.1 -P 3307 -u admin -p"$MYSQL_PASSWORD" kishax_mc < .bak/db/mc/s3_image_storage_settings.sql

# 複数ファイルを順次実行
for sql_file in .bak/db/mc/s3_*.sql; do
  echo "Importing: $sql_file"
  mysql -h 127.0.0.1 -P 3307 -u admin -p"$MYSQL_PASSWORD" kishax_mc < "$sql_file"
done
```

---

### MySQL挿入後の確認

#### 1. S3画像ストレージ設定の確認

```bash
make ssh-mysql
```

```sql
USE kishax_mc;

-- S3関連設定を確認
SELECT * FROM settings WHERE name LIKE 'IMAGE_STORAGE_MODE' OR name LIKE 'S3_%';
```

**期待される結果:**

| id | name | value | description |
|----|------|-------|-------------|
| X | IMAGE_STORAGE_MODE | local | Image storage mode: "local" or "s3" |
| X | S3_BUCKET_NAME | kishax-production-image-maps | S3 bucket name for image maps storage |
| X | S3_PREFIX | images/ | S3 key prefix for images |
| X | S3_REGION | ap-northeast-1 | AWS region for S3 |
| X | S3_USE_INSTANCE_PROFILE | true | Use IAM instance profile for S3 authentication |
| X | S3_CACHE_ENABLED | true | Enable local cache for S3 images |
| X | S3_CACHE_DIRECTORY | /mc/spigot/cache/images | Local cache directory for S3 images |

#### 2. サーバーステータスの確認

```sql
-- サーバー一覧
SELECT name, port, online, type, platform FROM status;

-- ハブサーバーの確認
SELECT * FROM status WHERE hub = 1;
```

#### 3. S3モードの有効化（必要に応じて）

```sql
-- S3モードに切り替え
UPDATE settings SET value = 's3' WHERE name = 'IMAGE_STORAGE_MODE';

-- 確認
SELECT * FROM settings WHERE name = 'IMAGE_STORAGE_MODE';
```

---

## PostgreSQL シード挿入

### PostgreSQLシードファイル一覧

#### 利用可能なシードファイル

```bash
make postgres-seed-list
```

#### 主要なシードファイル

`.bak/db/postgres`ディレクトリには以下のファイルが存在します：

| ファイル名 | 内容 | サイズ | 優先度 |
|-----------|------|--------|--------|
| `users_migrated_seed.sql` | ユーザー情報（移行済み） | ~数KB | **高** |

---

### PostgreSQL接続手順

#### ターミナル1: ポートフォワーディング

```bash
# RDS PostgreSQLへのSSMポートフォワーディングを開始
make ssm-postgres
```

**出力例:**
```
🔗 RDS PostgreSQL へポートフォワーディングを開始します...
Jump Server: i-0cb71a49eb2849b3d
Target: kishax-production-postgres.xxxxx.ap-northeast-1.rds.amazonaws.com:5432
Local Port: 5433
Database: kishax_web

✅ ポートフォワーディング開始 (このターミナルは占有されます)
📝 別ターミナルで 'make ssh-postgres' を実行してPostgreSQL接続してください

Starting session with SessionId: takaya@kishax.net-xxxxx
Port 5433 opened for sessionId...
Waiting for connections...
```

**⚠️ このターミナルは占有されます。Ctrl+Cで終了するまで維持してください。**

#### ターミナル2: PostgreSQL接続確認

```bash
# PostgreSQL接続テスト
make ssh-postgres
```

接続できたら、以下のコマンドで現在のデータを確認：

```sql
-- テーブル一覧
\dt

-- ユーザー一覧
SELECT id, email, username, created_at FROM users LIMIT 10;

-- 終了
\q
```

---

### PostgreSQLシード挿入手順

#### 方法1: Makefileコマンドを使用（推奨）

##### 1. ユーザー情報の挿入

```bash
# ターミナル2（ポートフォワーディング中）
make postgres-seed-users
```

または、個別に指定：

```bash
make postgres-seed-import FILE=.bak/db/postgres/users_migrated_seed.sql
```

#### 方法2: psql CLIで直接実行

```bash
# ターミナル2
source .env && source .env.auto

# SQLファイルを直接実行
PGPASSWORD="$POSTGRES_PASSWORD" psql -h 127.0.0.1 -p 5433 -U postgres -d kishax_web -f .bak/db/postgres/users_migrated_seed.sql
```

---

### PostgreSQL挿入後の確認

#### 1. ユーザー情報の確認

```bash
make ssh-postgres
```

```sql
-- ユーザー数確認
SELECT COUNT(*) FROM users;

-- 最新ユーザー10件
SELECT id, email, username, created_at 
FROM users 
ORDER BY created_at DESC 
LIMIT 10;

-- 特定ユーザー検索
SELECT * FROM users WHERE email = 'test@example.com';
```

---

## トラブルシューティング

### MySQL関連エラー

#### エラー1: `ERROR 2003: Can't connect to MySQL server`

**原因:** ポートフォワーディングが確立されていない

**解決策:**
1. ターミナル1で`make ssm-mysql`が実行中か確認
2. `Port 3307 opened`メッセージが表示されているか確認
3. `lsof -i :3307`でポートが開いているか確認

### エラー2: `Access denied for user 'admin'@'localhost'`

**原因:** パスワードが間違っている

**解決策:**
```bash
# .envファイルのMYSQL_PASSWORDを確認
cat .env | grep MYSQL_PASSWORD

# 環境変数を再読み込み
source .env && source .env.auto
```

### エラー3: `ERROR 1050: Table already exists`

**原因:** テーブルが既に存在する

**解決策:** SQLファイル内で`CREATE TABLE IF NOT EXISTS`や`INSERT ... ON DUPLICATE KEY UPDATE`を使用しているため、通常は問題ありません。エラーが出た場合は、既存データを確認してから手動で調整してください。

#### エラー4: `ERROR 1406: Data too long for column`

**原因:** データサイズが列の定義を超えている

**解決策:**
1. テーブル定義を確認
2. 必要に応じて列のサイズを変更
3. データを分割して挿入

### PostgreSQL関連エラー

#### エラー5: `psql: error: connection to server failed`

**原因:** ポートフォワーディングが確立されていない

**解決策:**
1. ターミナル1で`make ssm-postgres`が実行中か確認
2. `Port 5433 opened`メッセージが表示されているか確認
3. `lsof -i :5433`でポートが開いているか確認

#### エラー6: `psql: FATAL: password authentication failed`

**原因:** パスワードが間違っている

**解決策:**
```bash
# .envファイルのPOSTGRES_PASSWORDを確認
cat .env | grep POSTGRES_PASSWORD

# 環境変数を再読み込み
source .env && source .env.auto
```

#### エラー7: `ERROR: duplicate key value violates unique constraint`

**原因:** 主キーやユニーク制約に違反するデータが既に存在

**解決策:**
1. 既存データを確認
2. SQLファイル内で`ON CONFLICT`句を使用
3. 既存データを削除してから挿入

---

## ベストプラクティス

### 1. バックアップを取る

挿入前に現在のデータをバックアップ：

```bash
# 現在の設定をバックアップ
mysqldump -h 127.0.0.1 -P 3307 -u admin -p"$MYSQL_PASSWORD" kishax_mc settings > settings_backup_$(date +%Y%m%d_%H%M%S).sql

# 現在のステータスをバックアップ
mysqldump -h 127.0.0.1 -P 3307 -u admin -p"$MYSQL_PASSWORD" kishax_mc status > status_backup_$(date +%Y%m%d_%H%M%S).sql
```

### 2. 段階的に挿入

一度にすべて挿入せず、重要なものから順次挿入：

1. **Phase 1 (必須):** `s3_image_storage_settings.sql`
2. **Phase 2 (必須):** `status_migrated_seed.sql`
3. **Phase 3 (任意):** その他のデータ

### 3. 挿入後にアプリケーションを再起動

設定変更後は、MC Serverを再起動して設定を反映：

```bash
# MC Serverに接続
make ssh-mc

# Dockerコンテナを再起動
docker restart kishax-minecraft
```

---

## クイックリファレンス

### MySQL

```bash
# 1. 環境準備
make env-load && source .env && source .env.auto

# 2. ターミナル1: ポートフォワーディング
make ssm-mysql

# 3. ターミナル2: シード挿入
make mysql-seed-list                                            # ファイル一覧
make mysql-seed-s3                                             # S3設定挿入
make mysql-seed-import FILE=.bak/db/mc/status_migrated_seed.sql  # ステータス挿入

# 4. 確認
make ssh-mysql
# > SELECT * FROM settings WHERE name LIKE 'S3_%';
```

### PostgreSQL

```bash
# 1. 環境準備
make env-load && source .env && source .env.auto

# 2. ターミナル1: ポートフォワーディング
make ssm-postgres

# 3. ターミナル2: シード挿入
make postgres-seed-list                                         # ファイル一覧
make postgres-seed-users                                        # ユーザー情報挿入
make postgres-seed-import FILE=.bak/db/postgres/xxx.sql        # 個別ファイル挿入

# 4. 確認
make ssh-postgres
# > SELECT COUNT(*) FROM users;
```

---

## 関連ドキュメント

- [S3 Image Storage Implementation Summary](./s3-image-storage-implementation-summary.md)
- [EC2 Deployment Guide](./deployment.md)
- [Migrate Existing Images to S3](./migrate-existing-images-to-s3.md)
