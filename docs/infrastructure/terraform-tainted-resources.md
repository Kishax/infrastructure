# Terraform Tainted Resources（汚染済みリソース）

## 概要

**Tainted（汚染済み）** とは、Terraformが「このリソースは壊れている・問題がある」とマークした状態です。

taintedなリソースは、次の`terraform apply`で**強制的に削除→再作成**されます。

---

## Taintedになる原因

### 1. リソース作成中のエラー
```bash
# リソース作成中にエラーが発生
terraform apply
# Error: ...
# → リソースがtaintedとしてマークされる
```

### 2. 手動でのtaint実行
```bash
# 意図的にリソースを再作成したい場合
terraform taint module.s3.aws_s3_bucket.example
```

### 3. Terraform外部でのリソース変更
- AWSコンソールから直接変更
- AWS CLIで変更
- Terraform管理外での設定変更

### 4. Terraform設定の大幅な変更
- リソース定義の変更により、Terraformが「再作成が必要」と判断
- 依存関係の変更

---

## Taintedリソースの確認方法

### terraform planで確認
```bash
terraform plan
```

**出力例:**
```
# module.s3.aws_s3_bucket.image_maps is tainted, so must be replaced
-/+ resource "aws_s3_bucket" "image_maps"
```

**記号の意味:**
- `-/+` = 削除してから再作成（destroy and then create replacement）
- `~` = インプレースで更新（update in-place）
- `+` = 新規作成（create）
- `-` = 削除（destroy）

### terraform showで確認
```bash
terraform show | grep tainted
```

---

## ⚠️ Taintedの危険性

### データ損失のリスク

**例：S3バケットがtaintedの場合**
```
-/+ resource "aws_s3_bucket" "image_maps"
```

このまま`terraform apply`すると：
1. **既存のS3バケットが削除される** ⛔
2. **バケット内の全データが失われる** ⛔
3. 新しいバケットが作成される

**結果: 全ての画像マップデータが消失！**

### データベースがtaintedの場合
```
-/+ resource "aws_db_instance" "mysql"
```

このまま`terraform apply`すると：
1. **既存のRDSインスタンスが削除される** ⛔
2. **データベース内の全データが失われる** ⛔
3. 新しいインスタンスが作成される

**結果: 全てのアプリケーションデータが消失！**

---

## 🔧 対処方法

### 1. Untaint（推奨）

リソースを保持したまま、taintedマークを解除する方法。

```bash
# taintedを解除
terraform untaint module.s3.aws_s3_bucket.image_maps

# 成功メッセージ
# Resource instance module.s3.aws_s3_bucket.image_maps has been successfully untainted.
```

**実行後:**
```bash
# 再度planを実行して確認
terraform plan

# 期待される結果：
# - リソースは更新のみ（削除・再作成なし）
# ~ resource "aws_s3_bucket" "image_maps"  # インプレース更新
```

### 2. Import（既存リソースをTerraformに取り込む）

リソースがTerraform管理外になっている場合。

```bash
# 既存リソースをインポート
terraform import module.s3.aws_s3_bucket.image_maps kishax-production-image-maps
```

### 3. 手動でバックアップしてから再作成

どうしても再作成が必要な場合。

```bash
# 1. データのバックアップ（S3の例）
aws s3 sync s3://kishax-production-image-maps/ ./backup-image-maps/

# 2. terraform apply（再作成）
terraform apply

# 3. データのリストア
aws s3 sync ./backup-image-maps/ s3://kishax-production-image-maps/
```

---

## 📋 実践例：S3バケットのtainted対処

### 問題の発見

```bash
cd terraform
terraform plan

# 出力：
# module.s3.aws_s3_bucket.image_maps is tainted, so must be replaced
# -/+ resource "aws_s3_bucket" "image_maps"
#     - 既存バケット削除
#     + 新規バケット作成
#     → 全データ消失！
```

### 対処手順

