# MC プラグインビルド＆デプロイメント戦略

## 概要

MC プラグイン（Velocity/Spigot）は `kishax-api` に依存しています。
開発時に `kishax-api` の変更を MC プラグインに確実に反映させるため、適切なビルド戦略が必要です。

## 問題

### 1. デプロイ時のJAR更新問題
- `docker cp` でJARをコピーしても、既存ファイルが正しく上書きされないことがある
- 実行中のプロセスが古いJARを保持し続ける

### 2. kishax-api 依存関係の伝播問題
MC プラグインは Gradle/Maven を通じて `kishax-api` を依存関係として取得します。

```gradle
dependencies {
    // ローカルMavenリポジトリ or リモートリポジトリから取得
    implementation 'net.kishax:kishax-api:1.0.0'
}
```

**問題点:**
- `apps/api` で `kishax-api` のコードを変更
- `apps/mc` でビルドしても、古いバージョンの `kishax-api` がキャッシュされている
- 結果：最新の `kishax-api` の変更が MC プラグインに反映されない

## 解決策

### アプローチ1: ローカルMavenリポジトリを使用（推奨）

#### 利点
- シンプルで信頼性が高い
- 既存のGradle/Maven設定を最小限の変更で利用可能
- ビルドの独立性を保つ

#### 実装手順

**1. apps/api側の準備**

```bash
# kishax-apiをローカルMavenリポジトリにインストール
cd /path/to/infrastructure/apps/api
mvn clean install -DskipTests
```

これにより、`~/.m2/repository/net/kishax/kishax-api/` に最新版がインストールされます。

**2. apps/mc側の設定**

`apps/mc/build.gradle` でローカルMavenリポジトリを優先するよう設定：

```gradle
repositories {
    mavenLocal()  // ローカルを最優先
    mavenCentral()
    // その他のリポジトリ...
}

dependencies {
    implementation 'net.kishax:kishax-api:1.0.0-SNAPSHOT'
    // SNAPSHOT版を使うことで、常に最新を取得
}
```

**3. 環境変数による制御**

`.env` ファイルで制御：

```bash
# MC プラグインを毎回ビルドするか
MC_BUILD_ON_DEPLOY=true

# kishax-apiを強制的に再インストールするか
API_INSTALL_ON_DEPLOY=true
```

**4. デプロイスクリプトの更新**

```bash
#!/bin/bash
# docker-compose.yml の environment セクションで読み込み

if [ "$API_INSTALL_ON_DEPLOY" = "true" ]; then
  echo "📦 kishax-apiをローカルMavenリポジトリにインストール中..."
  cd /path/to/apps/api
  mvn clean install -DskipTests
fi

if [ "$MC_BUILD_ON_DEPLOY" = "true" ]; then
  echo "🔨 MCプラグインをビルド中..."
  cd /path/to/apps/mc
  ./gradlew clean build -x test --refresh-dependencies
  # --refresh-dependencies で依存関係のキャッシュをクリア
fi
```

### アプローチ2: Gradleマルチプロジェクト構成

#### 利点
- 依存関係が自動的に解決される
- IDEのサポートが良好
- リファクタリング時の追跡が容易

#### 欠点
- 既存のプロジェクト構造を大幅に変更する必要がある
- ビルド時間が増加する可能性

#### 実装概要

```
infrastructure/
├── apps/
│   ├── api/          # Mavenプロジェクト → Gradleに変換
│   ├── mc/           # Gradleプロジェクト
│   └── settings.gradle
```

`apps/settings.gradle`:
```gradle
rootProject.name = 'kishax-apps'
include 'api', 'mc'
```

`apps/mc/build.gradle`:
```gradle
dependencies {
    implementation project(':api')  // プロジェクト依存
}
```

### アプローチ3: Docker ボリュームマウント（開発環境専用）

#### 利点
- ホットリロード可能
- 開発サイクルが高速

#### 欠点
- 本番環境では使用できない
- ファイル権限の問題が発生しやすい

## 推奨フロー

### 開発環境（ローカル）

1. `apps/api` で変更を加える
2. `cd apps/api && mvn clean install -DskipTests`
3. `cd apps/mc && ./gradlew clean build -x test --refresh-dependencies`
4. S3にアップロード: `make deploy-mc-to-s3`

### 本番環境（EC2）

**方法A: 事前ビルド（推奨）**
- ローカルで完全にビルド → S3にアップロード → EC2でダウンロード＆配置

**方法B: EC2でビルド（MC_BUILD_ON_DEPLOY=true）**
```bash
# .env 設定
MC_BUILD_ON_DEPLOY=true
API_INSTALL_ON_DEPLOY=true

# デプロイ実行
make deploy-mc
```

