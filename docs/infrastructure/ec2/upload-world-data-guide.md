# MCサーバーワールドデータのS3アップロード手順

## 概要

既存のMinecraftサーバーワールドデータを`kishax-production-world-backups`バケットにアップロードします。

## 📁 データ構造

### ローカル（`./data/`）
```
data/
├── latest/          # 8.9GB - メインサーバー
│   ├── world/
│   ├── world_nether/
│   ├── world_the_end/
│   └── world_the_creative/
└── home/            # 709MB - ホームサーバー
    ├── world/
    ├── world_nether/
    └── world_the_end/
```

### S3アップロード先
```
s3://kishax-production-world-backups/deployment/202512/1/
├── latest/
│   ├── world/
│   ├── world_nether/
│   ├── world_the_end/
│   ├── world_the_creative/
│   ├── metadata.json
│   └── __IMPORT_ENABLED__
└── home/
    ├── world/
    ├── world_nether/
    ├── world_the_end/
    ├── metadata.json
    └── __IMPORT_ENABLED__
```

---

## 🚀 アップロード手順

### ステップ1: AWS認証

```bash
# SSO ログイン
aws sso login --profile AdministratorAccess-126112056177

# 認証確認
aws sts get-caller-identity --profile AdministratorAccess-126112056177
```

### ステップ2: ドライラン（テスト実行）

```bash
# 何がアップロードされるか確認（実際にはアップロードしない）
./scripts/upload-world-to-s3.sh --dry-run
```

**確認項目:**
- ✅ データサイズが正しいか
- ✅ アップロード先のパスが正しいか
- ✅ 全てのワールドディレクトリが検出されているか

### ステップ3: 本番アップロード

```bash
# 実際にアップロード
./scripts/upload-world-to-s3.sh
```

**プロンプト:**
```
⚠️  実際にS3にアップロードします
続行しますか？ (yes/no): yes
```

**所要時間（目安）:**
- `latest` (8.9GB): 約15-20分
- `home` (709MB): 約2-3分
- **合計**: 約20-25分

---

## 📊 アップロード結果の確認

### S3バケットの確認

```bash
# deployment/ 全体を確認
aws s3 ls s3://kishax-production-world-backups/deployment/ \
  --profile AdministratorAccess-126112056177 \
  --recursive

# 特定サーバーを確認
aws s3 ls s3://kishax-production-world-backups/deployment/202512/1/latest/ \
  --profile AdministratorAccess-126112056177

# ファイル数とサイズを確認
aws s3 ls s3://kishax-production-world-backups/deployment/202512/1/latest/ \
  --profile AdministratorAccess-126112056177 \
  --recursive \
  --summarize \
  --human-readable
```

### __IMPORT_ENABLED__ フラグの確認

```bash
# インポートフラグが存在するか確認
aws s3 ls s3://kishax-production-world-backups/deployment/ \
  --profile AdministratorAccess-126112056177 \
  --recursive | grep __IMPORT_ENABLED__

# 出力例:
# 2024-12-20 22:30:00         20 deployment/202512/1/latest/__IMPORT_ENABLED__
# 2024-12-20 22:35:00         20 deployment/202512/1/home/__IMPORT_ENABLED__
```

### メタデータの確認

```bash
# メタデータファイルをダウンロードして確認
aws s3 cp s3://kishax-production-world-backups/deployment/202512/1/latest/metadata.json - \
  --profile AdministratorAccess-126112056177

# 出力例:
# {
#   "server": "latest",
#   "upload_date": "20241220",
#   "year_month": "202512",
#   "version": "1",
#   "timestamp": "2024-12-20T13:30:00Z",
#   "worlds": [
#     "world",
#     "world_nether",
#     "world_the_end",
#     "world_the_creative"
#   ]
# }
```

---

## 🔧 EC2でのワールドインポート

### ステップ1: servers.jsonの設定

EC2インスタンス (i-a) で設定を確認・変更：

```bash
# SSH接続
make ssh-mc

# servers.json を確認
cat /opt/mc/docker/config/servers.json | jq '.spigots[] | select(.name == "latest")'
```

**`s3import`を有効化:**
```json
{
  "name": "latest",
  "s3import": true,    // ← trueに設定
  "memory": "8G",
  ...
}
```

### ステップ2: Docker起動

```bash
# ボリュームのインポート完了フラグを削除（初回のみ）
sudo rm -f /opt/mc/volumes/latest/.import_completed
sudo rm -f /opt/mc/volumes/home/.import_completed

# Dockerコンテナ起動
cd /opt/mc
docker compose up -d

# ログでインポート状況を確認
docker compose logs -f | grep -i "import\|s3"
```

**期待されるログ:**
```
=== S3 World Data Import ===
Server: latest
S3 Bucket: s3://kishax-production-world-backups/deployment/
Importing world data from S3...
✅ World import completed successfully
```

---

## 🛠️ トラブルシューティング

### アップロード失敗

