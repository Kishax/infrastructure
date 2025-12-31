# SSM ポートフォワーディング 一括管理

このドキュメントでは、全てのSSMポートフォワーディングを一括で管理するための新しいコマンドについて説明します。

## 概要

従来は各サーバーやRDSへのポートフォワーディングを個別に起動する必要がありましたが、新しいコマンドを使用すると、全てのポートフォワーディングを一括で管理できます。

**2つの方法を提供:**
1. **tmux版（推奨）**: より安定した動作、セッション管理が容易
2. **バックグラウンド版**: tmuxなしで動作、シンプル

## 前提条件

1. AWS SSO認証が完了していること
```bash
aws sso login --profile AdministratorAccess-126112056177
```

2. 環境変数が読み込まれていること
```bash
make env-load
source .env && source .env.auto
```

3. **(tmux版のみ)** tmuxがインストールされていること
```bash
# macOS
brew install tmux

# Ubuntu/Debian
sudo apt-get install tmux
```

## 新しいコマンド

### 方法1: tmux版（推奨）⭐

tmuxセッション内でポートフォワーディングを管理します。より安定しており、セッション管理も容易です。

#### 1-1. 全ポートフォワーディングを一括起動（tmux版）

```bash
make ssm-start-all-tmux
```

#### 1-2. 全ポートフォワーディングを一括停止（tmux版）

```bash
make ssm-stop-all-tmux
```

**tmux版の利点:**
- ✅ より安定した動作
- ✅ ターミナルを閉じてもセッションが継続
- ✅ セッション内で各ポートフォワーディングの状態を確認可能
- ✅ 個別のウィンドウで各サービスを管理

**tmux操作:**
```bash
# セッション一覧を表示
tmux ls

# セッションにアタッチ
tmux attach -t kishax-ssm-forwarding

# セッションから離脱（セッションは継続）
Ctrl+B → D

# ウィンドウ切り替え
Ctrl+B → 数字キー（0-4）

# ウィンドウ一覧
Ctrl+B → W
```

### 方法2: バックグラウンド版

tmuxを使わずにバックグラウンドプロセスとして実行します。

#### 2-1. 全ポートフォワーディングを一括起動

```bash
make ssm-start-all
```

#### 2-2. ポートフォワーディングの状態確認

```bash
make ssm-status
```

#### 2-3. 全ポートフォワーディングを一括停止

```bash
make ssm-stop-all
```

**注意:** バックグラウンド版は環境によって動作が不安定な場合があります。その場合は **tmux版の使用を推奨** します。

## 対象ポートフォワーディング

どちらの方法でも、以下の全てのポートフォワーディングが起動します：

- **MC Server (i-a)**: `localhost:2222`
- **API Server (i-b)**: `localhost:2223`
- **Web Server (i-c)**: `localhost:2224`
- **RDS MySQL**: `localhost:3307`
- **RDS PostgreSQL**: `localhost:5433`

## 使用例

### tmux版を使用する場合（推奨）

```bash
# 1. 環境変数を読み込む
make env-load
source .env && source .env.auto

# 2. AWS SSOログイン（必要な場合）
aws sso login --profile AdministratorAccess-126112056177

# 3. 全ポートフォワーディングを起動（tmux版）
make ssm-start-all-tmux

# 4. サーバーに接続（例：MC Server）
make ssh-mc

# 5. tmuxセッションの状態を確認
tmux attach -t kishax-ssm-forwarding
# Ctrl+B → D で離脱

# 6. 作業が終わったら停止
make ssm-stop-all-tmux
```

### バックグラウンド版を使用する場合

### バックグラウンド版を使用する場合

```bash
# 1. 環境変数を読み込む
make env-load
source .env && source .env.auto

# 2. AWS SSOログイン（必要な場合）
aws sso login --profile AdministratorAccess-126112056177

# 3. 全ポートフォワーディングを起動
make ssm-start-all

# 4. 状態確認
make ssm-status

# 5. サーバーに接続（例：MC Server）
make ssh-mc

# 6. 作業が終わったら停止
make ssm-stop-all
```

### 個別接続の例

ポートフォワーディング起動後、以下のコマンドで各サーバーに接続できます：

```bash
# SSH接続
make ssh-mc    # MC Server
make ssh-api   # API Server
make ssh-web   # Web Server

# データベース接続
make ssh-mysql     # MySQL
make ssh-postgres  # PostgreSQL
```

## トラブルシューティング

### tmux版のトラブルシューティング

#### tmuxセッションが起動しない

1. tmuxがインストールされているか確認：
```bash
which tmux
```