```bash
# 1. taintedを解除
terraform untaint module.s3.aws_s3_bucket.image_maps

# 2. 再度planで確認
terraform plan

# 期待される出力：
# ~ resource "aws_s3_bucket" "image_maps"  # 更新のみ
#   ~ tags = {
#       + "Purpose" = "Minecraft image maps storage - persistent"
#     }
# ✅ 削除・再作成なし！

# 3. 安全に適用
terraform apply
```

---

## 🛡️ 予防策

### 1. 常にterraform planを実行

```bash
# applyの前に必ずplanで確認
terraform plan

# -/+ が出ていないか確認
# 特にS3バケット、RDS、EBSボリュームなど
```

### 2. terraform.tfstateのバックアップ

```bash
# S3バックエンドを使用
terraform {
  backend "s3" {
    bucket         = "kishax-terraform-state"
    key            = "infrastructure/terraform.tfstate"
    region         = "ap-northeast-1"
    encrypt        = true
    dynamodb_table = "kishax-terraform-locks"
  }
}
```

### 3. 重要なリソースにライフサイクル設定

```hcl
resource "aws_s3_bucket" "important_data" {
  bucket = "kishax-important-data"

  lifecycle {
    prevent_destroy = true  # 削除を防止
  }
}
```

### 4. Terraform実行前のチェックリスト

- [ ] `terraform plan`を実行した
- [ ] `-/+` (削除・再作成) がないことを確認した
- [ ] S3、RDS、EBSなどデータを持つリソースに変更がないか確認した
- [ ] 変更内容が期待通りか確認した

---

## 🚨 緊急時の対応

### 誤ってapplyしてリソースが削除された場合

#### S3バケットの場合

1. **バージョニングが有効な場合**
   ```bash
   # 削除されたオブジェクトを復元
   aws s3api list-object-versions --bucket kishax-production-image-maps
   ```

2. **バックアップから復元**
   ```bash
   aws s3 sync s3://backup-bucket/ s3://kishax-production-image-maps/
   ```

#### RDSの場合

1. **自動バックアップから復元**
   ```bash
   # スナップショットから復元
   aws rds restore-db-instance-from-db-snapshot \
     --db-instance-identifier kishax-production-mysql-restored \
     --db-snapshot-identifier kishax-production-mysql-snapshot-latest
   ```

2. **ポイントインタイムリカバリ**
   ```bash
   aws rds restore-db-instance-to-point-in-time \
     --source-db-instance-identifier kishax-production-mysql \
     --target-db-instance-identifier kishax-production-mysql-restored \
     --restore-time 2024-12-15T10:00:00Z
   ```

---

## 📚 関連コマンド

### リソースのtaint状態を操作

```bash
# taintedにする（再作成を強制）
terraform taint module.s3.aws_s3_bucket.example

# taintedを解除（再作成を回避）
terraform untaint module.s3.aws_s3_bucket.example

# tainted状態の確認
terraform show | grep tainted

# 全リソースの状態確認
terraform state list
```

### リソースのインポート

```bash
# 既存リソースをTerraformに取り込む
terraform import <リソースタイプ>.<リソース名> <AWS リソースID>

# 例：S3バケット
terraform import module.s3.aws_s3_bucket.image_maps kishax-production-image-maps

# 例：RDS
terraform import module.rds.aws_db_instance.mysql db-instance-identifier
```

---

## ✅ ベストプラクティス

1. **本番環境では必ず`terraform plan`を実行**
2. **`-/+`が出たら立ち止まって原因を調査**
3. **データを持つリソースは特に慎重に**
4. **terraform.tfstateは定期的にバックアップ**
5. **重要なリソースには`prevent_destroy`を設定**
6. **変更前にAWSコンソールでリソースの状態を確認**

---

## 参考資料

- [Terraform - Resource Lifecycle](https://www.terraform.io/docs/language/meta-arguments/lifecycle.html)
- [Terraform - State Command](https://www.terraform.io/docs/cli/commands/state/index.html)
- [Terraform - Import](https://www.terraform.io/docs/cli/import/index.html)

---

**最終更新:** 2024年12月15日
