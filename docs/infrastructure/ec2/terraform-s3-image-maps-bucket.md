# Terraform更新: 画像マップ専用S3バケット追加

## 概要

画像マップ保存用に専用のS3バケット `kishax-production-image-maps` を新規作成しました。

## 変更理由

Dockerイメージバケット（`kishax-production-docker-images`）は30日で自動削除されるライフサイクルポリシーがあるため、永続保存が必要な画像マップとは分離する必要があります。

## 変更内容

### 1. 新規S3バケット作成

**ファイル**: `terraform/modules/s3/main.tf`

```hcl
resource "aws_s3_bucket" "image_maps" {
  bucket = "kishax-${var.environment}-image-maps"
  
  tags = {
    Name        = "kishax-${var.environment}-image-maps"
    Environment = var.environment
    Purpose     = "Minecraft image maps storage (persistent)"
  }
}
```

**特徴**:
- ✅ バージョニング有効
- ✅ サーバーサイド暗号化（AES256）
- ✅ パブリックアクセスブロック
- ✅ ライフサイクルポリシー: **なし（永続保存）**
- ✅ VPCエンドポイント経由のみアクセス許可

### 2. S3モジュール outputs 追加

**ファイル**: `terraform/modules/s3/outputs.tf`

```hcl
output "image_maps_bucket_name" {
  description = "S3 bucket name for image maps"
  value       = aws_s3_bucket.image_maps.id
}

output "image_maps_bucket_arn" {
  description = "S3 bucket ARN for image maps"
  value       = aws_s3_bucket.image_maps.arn
}

output "image_maps_bucket_regional_domain_name" {
  description = "S3 bucket regional domain name for image maps"
  value       = aws_s3_bucket.image_maps.bucket_regional_domain_name
}
```

### 3. IAMモジュール更新

**ファイル**: `terraform/modules/iam/variables.tf`

新規変数追加:
```hcl
variable "s3_image_maps_bucket_arn" {
  description = "S3 bucket ARN for image maps"
  type        = string
}
```

**ファイル**: `terraform/modules/iam/main.tf`

MC Server S3ポリシーに新バケットへのアクセス追加:
```hcl
resource "aws_iam_role_policy" "mc_server_s3" {
  # ...
  Resource = [
    var.s3_docker_images_bucket_arn,
    "${var.s3_docker_images_bucket_arn}/*",
    var.s3_image_maps_bucket_arn,      # 追加
    "${var.s3_image_maps_bucket_arn}/*" # 追加
  ]
}
```

### 4. メイン設定更新

**ファイル**: `terraform/main.tf`

IAMモジュール呼び出しに新バケットARN追加:
```hcl
module "iam" {
  # ...
  s3_docker_images_bucket_arn = module.s3.bucket_arn
  s3_image_maps_bucket_arn    = module.s3.image_maps_bucket_arn  # 追加
}
```

**ファイル**: `terraform/outputs.tf`

ルートoutputsに新バケット情報追加:
```hcl
output "s3_image_maps_bucket_name" {
  description = "S3 bucket name for image maps"
  value       = module.s3.image_maps_bucket_name
}

output "s3_image_maps_bucket_arn" {
  description = "S3 bucket ARN for image maps"
  value       = module.s3.image_maps_bucket_arn
}
```

## バケット比較表

| 項目 | Dockerイメージバケット | 画像マップバケット |
|------|---------------------|------------------|
| バケット名 | `kishax-production-docker-images` | `kishax-production-image-maps` |
| 用途 | Dockerイメージ、ワールドデータ | 画像マップ（永続） |
| ライフサイクル | 30日で自動削除 | 永続保存（削除なし） |
| アクセス元 | 全EC2インスタンス | MC Server (i-a) のみ |
| 暗号化 | AES256 | AES256 |
| バージョニング | 有効 | 有効 |

## デプロイ手順

### 1. Terraform初期化