```bash
# エラー詳細を確認
./scripts/upload-world-to-s3.sh --dry-run

# AWS認証を再確認
aws sso login --profile AdministratorAccess-126112056177

# 手動でアップロード（特定サーバー）
aws s3 sync ./data/latest/world/ \
  s3://kishax-production-world-backups/deployment/202512/1/latest/world/ \
  --profile AdministratorAccess-126112056177
```

### インポートがスキップされる

#### 原因1: `.import_completed`フラグが存在
```bash
# EC2でフラグを確認
docker exec kishax-minecraft ls -la /mc/volumes/latest/.import_completed

# 削除して再起動
docker exec kishax-minecraft rm /mc/volumes/latest/.import_completed
docker compose restart
```

#### 原因2: `__IMPORT_ENABLED__`が存在しない
```bash
# S3でフラグを確認
aws s3 ls s3://kishax-production-world-backups/deployment/202512/1/latest/ \
  --profile AdministratorAccess-126112056177

# 手動で作成
echo "Uploaded at $(date)" | aws s3 cp - \
  s3://kishax-production-world-backups/deployment/202512/1/latest/__IMPORT_ENABLED__ \
  --profile AdministratorAccess-126112056177
```

#### 原因3: `servers.json`の`s3import`が`false`
```bash
# 設定を確認
docker exec kishax-minecraft cat /mc/config/servers.json | jq '.spigots[] | select(.name == "latest") | .s3import'

# trueでない場合は、ホスト側で修正
vi /opt/mc/docker/config/servers.json
docker compose restart
```

### S3アクセスエラー

```bash
# EC2のIAMロール確認
aws iam get-role --role-name kishax-production-mc-server-role

# S3へのアクセス確認（EC2から）
make ssh-mc
aws s3 ls s3://kishax-production-world-backups/deployment/
```

---

## 📝 スクリプト詳細

### `upload-world-to-s3.sh`

**機能:**
- ✅ データサイズの自動計算
- ✅ 全ワールドディレクトリの自動検出
- ✅ メタデータファイルの自動生成
- ✅ `__IMPORT_ENABLED__`フラグの自動作成
- ✅ カラー出力による視認性向上
- ✅ ドライランモード

**オプション:**
```bash
./scripts/upload-world-to-s3.sh --dry-run    # ドライラン
./scripts/upload-world-to-s3.sh --help       # ヘルプ表示
./scripts/upload-world-to-s3.sh              # 本番実行
```

**設定（スクリプト内）:**
```bash
BUCKET="kishax-production-world-backups"
REGION="ap-northeast-1"
AWS_PROFILE="AdministratorAccess-126112056177"
DATE=$(date +%Y%m%d)
YEAR_MONTH=$(date +%Y%m)
VERSION="1"
```

---

## 🔄 バックアップの世代管理

### ディレクトリ構造
```
s3://kishax-production-world-backups/
├── deployment/         # VM展開用（永続保存）
│   └── 202512/
│       └── 1/
│           ├── latest/
│           └── home/
├── backups/           # 定期バックアップ（180日保持）
│   └── 202512/
│       └── 1/
│           ├── latest/
│           └── home/
└── migration/         # 移行作業用（90日保持）
    └── 202412/
        └── ...
```

### バックアップコピー

```bash
# deployment/ から backups/ へコピー
aws s3 cp s3://kishax-production-world-backups/deployment/202512/1/ \
          s3://kishax-production-world-backups/backups/202512/1/ \
          --recursive \
          --profile AdministratorAccess-126112056177

# 確認
aws s3 ls s3://kishax-production-world-backups/backups/202512/1/ \
  --profile AdministratorAccess-126112056177 \
  --recursive \
  --summarize \
  --human-readable
```

---

## 📚 関連ドキュメント

- [S3基本操作ガイド](../docs/infrastructure/ec2/s3-basic-operations.md)
- [S3統合機能サマリー](../docs/infrastructure/ec2/s3-features-summary.md)
- [S3ワールドデータインポート](../apps/mc/docker/docs/S3_WORLD_IMPORT.md)

---

## ⚠️ 注意事項

1. **データサイズ**: 合計約9.6GB、アップロードに20-25分かかります
2. **ネットワーク**: 安定したインターネット接続を確保してください
3. **認証**: AWS SSO セッションは12時間で期限切れになります
4. **コスト**: S3転送コストは約$0.9（9.6GB × $0.09/GB）
5. **上書き**: 同じパスに再度アップロードすると上書きされます

---

## ✅ チェックリスト

### アップロード前
- [ ] AWS SSO ログイン完了
- [ ] `./data/` ディレクトリ確認
- [ ] ドライランでテスト実行
- [ ] アップロード先パス確認

### アップロード後
- [ ] S3バケットでファイル確認
- [ ] `__IMPORT_ENABLED__`フラグ存在確認
- [ ] `metadata.json`確認
- [ ] ファイル数・サイズの一致確認

### EC2インポート前
- [ ] `servers.json`で`s3import: true`設定
- [ ] `.import_completed`フラグ削除（初回のみ）
- [ ] Docker起動準備完了

### EC2インポート後
- [ ] ログでインポート成功確認
- [ ] Minecraftサーバー起動確認
- [ ] ワールドデータ読込確認
