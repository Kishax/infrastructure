# S3画像マップ管理システム実装サマリー

## 実装完了日
2024年12月15日

## 実装概要

Minecraftプラグインで生成された画像マップをS3に保存・取得する機能を実装しました。

## 実装したコンポーネント

### 1. Java実装

#### 1.1 インターフェース
- **ファイル**: `apps/mc/spigot/svcore/src/main/java/net/kishax/mc/spigot/server/imagemap/ImageStorage.java`
- **機能**: 画像ストレージの抽象インターフェース
- **メソッド**:
  - `saveImage()` - 画像の保存
  - `loadImage()` - 画像の取得
  - `exists()` - 画像の存在確認
  - `deleteImage()` - 画像の削除
  - `getStorageType()` - ストレージタイプの取得

#### 1.2 ローカルストレージ実装
- **ファイル**: `apps/mc/spigot/svcore/src/main/java/net/kishax/mc/spigot/server/imagemap/LocalImageStorage.java`
- **機能**: ローカルファイルシステムへの画像保存・取得
- **特徴**: 従来の実装と互換性を維持

#### 1.3 S3ストレージ実装
- **ファイル**: `apps/mc/spigot/svcore/src/main/java/net/kishax/mc/spigot/server/imagemap/S3ImageStorage.java`
- **機能**: S3への画像保存・取得
- **特徴**:
  - AWS SDK v2使用
  - IAMインスタンスプロファイル対応
  - ローカルキャッシュ機能
  - 非同期処理（CompletableFuture）

#### 1.4 ストレージ管理クラス
- **ファイル**: `apps/mc/spigot/svcore/src/main/java/net/kishax/mc/spigot/server/imagemap/ImageStorageManager.java`
- **機能**: 設定に基づいてローカルまたはS3ストレージを初期化・提供
- **特徴**: シングルトン的な管理とクリーンアップ機能

#### 1.5 ImageMap.java統合
- **ファイル**: `apps/mc/spigot/svcore/src/main/java/net/kishax/mc/spigot/server/ImageMap.java`
- **変更点**:
  - `ImageStorageManager`のインジェクション
  - `saveImageToFileSystem()` - S3統合 + フォールバック機能
  - `loadImage()` - S3からの取得 + レガシーパス対応
  - `executeImageMapFromMenu()` - S3統合

### 2. 設定管理

#### 2.1 Settings.java更新
- **ファイル**: `apps/mc/common/src/main/java/net/kishax/mc/common/settings/Settings.java`
- **追加設定**:
  - `IMAGE_STORAGE_MODE` - ストレージモード（local/s3）
  - `S3_BUCKET_NAME` - S3バケット名
  - `S3_PREFIX` - S3キープレフィックス
  - `S3_REGION` - AWSリージョン
  - `S3_USE_INSTANCE_PROFILE` - IAMインスタンスプロファイル使用
  - `S3_CACHE_ENABLED` - ローカルキャッシュ有効化
  - `S3_CACHE_DIRECTORY` - キャッシュディレクトリ
- **追加メソッド**: `getBooleanValue()`

#### 2.2 MySQL設定SQL
- **ファイル**: `.bak/db/mc/s3_image_storage_settings.sql`
- **内容**: 上記設定項目をMySQLの`settings`テーブルに追加するSQL

### 3. 依存関係

#### 3.1 Gradle
- **ファイル**: `apps/mc/spigot/svcore/build.gradle`
- **追加依存関係**:
  ```gradle
  implementation platform('software.amazon.awssdk:bom:2.21.0')
  implementation 'software.amazon.awssdk:s3'
  implementation 'software.amazon.awssdk:auth'
  ```

### 4. ドキュメント

#### 4.1 デプロイドキュメント更新
- **ファイル**: `docs/infrastructure/ec2/deployment.md`
- **追加セクション**: `3-6. S3画像ストレージ設定（Minecraft Image Maps）`
- **内容**:
  - MySQL設定のインポート手順
  - S3モード有効化手順
  - S3ディレクトリ構造説明
  - キャッシュディレクトリ作成手順
  - IAM権限確認手順
  - トラブルシューティング

#### 4.2 設計ドキュメント更新
- **ファイル**: `apps/mc/docker/docs/S3_IMAGE_STORAGE.md`
- **更新内容**: 実装ステータステーブルの追加

## S3ディレクトリ構造

```
s3://kishax-production-image-maps/images/
├── 20241201/
│   ├── a1b2c3d4-e5f6-7890-abcd-ef1234567890.png
│   ├── b2c3d4e5-f6g7-8901-bcde-f12345678901.png
│   └── ...
├── 20241202/
│   └── ...
└── 20241215/
    └── ...
```

- **形式**: `YYYYMMDD/[UUID].png`
- **YYYYMMDD**: 画像生成日（JST）
- **UUID**: Minecraft内部のマップUUID
- **バケット**: `kishax-production-image-maps`（Dockerイメージバケットとは別）
- **ライフサイクル**: 永続保存（自動削除なし）

