こちらは初期に使っていたものです。
今ではDockerに置き換わったので、使われていません。

以下のディレクトリ構造でスクリプト: [scripts/upload-world-to-s3.sh](scripts/upload-world-to-s3.sh) を使用して、最新のワールドデータをS3バケットにアップロードします。
```
# Directory Structure
latest/
home/
terraria/
```

## data/terraria/

Terraria サーバのデータディレクトリです。

### Makefile

S3との同期・バックアップ用のMakefileコマンドが用意されています。

**EC2サーバ側（`/opt/terraria`）で使用するコマンド:**

- `make download`: S3から最新バージョンをダウンロード
- `make upload`: 既存の最新バージョンに上書きアップロード
- `make upload new`: 新バージョンとしてアップロード

**ローカル開発環境で使用するコマンド（ルートディレクトリ）:**

- `make terra-download`: S3から最新バージョンを `./data/terraria/` にダウンロード
- `make terra-upload`: `./data/terraria/` から最新バージョンへアップロード

### スクリプト

#### setup

初回セットアップ用スクリプトです。実行権限を付与します。

```bash
./setup
```

- `start` に実行権限を付与
- `TShock.Server` に実行権限を付与

#### start

Terrariaサーバを起動するスクリプトです。

**使い方:**

- `./start`: 通常起動（フォアグラウンド）
- `./start --daemon`: screenセッションで起動（バックグラウンド）

**screenセッションの操作:**

- セッション名: `terraria`
- アタッチ: `screen -r terraria`
- デタッチ: `Ctrl+A` → `D`

**環境変数:**

- `DOTNET_ROOT`: スクリプトディレクトリ内の `.NET_Runtime_6.0.16` を自動検出
- 見つからない場合は `/opt/terraria/.NET_Runtime_6.0.16` をデフォルトで使用