```bash
cd /Users/tk/git/Kishax/infrastructure/terraform

# 変更を確認（新しいバケットが作成される）
terraform plan

# 出力例:
# + aws_s3_bucket.image_maps
# + aws_s3_bucket_public_access_block.image_maps
# + aws_s3_bucket_versioning.image_maps
# + aws_s3_bucket_server_side_encryption_configuration.image_maps
# + aws_s3_bucket_policy.image_maps
# ~ aws_iam_role_policy.mc_server_s3 (Resource配列に新バケット追加)
```

### 2. 適用

```bash
terraform apply

# 確認プロンプトで "yes" を入力
```

### 3. バケット名を確認

```bash
# 画像マップバケット名を取得
terraform output s3_image_maps_bucket_name
# 出力: kishax-production-image-maps

# バケットARNを取得
terraform output s3_image_maps_bucket_arn
# 出力: arn:aws:s3:::kishax-production-image-maps
```

### 4. MySQL設定を更新

```bash
# S3設定SQLを実行（バケット名が更新済み）
# .bak/db/mc/s3_image_storage_settings.sql

# デフォルトバケット名: kishax-production-image-maps
```

## 影響範囲

### 既存リソースへの影響

- ✅ **既存のDockerイメージバケットには影響なし**
- ✅ **既存のIAMロールにリソースが追加されるのみ**
- ✅ **ダウンタイムなし**

### 新規リソース

1. S3バケット: `kishax-production-image-maps`
2. S3バケットポリシー
3. S3バケット暗号化設定
4. S3バケットバージョニング設定
5. S3パブリックアクセスブロック設定

### 変更されるリソース

1. IAMロール `kishax-production-mc-server-role` のS3ポリシー
   - Resourceリストに新バケットARNが追加される

## コスト見積もり

### ストレージコスト（S3 Standard - ap-northeast-1）

| 項目 | 単価 | 想定容量 | 月額コスト |
|------|------|---------|----------|
| ストレージ | $0.025/GB | 10GB | $0.25 |
| PUT/COPY/POST | $0.0047/1000リクエスト | 10,000リクエスト | $0.047 |
| GET/SELECT | $0.00037/1000リクエスト | 50,000リクエスト | $0.019 |
| **合計** | - | - | **約$0.32/月** |

### データ転送コスト

- VPCエンドポイント経由のため**無料**
- S3 → EC2間の転送は課金されません

### その他

- バージョニング: 使用量に応じて追加コスト
- リクエストコスト: プレイヤー数に依存

## ロールバック手順

万が一問題が発生した場合：

```bash
# Terraformで新バケットを削除
cd /Users/tk/git/Kishax/infrastructure/terraform

# バケット内のデータを削除（空でないとdestroy不可）
aws s3 rm s3://kishax-production-image-maps --recursive --profile AdministratorAccess-126112056177

# Terraformでリソースを削除
terraform destroy -target=module.s3.aws_s3_bucket.image_maps
terraform destroy -target=module.s3.aws_s3_bucket_public_access_block.image_maps
# ... (他の関連リソース)

# または、main.tfから該当リソースを削除してapply
```

## テスト項目

デプロイ後、以下を確認：

- [ ] S3バケットが作成されている
- [ ] バケットポリシーが正しく設定されている
- [ ] MC ServerのIAMロールに権限が追加されている
- [ ] Terraformのoutputで新バケット名が取得できる
- [ ] i-aから新バケットへのアクセスが可能
- [ ] MySQL設定でバケット名が正しく設定されている

## 参考資料

- [terraform/modules/s3/main.tf](../terraform/modules/s3/main.tf)
- [terraform/modules/iam/main.tf](../terraform/modules/iam/main.tf)
- [deployment.md - 3-6節](./deployment.md#3-6-s3画像ストレージ設定minecraft-image-maps)
- [s3-image-storage-implementation-summary.md](./s3-image-storage-implementation-summary.md)