## S3バケット構成

本システムでは**2つの独立したS3バケット**を使用します：

| バケット名 | 用途 | ライフサイクル | 備考 |
|-----------|------|---------------|------|
| `kishax-production-docker-images` | Dockerイメージ、ワールドデータ | 30日で自動削除 | 一時的なデータ |
| `kishax-production-image-maps` | 画像マップ | 永続保存 | プレイヤー作成の画像を保持 |

## デフォルト設定

| 設定名 | デフォルト値 | 説明 |
|--------|------------|------|
| `IMAGE_STORAGE_MODE` | `local` | ストレージモード |
| `S3_BUCKET_NAME` | `kishax-production-image-maps` | S3バケット名（画像マップ専用） |
| `S3_PREFIX` | `images/` | S3キープレフィックス |
| `S3_REGION` | `ap-northeast-1` | AWSリージョン |
| `S3_USE_INSTANCE_PROFILE` | `true` | IAMインスタンスプロファイル使用 |
| `S3_CACHE_ENABLED` | `true` | ローカルキャッシュ有効化 |
| `S3_CACHE_DIRECTORY` | `/mc/spigot/cache/images` | キャッシュディレクトリ |

## 主要機能

### 1. 非同期処理
- すべてのS3操作は`CompletableFuture`で非同期実行
- ゲームプレイへの影響を最小化

### 2. ローカルキャッシュ
- S3から取得した画像をローカルにキャッシュ
- 2回目以降のアクセスを高速化

### 3. フォールバック機能
- S3保存失敗時、自動的にローカルストレージへフォールバック
- 既存のローカル画像もサポート（レガシーパス対応）

### 4. IAM権限管理
- EC2インスタンスプロファイルを使用した安全な認証
- 必要なS3権限:
  - `s3:GetObject`
  - `s3:PutObject`
  - `s3:DeleteObject`
  - `s3:HeadObject`
  - `s3:ListBucket`

## デプロイ手順

### 1. MySQL設定のインポート
```bash
mysql -h $MYSQL_HOST -P $MYSQL_PORT -u $MYSQL_USER -p"$MYSQL_PASSWORD" $MYSQL_DATABASE < s3_image_storage_settings.sql
```

### 2. キャッシュディレクトリの作成（i-a）
```bash
sudo mkdir -p /opt/mc/cache/images
sudo chown ec2-user:ec2-user /opt/mc/cache/images
```

### 3. S3モードの有効化（オプション）
```bash
mysql -h $MYSQL_HOST -P $MYSQL_PORT -u $MYSQL_USER -p"$MYSQL_PASSWORD" $MYSQL_DATABASE -e "
UPDATE settings SET value = 's3' WHERE name = 'IMAGE_STORAGE_MODE';
"
```

### 4. Minecraftサーバーの再起動
```bash
cd /opt/mc
docker compose restart
```

### 5. 動作確認
```bash
# ログでS3クライアント初期化を確認
docker compose logs -f | grep -i "s3\|storage"

# S3バケットの確認
aws s3 ls s3://kishax-production-image-maps/images/ --recursive
```

## テスト方法

1. Minecraftサーバーに接続
2. `/kishax im create <url> <title> <comment>` コマンドで画像マップを作成
3. S3バケットへのアクセス確認
   ```bash
   aws s3 ls s3://kishax-production-image-maps/images/$(date +%Y%m%d)/
   ```
4. ローカルキャッシュに画像が保存されているか確認（i-a上）:
   ```bash
   ls -lah /opt/mc/cache/images/$(date +%Y%m%d)/
   ```

## トラブルシューティング

### S3接続エラー
- IAMインスタンスプロファイルの確認
- IAMロールに付与されている権限を確認
- S3バケットへのアクセス確認

### キャッシュが動作しない
- キャッシュディレクトリのパーミッション確認
- ディスク容量確認

### 画像が見つからない
- S3バケット内のオブジェクト確認
- MySQLの`images`テーブルのデータ確認
- ローカルキャッシュの確認

## 今後の拡張

1. **S3ライフサイクルポリシー**
   - 古い画像の自動削除
   - アーカイブストレージへの移行

2. **キャッシュ最適化**
   - LRUキャッシュの実装
   - キャッシュサイズの制限

3. **モニタリング**
   - S3操作のメトリクス収集
   - CloudWatch Logsへのログ転送

4. **マイグレーションツール**
   - 既存ローカル画像のS3への一括アップロード

## 参考資料

- [S3_IMAGE_STORAGE.md](../apps/mc/docker/docs/S3_IMAGE_STORAGE.md) - 詳細設計ドキュメント
- [deployment.md](./deployment.md) - デプロイ手順
- [AWS SDK for Java v2 Documentation](https://docs.aws.amazon.com/sdk-for-java/latest/developer-guide/home.html)


