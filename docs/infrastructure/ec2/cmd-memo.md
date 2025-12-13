```bash
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
```