デプロイスクリプトが自動的に：
1. kishax-apiをビルド＆インストール（Maven）
2. MCプラグインをビルド（Gradle、最新のkishax-apiを使用）
3. コンテナに配置＆再起動

## .env 設定例

```bash
# apps/mc/.env
# ================================================
# MC Plugin Build Configuration
# ================================================

# EC2デプロイ時に毎回MCプラグインをビルドするか
# true: EC2でGradleビルドを実行（時間がかかる）
# false: S3から事前ビルド済みのJARをダウンロード（推奨）
MC_BUILD_ON_DEPLOY=false

# EC2デプロイ時にkishax-apiを再インストールするか
# true: apps/apiでmvn installを実行してローカルMavenリポジトリを更新
# false: 既存のローカルMavenリポジトリを使用
API_INSTALL_ON_DEPLOY=false

# 開発環境では以下を推奨：
# MC_BUILD_ON_DEPLOY=false
# API_INSTALL_ON_DEPLOY=false
# → ローカルでビルド&S3アップロード → EC2でダウンロード

# 本番環境で緊急時のホットフィックスが必要な場合：
# MC_BUILD_ON_DEPLOY=true
# API_INSTALL_ON_DEPLOY=true
# → EC2で完全ビルド（時間がかかるが確実）
```

## トラブルシューティング

### 問題: 変更が反映されない

**症状:**
- `apps/api` でコードを変更したが、MC プラグインで古い動作をする

**解決策:**
```bash
# 1. Gradle/Mavenキャッシュをクリア
rm -rf ~/.gradle/caches
rm -rf ~/.m2/repository/net/kishax

# 2. 完全な再ビルド
cd apps/api && mvn clean install -DskipTests
cd apps/mc && ./gradlew clean build -x test --refresh-dependencies
```

### 問題: デプロイ後もUIが変わらない

**症状:**
- EC2でデプロイしても、古いUIが表示される

**解決策:**
```bash
# コンテナ内のプラグインを完全削除してから再デプロイ
docker exec -it kishax-minecraft rm -f /mc/velocity/plugins/Kishax*.jar
docker exec -it kishax-minecraft rm -f /mc/spigot/home/plugins/Kishax*.jar
docker exec -it kishax-minecraft rm -f /mc/spigot/latest/plugins/Kishax*.jar

# 再デプロイ
cd /opt/mc && make deploy-mc

# コンテナを完全再起動
docker restart kishax-minecraft
```

### 問題: JAR内に新しいコードが含まれていない

**確認方法:**
```bash
# ローカル
unzip -p velocity/build/libs/Kishax-Velocity-3.4.0.jar net/kishax/mc/velocity/Main.class | strings | grep "v1.0.0"

# EC2
docker exec -it kishax-minecraft unzip -p /mc/velocity/plugins/Kishax-Velocity-3.4.0.jar net/kishax/mc/velocity/Main.class | strings | grep "v1.0.0"
```

**解決策:**
Gradleのビルドキャッシュが原因の可能性：
```bash
cd apps/mc
./gradlew clean
rm -rf build/
./gradlew build -x test --refresh-dependencies --rerun-tasks
```

## ベストプラクティス

### 開発フロー

1. **API変更時:**
   ```bash
   cd apps/api
   mvn clean install -DskipTests
   ```

2. **MC変更時:**
   ```bash
   cd apps/mc
   ./gradlew clean build -x test --refresh-dependencies
   ```

3. **デプロイ:**
   ```bash
   # ローカル
   make deploy-mc-to-s3
   
   # EC2
   make deploy-mc
   ```

### バージョン管理

ビルド識別子をコードに埋め込むことで、デプロイされたバージョンを確認可能にする：

```java
// Velocity/Spigot Main.java
String buildIdentifier = "v1.0.0-20251221-2130";
logger.info("Build: {}", buildIdentifier);
```

ログで確認：
```bash
docker exec -it kishax-minecraft tail -50 velocity/logs/latest.log | grep "Build:"
```

## まとめ

- **推奨アプローチ:** ローカルMavenリポジトリを使用（アプローチ1）
- **開発環境:** `MC_BUILD_ON_DEPLOY=false` でローカルビルド → S3経由でデプロイ
- **本番環境:** 通常はS3から取得、緊急時のみ `MC_BUILD_ON_DEPLOY=true`
- **依存関係更新:** `apps/api` 変更時は必ず `mvn clean install` を実行
- **トラブル時:** キャッシュクリア → 完全再ビルド → コンテナ再起動
