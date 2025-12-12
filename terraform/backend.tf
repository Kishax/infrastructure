# Terraform Backend Configuration
# S3 + DynamoDB for remote state management and locking

terraform {
  backend "s3" {
    bucket         = "kishax-terraform-state"
    key            = "infrastructure/terraform.tfstate"
    region         = "ap-northeast-1"
    encrypt        = true
    dynamodb_table = "kishax-terraform-locks"
    
    # プロファイル指定（ローカル開発用）
    # CI/CD環境ではIAMロールを使用
    profile = "AdministratorAccess-126112056177"
  }
}

# Note: 初回実行前にS3バケットとDynamoDBテーブルを作成する必要があります
# 
# S3バケット作成:
#   aws s3api create-bucket \
#     --bucket kishax-terraform-state \
#     --region ap-northeast-1 \
#     --create-bucket-configuration LocationConstraint=ap-northeast-1 \
#     --profile AdministratorAccess-126112056177
#
#   aws s3api put-bucket-versioning \
#     --bucket kishax-terraform-state \
#     --versioning-configuration Status=Enabled \
#     --profile AdministratorAccess-126112056177
#
#   aws s3api put-bucket-encryption \
#     --bucket kishax-terraform-state \
#     --server-side-encryption-configuration '{
#       "Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]
#     }' \
#     --profile AdministratorAccess-126112056177
#
# DynamoDBテーブル作成:
#   aws dynamodb create-table \
#     --table-name kishax-terraform-locks \
#     --attribute-definitions AttributeName=LockID,AttributeType=S \
#     --key-schema AttributeName=LockID,KeyType=HASH \
#     --billing-mode PAY_PER_REQUEST \
#     --region ap-northeast-1 \
#     --profile AdministratorAccess-126112056177
