# Minecraft プラグインデプロイメント手順書

**作成日**: 2025-12-21  
**対象環境**: EC2 Production (i-a: MC Server)  
**前提条件**: MCサーバーが起動していること

---

## 📋 目次

1. [概要](#概要)
2. [前提条件](#前提条件)
3. [デプロイ方法の選択](#デプロイ方法の選択)
4. [方法1: ローカルビルド → S3経由転送（推奨）](#方法1-ローカルビルド--s3経由転送推奨)
5. [方法2: EC2上で直接ビルド](#方法2-ec2上で直接ビルド)
6. [動作確認](#動作確認)
7. [トラブルシューティング](#トラブルシューティング)

---

## 概要

このドキュメントは、Kishax Minecraftプラグイン（Spigot/Velocity）をEC2サーバー（i-a）にデプロイする手順を説明します。

### プラグインの種類

- **Spigot Plugin**: 各Spigotサーバーで動作するプラグイン
- **Velocity Plugin**: Velocityプロキシで動作するプラグイン

### デプロイ対象

```
apps/mc/
├── spigot/
│   ├── sv1_21_8/      # Minecraft 1.21.8用
│   ├── sv1_21_11/     # Minecraft 1.21.11用
│   └── svcore/        # 共通コア
└── velocity/          # Velocityプラグイン
```

---

## 前提条件

### ローカル環境（開発マシン）

- ✅ Git リポジトリのクローン完了
- ✅ Java 21 インストール済み
- ✅ Gradle インストール済み（または `./gradlew` 使用）
- ✅ AWS CLI v2 + AWS SSO 認証済み

```bash
# Java確認
java -version
# → openjdk version "21.x.x" または "21.0.x"

# Gradle確認（プロジェクト内のgradlewを使用）
cd /Users/tk/git/Kishax/infrastructure/apps/mc
./gradlew --version

# AWS SSO確認
aws sts get-caller-identity --profile AdministratorAccess-126112056177
```

### EC2環境（i-a: MC Server）

- ✅ MC Server起動中
- ✅ Docker & Docker Compose インストール済み
- ✅ SSM Session Manager でアクセス可能

---

## デプロイ方法の選択

| 方法 | メリット | デメリット | 推奨度 |
|------|---------|-----------|--------|
| **方法1: ローカルビルド → S3経由** | ・高速（VPC Endpoint経由）<br>・ローカルの高性能マシンでビルド<br>・EC2リソース節約 | ・ローカルにJava/Gradle環境が必要 | ⭐⭐⭐ **推奨** |
| **方法2: EC2上で直接ビルド** | ・EC2上で完結<br>・ローカル環境不要 | ・ビルドに時間がかかる<br>・EC2リソースを消費 | ⭐⭐ |

---

## 方法1: ローカルビルド → S3経由転送（推奨）

### 🚀 クイックスタート（Makeコマンド使用）

**最も簡単な方法**: 以下の2つのコマンドを実行するだけです。

```bash
# ===== ローカルマシンで実行 =====
cd /Users/tk/git/Kishax/infrastructure

# 最新コードを取得
git pull origin infra/migrate-to-ec2

# 環境変数を読み込む（初回のみ）
make env-load
source .env && source .env.auto

# ビルド → S3アップロード（自動）
make deploy-mc-to-s3
```

```bash
# ===== EC2 (i-a: MC Server) で実行 =====
# ローカルから接続
make ssh-mc

# S3からダウンロード → Dockerコンテナにコピー → 再起動（自動）
make deploy-mc
```

**これで完了！** 以下は詳細手順です。

---

### ステップ1: コードの最新化とビルド

#### 方法A: Makeコマンド（推奨）

```bash
# ローカルマシンで実行
cd /Users/tk/git/Kishax/infrastructure

# 最新コードを取得
git pull origin infra/migrate-to-ec2

# 環境変数を読み込む（初回のみ必要）
make env-load
source .env && source .env.auto

# ビルド → S3アップロード（自動）
make deploy-mc-to-s3
```

**このコマンドは自動的に以下を実行します：**
1. `./gradlew build -x test` でプラグインをビルド
2. Spigot 1.21.8/1.21.11 と Velocity をS3にアップロード
3. アップロード確認

#### 方法B: 手動実行

```bash
# ローカルマシンで実行
cd /Users/tk/git/Kishax/infrastructure

# 最新コードを取得
git pull origin infra/migrate-to-ec2

# MCプラグインディレクトリに移動
cd apps/mc

# Gradleでビルド（テストはスキップ）
./gradlew build -x test
```

**ビルド時間**: 約1-3分

**成果物の場所**:
```
apps/mc/spigot/sv1_21_8/build/libs/Kishax-Spigot-1.21.8.jar
apps/mc/spigot/sv1_21_11/build/libs/Kishax-Spigot-1.21.11.jar
apps/mc/velocity/build/libs/Kishax-Velocity-3.4.0.jar
```

---

### ステップ2: EC2でS3からダウンロードしてデプロイ

#### 方法A: Makeコマンド（推奨）

```bash
# ローカルマシンから i-a (MC Server) に接続
make ssh-mc
```

```bash
# i-a (MC Server) 上で実行

# MCプラグインディレクトリに移動
cd /home/ubuntu/infrastructure/apps/mc

# S3からダウンロード → Dockerコンテナにコピー → 再起動（自動）
make deploy-mc
```

**このコマンドは自動的に以下を実行します：**
1. S3から最新プラグインをダウンロード
2. Dockerコンテナ (`kishax-minecraft`) にコピー
3. 全サーバーを正常終了（stop/end コマンド）
4. `screen -wipe` でDeadセッションをクリーンアップ
5. `docker restart kishax-minecraft` でコンテナ再起動
6. サーバーステータスを表示

**完了！** 以下は手動実行の詳細手順です。

#### 方法B: 手動実行

##### ステップ2-1: EC2に接続

```bash
# ローカルマシンから i-a (MC Server) に接続
make ssh-mc
# または
aws ssm start-session \
  --profile AdministratorAccess-126112056177 \
  --target $(terraform -chdir=terraform output -raw instance_id_a)
```

##### ステップ2-2: S3からダウンロード

```bash
# i-a (MC Server) 上で実行

# S3バケット名を設定
export S3_BUCKET="kishax-production-docker-images"

# 作業ディレクトリ作成
mkdir -p ~/mc-plugins-temp
cd ~/mc-plugins-temp

# S3からプラグインをダウンロード
aws s3 cp s3://${S3_BUCKET}/mc-plugins/Kishax-Spigot-1.21.8.jar .
aws s3 cp s3://${S3_BUCKET}/mc-plugins/Kishax-Spigot-1.21.11.jar .
aws s3 cp s3://${S3_BUCKET}/mc-plugins/Kishax-Velocity-3.4.0.jar .

# ダウンロード確認
ls -lh *.jar

# プラグインをDockerコンテナにコピー
docker cp Kishax-Velocity-3.4.0.jar kishax-minecraft:/mc/velocity/plugins/

# 使用しているMinecraftバージョンに応じて選択
# Spigot 1.21.11の場合（推奨）
docker cp Kishax-Spigot-1.21.11.jar kishax-minecraft:/mc/spigot/home/plugins/
docker cp Kishax-Spigot-1.21.11.jar kishax-minecraft:/mc/spigot/latest/plugins/

# コピー確認
docker exec -it kishax-minecraft ls -lh /mc/velocity/plugins/Kishax-*.jar
docker exec -it kishax-minecraft ls -lh /mc/spigot/home/plugins/Kishax-*.jar
docker exec -it kishax-minecraft ls -lh /mc/spigot/latest/plugins/Kishax-*.jar

# 一時ファイルを削除
cd ~
rm -rf ~/mc-plugins-temp
```

##### ステップ2-3: サーバー再起動

**⚠️ 重要**: `docker restart` を直接使用すると、screenセッションが重複して "Dead" 状態になります。
以下の手順で正しく再起動してください。

```bash
# i-a (MC Server) 上で実行

# 1. 各サーバーを正常終了（screenセッション内でstop/endコマンド）
docker exec -it kishax-minecraft screen -S home -X stuff "stop$(printf \\r)"
docker exec -it kishax-minecraft screen -S latest -X stuff "stop$(printf \\r)"
docker exec -it kishax-minecraft screen -S proxy -X stuff "end$(printf \\r)"

# 2. サーバーの停止を待つ（45秒）
echo "サーバー停止を待機中..."
sleep 45

# 3. screenセッションが正常に終了したか確認
docker exec -it kishax-minecraft screen -list
# → "Dead" セッションがある場合は次のコマンドで削除
docker exec -it kishax-minecraft screen -wipe

# 4. プラグインがリロードされたことを確認するため、コンテナを再起動
docker restart kishax-minecraft

# 5. 30秒待機してから起動確認
sleep 30
docker exec -it kishax-minecraft screen -list
# → 新しいセッションのみが表示されることを確認
```

#### 方法B: コンテナを完全停止→起動（より確実）

```bash
# i-a (MC Server) 上で実行

# 1. 各サーバーを正常終了
docker exec -it kishax-minecraft screen -S home -X stuff "stop$(printf \\r)"
docker exec -it kishax-minecraft screen -S latest -X stuff "stop$(printf \\r)"
docker exec -it kishax-minecraft screen -S proxy -X stuff "end$(printf \\r)"

# 2. サーバー停止を待つ
sleep 45

# 3. コンテナを完全停止
docker stop kishax-minecraft

# 4. 10秒待機
sleep 10

# 5. コンテナを起動
docker start kishax-minecraft

# 6. 起動確認（30秒待機）
sleep 30
docker exec -it kishax-minecraft screen -list
# → 新しいセッションのみが表示されることを確認
```

#### 方法C: 急いでいる場合（Dead セッションのクリーンアップ付き）

```bash
# i-a (MC Server) 上で実行

# 1. Dead セッションをクリーンアップ
docker exec -it kishax-minecraft screen -wipe

# 2. 各サーバーを正常終了
docker exec -it kishax-minecraft screen -S home -X stuff "stop$(printf \\r)"
docker exec -it kishax-minecraft screen -S latest -X stuff "stop$(printf \\r)"
docker exec -it kishax-minecraft screen -S proxy -X stuff "end$(printf \\r)"

# 3. 待機
sleep 45

# 4. コンテナ再起動
docker restart kishax-minecraft

# 5. 起動確認
sleep 30
docker exec -it kishax-minecraft screen -list
```

#### トラブルシューティング: Dead セッションが残っている場合

```bash
# Dead セッションを削除
docker exec -it kishax-minecraft screen -wipe

# まだ残っている場合は、コンテナを完全に再起動
docker stop kishax-minecraft
sleep 10
docker start kishax-minecraft
sleep 30
docker exec -it kishax-minecraft screen -list
```

---

## 方法2: EC2上で直接ビルド

### ステップ1: EC2にコードをpullしてビルド

```bash
# ローカルマシンで変更をコミット＆プッシュ
cd /Users/tk/git/Kishax/infrastructure
git add .
git commit -m "Update MC plugin"
git push origin infra/migrate-to-ec2

# i-a (MC Server) に接続
make ssh-mc

# i-a上で実行
cd ~/infrastructure
git pull origin infra/migrate-to-ec2

# Gradleでビルド
cd apps/mc
./gradlew build -x test
```

**注意**: EC2上でのビルドはローカルよりも遅い場合があります（特にt3.large）。

### ステップ2: プラグインをデプロイ

```bash
# i-a (MC Server) 上で実行
cd ~/infrastructure/apps/mc

# プラグインをDockerコンテナにコピー
docker cp velocity/build/libs/Kishax-Velocity-3.4.0.jar kishax-minecraft:/mc/velocity/plugins/

# 使用しているバージョンに応じて選択
docker cp spigot/sv1_21_11/build/libs/Kishax-Spigot-1.21.11.jar kishax-minecraft:/mc/spigot/home/plugins/
docker cp spigot/sv1_21_11/build/libs/Kishax-Spigot-1.21.11.jar kishax-minecraft:/mc/spigot/latest/plugins/

# 他のサーバーにも必要に応じてコピー
# docker cp spigot/sv1_21_11/build/libs/Kishax-Spigot-1.21.11.jar kishax-minecraft:/mc/spigot/darumasan/plugins/

# コピー確認
docker exec -it kishax-minecraft ls -lh /mc/velocity/plugins/Kishax-*.jar
docker exec -it kishax-minecraft ls -lh /mc/spigot/home/plugins/Kishax-*.jar
docker exec -it kishax-minecraft ls -lh /mc/spigot/latest/plugins/Kishax-*.jar
```

### ステップ3: サーバー再起動

方法1のステップ4と同じ手順でサーバーを再起動してください（上記参照）。

---

## 動作確認

### 1. プラグインが正しくロードされたか確認

```bash
# Velocity コンソールに接続
docker exec -it kishax-minecraft screen -rx proxy

# プラグイン一覧を確認
/velocity plugins
# → Kishaxが表示されることを確認

# Ctrl+A → D でデタッチ
```

```bash
# Spigot (home) コンソールに接続
docker exec -it kishax-minecraft screen -rx home

# プラグイン一覧を確認
/plugins
# → Kishaxが緑色で表示されることを確認

# Ctrl+A → D でデタッチ
```

### 2. プラグインのバージョン確認

```bash
# Velocity
docker exec -it kishax-minecraft cat /mc/velocity/logs/latest.log | grep -i "kishax"

# Spigot (home)
docker exec -it kishax-minecraft cat /mc/spigot/home/logs/latest.log | grep -i "kishax"

# Spigot (latest)
docker exec -it kishax-minecraft cat /mc/spigot/latest/logs/latest.log | grep -i "kishax"
```

### 3. plugin.ymlの変更が反映されているか確認

プラグイン内でパーミッションを確認します：

```bash
# ゲーム内で実行（Minecraftクライアントから）
/lp user <ユーザー名> permission check kishax.confirm
/lp user <ユーザー名> permission check kishax.portal

# タブ補完の確認
/kishax [TAB]
# → confirm, check, portal などが表示されればOK
```

---

## トラブルシューティング

### 問題1: screenセッションが重複する（Dead セッション）

**症状**: `docker exec -it kishax-minecraft screen -list` で "Dead" セッションが表示される

**原因**: 
- `docker restart` を直接使用すると、screenセッションが正常終了せずにDead状態になる
- サーバーが停止する前にコンテナが再起動される

**解決策**:
```bash
# 1. Dead セッションをクリーンアップ
docker exec -it kishax-minecraft screen -wipe

# 2. 今後は正しい再起動手順を使用（ステップ4参照）
# - 必ずサーバーを先に stop/end で終了
# - 十分な待機時間を確保（45秒以上推奨）
# - docker stop → docker start を使用
```

### 問題2: タブ補完が表示されない

**症状**: `/kishax` の後にスペース＋TABを押しても補完候補が出ない

**原因**: 
1. `plugin.yml` のパーミッション定義が含まれていない古いプラグインが動作している
2. プラグインが正しくリロードされていない

**解決策**:
```bash
# 1. 新しいプラグインが実際にコピーされているか確認
docker exec -it kishax-minecraft ls -lh /mc/spigot/home/plugins/Kishax-Spigot-*.jar

# 2. plugin.ymlの内容を確認（パーミッション定義があるか）
docker exec -it kishax-minecraft unzip -p /mc/spigot/home/plugins/Kishax-Spigot-1.21.11.jar plugin.yml | grep -A 10 "permissions:"

# 3. サーバーを完全に再起動
docker exec -it kishax-minecraft screen -S home -X stuff "stop$(printf \\r)"
# 30秒待機
sleep 30
docker exec -it kishax-minecraft screen -list
```

### 問題3: プラグインがロードされない（赤色で表示）

**症状**: `/plugins` で Kishax が赤色で表示される

**原因**:
1. 依存プラグイン（LuckPerms）がロードされていない
2. プラグインのバージョンとMinecraftバージョンの不一致
3. JARファイルが破損している

**解決策**:
```bash
# 1. エラーログを確認
docker exec -it kishax-minecraft cat /mc/spigot/home/logs/latest.log | grep -i "kishax\|error"

# 2. LuckPermsが正しくロードされているか確認
docker exec -it kishax-minecraft screen -rx home
/plugins
# → LuckPermsが緑色で表示されることを確認

# 3. JARファイルの整合性確認
docker exec -it kishax-minecraft md5sum /mc/spigot/home/plugins/Kishax-Spigot-*.jar
```

### 問題4: ビルドが失敗する

**症状**: `./gradlew build` でエラーが発生

**原因**:
1. Javaバージョンの不一致（Java 21が必要）
2. 依存関係の問題
3. ソースコードの構文エラー

**解決策**:
```bash
# 1. Javaバージョン確認
java -version
# → 21.x.x であることを確認

# 2. Gradleキャッシュをクリア
./gradlew clean

# 3. 再ビルド（詳細ログ付き）
./gradlew build -x test --info

# 4. エラーメッセージを確認して修正
```

### 問題5: S3からのダウンロードが失敗する

**症状**: `aws s3 cp` でエラーが発生

**原因**:
1. EC2のIAMロールにS3アクセス権限がない
2. S3バケット名が間違っている
3. ファイルが存在しない

**解決策**:
```bash
# 1. IAMロール確認
aws sts get-caller-identity

# 2. S3バケットの存在確認
aws s3 ls

# 3. ファイルの存在確認
aws s3 ls s3://kishax-production-docker-images/mc-plugins/

# 4. 正しいバケット名を使用
export S3_BUCKET="kishax-production-docker-images"
aws s3 cp s3://${S3_BUCKET}/mc-plugins/Kishax-Spigot-1.21.11.jar .
```

---

## ローカル開発環境用コマンド

ローカルでDockerを使用して開発している場合は、以下のMakeコマンドが使用できます：

```bash
# ローカル環境のみ（kishax-minecraftコンテナが必要）
cd /Users/tk/git/Kishax/infrastructure/apps/mc

# プラグインをビルド＆デプロイ＆再起動
make deploy-plugin
```

**注意**: このコマンドは EC2 では使用できません。EC2では上記の「方法1」または「方法2」を使用してください。

---

## 参考情報

### plugin.yml のパーミッション定義について

Minecraft 1.21.11 以降、または特定の環境では `plugin.yml` にパーミッション定義を明示的に記載する必要があります。

**例**: `apps/mc/spigot/src/main/resources/plugin.yml`

```yaml
permissions:
  kishax.*:
    description: Gives access to all kishax commands
    default: op
    children:
      kishax.confirm: true
      kishax.check: true
      kishax.portal: true
      # ...
  kishax.confirm:
    description: Allows use of /kishax confirm
    default: true  # 全プレイヤーに許可
  kishax.check:
    description: Allows use of /kishax check
    default: true  # 全プレイヤーに許可
```

これにより、LuckPerms のワイルドカードパーミッション（`kishax.*`）が正しく展開され、タブ補完も動作します。

### Gradle ビルドキャッシュ

初回ビルドは依存関係のダウンロードで時間がかかりますが、2回目以降はキャッシュが効いて高速になります。

```bash
# キャッシュをクリアしたい場合
./gradlew clean

# ビルドキャッシュの場所
~/.gradle/caches/
```

### docker cp の代替: Volume マウント

頻繁にプラグインを更新する場合は、ホストとコンテナ間で Volume をマウントすることも検討できます：

```yaml
# compose.yml
services:
  minecraft:
    volumes:
      - ./plugins:/mc/home/plugins
```

ただし、本番環境では明示的なコピーの方が安全です。

---

## 関連ドキュメント

- [EC2 デプロイメント手順書](./deployment.md)
- [MC Server 運用マニュアル](./mc-server-operations.md)
- [トラブルシューティング全般](./deployment.md#トラブルシューティング)