2. AWS認証を確認：
```bash
aws sts get-caller-identity --profile AdministratorAccess-126112056177
```

3. Jump Serverが起動しているか確認：
```bash
make ec2-list
```

#### tmuxセッション内のエラーを確認

```bash
# セッションにアタッチ
tmux attach -t kishax-ssm-forwarding

# 各ウィンドウを確認（Ctrl+B → 数字キー）
# エラーメッセージが表示されている場合、それに従って対処
```

### バックグラウンド版のトラブルシューティング

#### ポートフォワーディングがすぐに停止する

1. ログを確認：
```bash
make ssm-status
# または
tail -50 ~/.kishax-ssm-logs/ssm-*.log
```

2. AWS Session Manager Pluginがインストールされているか確認：
```bash
session-manager-plugin
```

インストールされていない場合：
- [AWS Session Manager Plugin インストールガイド](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html)

3. バックグラウンド版で問題が発生する場合は、**tmux版の使用を推奨** します。

### ポートが既に使用中

**tmux版:**
```bash
make ssm-stop-all-tmux
# その後、再起動
make ssm-start-all-tmux
```

**バックグラウンド版:**
```bash
make ssm-status  # 使用中のポートを確認
make ssm-stop-all
# その後、再起動
make ssm-start-all
```

### 手動でプロセスを停止する必要がある場合

```bash
# ポートを使用しているプロセスを確認
lsof -ti:2222

# プロセスを停止
kill <PID>

# または、tmuxセッションを直接停止
tmux kill-session -t kishax-ssm-forwarding
```

## ログファイルとセッション管理

### tmux版
- **セッション名**: `kishax-ssm-forwarding`
- **ウィンドウ構成**:
  - `mc`: MC Server
  - `api`: API Server
  - `web`: Web Server
  - `mysql`: RDS MySQL
  - `postgres`: RDS PostgreSQL

### バックグラウンド版
全てのログは `~/.kishax-ssm-logs/` ディレクトリに保存されます：

- `ssm-MC Server.log`
- `ssm-API Server.log`
- `ssm-Web Server.log`
- `ssm-RDS MySQL.log`
- `ssm-RDS PostgreSQL.log`
- `pids.txt` (プロセスIDの管理ファイル)

## 従来のコマンドとの比較

### 従来の方法（個別実行）

```bash
# 各ターミナルで個別に実行（ターミナルを占有）
make ssm-mc       # ターミナル1
make ssm-api      # ターミナル2
make ssm-web      # ターミナル3
make ssm-mysql    # ターミナル4
make ssm-postgres # ターミナル5
```

**問題点:**
- ❌ 5つのターミナルが必要
- ❌ 各ターミナルが占有される
- ❌ 管理が煩雑
- ❌ 一括停止ができない

### 新しい方法（tmux版・推奨）

```bash
# 1つのコマンドで全て起動
make ssm-start-all-tmux

# ターミナルは占有されず、自由に使える
# セッションはバックグラウンドで動作
```

**メリット:**
- ✅ 1つのコマンドで全て管理
- ✅ ターミナルを占有しない
- ✅ セッション管理が容易
- ✅ 一括停止が可能
- ✅ 安定した動作
- ✅ ターミナルを閉じても継続

### 新しい方法（バックグラウンド版）

```bash
# 1つのコマンドで全て起動
make ssm-start-all

# ターミナルは占有されない
```

**メリット:**
- ✅ tmux不要でシンプル
- ✅ 1つのコマンドで全て管理
- ✅ 状態確認が簡単

**注意点:**
- ⚠️ 環境によって不安定な場合あり
- ⚠️ その場合はtmux版を推奨

## どちらの方法を選ぶべきか？

| 状況 | 推奨方法 |
|------|---------|
| **通常の使用** | tmux版（より安定） |
| **tmuxをインストールしたくない** | バックグラウンド版 |
| **長時間稼働させたい** | tmux版（セッション管理が容易） |
| **デバッグが必要** | tmux版（各セッションを直接確認可能） |
| **シンプルさ重視** | バックグラウンド版 |

## 注意事項

1. **AWS SSO認証**: セッションが切れている場合は再ログインが必要です
2. **Jump Server**: Jump Serverが起動していない場合はエラーになります
3. **ポートの競合**: 同じポートを使用する他のアプリケーションがある場合は停止してください
4. **macOS/Linux互換性**: スクリプトは両OSに対応していますが、一部コマンドの動作が異なる場合があります

## 関連コマンド

- `make env-load`: 環境変数を読み込む
- `make ec2-list`: EC2インスタンス一覧を表示
- `make rds-status`: RDSのステータスを確認
- `make help`: 全てのMakeコマンドを表示

