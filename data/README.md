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
