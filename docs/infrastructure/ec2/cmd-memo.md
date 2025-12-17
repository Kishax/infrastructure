```bash
aws sso login --profile AdministratorAccess-126112056177

# i-b (Jump Server) を再起動
aws ec2 reboot-instances \
  --instance-ids $INSTANCE_ID_D \
  --profile AdministratorAccess-126112056177

# i-b (API Server) を再起動
aws ec2 reboot-instances \
  --instance-ids $INSTANCE_ID_B \
  --profile AdministratorAccess-126112056177

# i-c (Web Server) も同様に
aws ec2 reboot-instances \
  --instance-ids $INSTANCE_ID_C \
  --profile AdministratorAccess-126112056177

# i-a (MC Server) も同様に
aws ec2 reboot-instances \
  --instance-ids $INSTANCE_ID_A \
  --profile AdministratorAccess-126112056177

# i-aにSSM接続
aws ssm start-session --target $INSTANCE_ID_A --profile AdministratorAccess-126112056177

# i-a上で実行
IMAGE_DIR="/opt/mc/spigot/world/data/images"
S3_BUCKET="kishax-production-image-maps"
S3_PREFIX="images/"

# ドライラン（確認のみ）
aws s3 sync $IMAGE_DIR/ s3://$S3_BUCKET/$S3_PREFIX --dryrun

# 本番実行
aws s3 sync $IMAGE_DIR/ s3://$S3_BUCKET/$S3_PREFIX
```