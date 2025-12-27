# 環境変数管理ガイド

## 🎯 目的

Terraform outputから取得する環境変数を毎回手動でexportするのは面倒です。
このMakefile + .env システムにより、以下が実現できます：

1. **一括取得**: `make env-load` で全ての環境変数を取得
2. **簡単読み込み**: `source .env && source .env.auto` で環境に適用
3. **パスワード管理**: `.env` でRDSパスワードを一元管理

## 📋 初回セットアップ

### 1. .envファイル作成

```bash
# .env.example をコピー
cp .env.example .env

# パスワードを設定
vi .env
```

`.env` に以下を設定してください：

```bash
# terraform.tfvars と同じ値を入力
POSTGRES_PASSWORD=your_actual_postgres_password
MYSQL_PASSWORD=your_actual_mysql_password
```

### 2. 環境変数を取得

```bash
# Terraform outputから環境変数を取得
make env-load
```

これにより、`.env.auto` ファイルが生成されます。

### 3. 環境変数を読み込む

```bash
# 現在のシェルセッションに読み込む
source .env && source .env.auto
```

## 🔄 日常の使い方

### 環境変数の更新が必要な時

Terraform apply後など、環境が変更された場合：

```bash
# 1. 環境変数を再取得
make env-load

# 2. 現在のシェルに反映
source .env && source .env.auto
```

### 環境変数の確認

```bash
# 現在設定されている環境変数を表示
make env-show
```

### 個別の確認

```bash
# RDS Endpoint
echo $RDS_POSTGRES_ENDPOINT
echo $RDS_MYSQL_ENDPOINT

# EC2 Instance ID
echo $INSTANCE_ID_A  # MC Server
echo $INSTANCE_ID_B  # API Server
echo $INSTANCE_ID_C  # Web Server
echo $INSTANCE_ID_D  # Jump Server

# Private IP
echo $INSTANCE_ID_B_PRIVATE_IP

# SQS
echo $TO_MC_QUEUE_URL

# S3
echo $S3_BUCKET
```

## 📝 生成される環境変数一覧

### RDS関連
- `RDS_POSTGRES_ENDPOINT`: PostgreSQLエンドポイント (ホスト:ポート)
- `RDS_POSTGRES_HOST`: PostgreSQLホスト名のみ
- `RDS_POSTGRES_PORT`: PostgreSQLポート番号のみ
- `RDS_MYSQL_ENDPOINT`: MySQLエンドポイント (ホスト:ポート)
- `RDS_MYSQL_HOST`: MySQLホスト名のみ
- `RDS_MYSQL_PORT`: MySQLポート番号のみ

### SQS関連
- `TO_WEB_QUEUE_URL`: Web向けSQSキューURL
- `TO_MC_QUEUE_URL`: MC向けSQSキューURL
- `TO_DISCORD_QUEUE_URL`: Discord向けSQSキューURL
- `MC_WEB_SQS_ACCESS_KEY_ID`: SQS Access Key ID
- `MC_WEB_SQS_SECRET_ACCESS_KEY`: SQS Secret Access Key

### S3関連
- `S3_BUCKET`: Dockerイメージ保存用S3バケット名

### EC2関連
- `INSTANCE_ID_A`: MC ServerのインスタンスID
- `INSTANCE_ID_B`: API ServerのインスタンスID
- `INSTANCE_ID_C`: Web ServerのインスタンスID
- `INSTANCE_ID_D`: Jump ServerのインスタンスID
- `INSTANCE_ID_A_PRIVATE_IP`: MC ServerのプライベートIP
- `INSTANCE_ID_B_PRIVATE_IP`: API ServerのプライベートIP
- `INSTANCE_ID_C_PRIVATE_IP`: Web ServerのプライベートIP

### PostgreSQL接続用 (ポートフォワーディング)
- `PGHOST`: localhost
- `PGPORT`: 5433
- `PGUSER`: postgres
- `PGPASSWORD`: (POSTGRES_PASSWORDから自動設定)
- `PGDATABASE`: kishax_main

## 🛠️ 使用例

### PostgreSQL接続

```bash
# 1. 環境変数を読み込む
source .env && source .env.auto

# 2. Jump Server経由でポートフォワーディング (別ターミナル)
make rds-connect-postgres

# 3. psqlで接続 (メインターミナル)
psql
# または
psql -h $PGHOST -p $PGPORT -U $PGUSER -d $PGDATABASE
```

環境変数 `PGPASSWORD` が設定されているため、パスワード入力不要です！

### Docker Image S3アップロード

```bash
# 環境変数読み込み
source .env && source .env.auto

# イメージをS3にアップロード
docker save kishax-web:latest | gzip | aws s3 cp - s3://$S3_BUCKET/kishax-web-latest.tar.gz
```

### .envファイル生成（EC2上）

```bash
# 環境変数読み込み
source .env && source .env.auto

# i-bの.envファイル生成例
cat > /tmp/i-b.env <<EOF
REDIS_URL=redis://localhost:6379
AUTH_API_URL=http://localhost:8080
POSTGRES_URL=postgresql://postgres:${POSTGRES_PASSWORD}@${RDS_POSTGRES_HOST}:${RDS_POSTGRES_PORT}/kishax_main
TO_WEB_QUEUE_URL=${TO_WEB_QUEUE_URL}
EOF
```

## ⚠️ 注意事項

### セキュリティ

- `.env` と `.env.auto` は `.gitignore` に追加済み（コミットされません）
- `.env` にはパスワードが含まれるため、取り扱いに注意
- `.env.example` にはパスワードを含めないこと

### シェルセッション

- 環境変数は**現在のシェルセッション**のみ有効
- 新しいターミナルを開いた場合は `source .env && source .env.auto` を再実行

### ファイルの優先順位

1. `.env`: ユーザーが手動で設定（パスワード等）
2. `.env.auto`: `make env-load` が自動生成（Terraform output）

両方を読み込む必要があります：
```bash
source .env && source .env.auto
```

## 🔍 トラブルシューティング

### "❌ .envファイルが見つかりません"

```bash
cp .env.example .env
vi .env  # パスワードを設定
```

### 環境変数が空

```bash
# Terraformが初期化されているか確認
cd terraform
terraform output

# 問題なければ再取得
cd ..
make env-load
source .env && source .env.auto
```

### 古い環境変数が残っている

```bash
# シェルを再起動
exit

# または新しい環境変数を再読み込み
make env-load
source .env && source .env.auto
```

## 📖 関連コマンド

```bash
make env-check    # .envファイルの存在確認
make env-load     # 環境変数を.env.autoに保存
make env-show     # 現在の環境変数を表示
make whoami       # AWS認証情報確認
make tf-output    # Terraform output表示
```
