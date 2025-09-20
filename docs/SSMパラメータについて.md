以下のようなIAMポリシーを作成し、様々なECSサービスにアタッチしてSSMパラメータへのアクセスを許可します。
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowKishaxSSMParameterAccess",
      "Effect": "Allow",
      "Action": [
        "ssm:GetParameters",
        "ssm:GetParameter"
      ],
      "Resource": [
        "arn:aws:ssm:$(AWS_REGION):$(AWS_ACCOUNT_ID):parameter/kishax/discord/*",
        "arn:aws:ssm:$(AWS_REGION):$(AWS_ACCOUNT_ID):parameter/kishax/sqs/*",
        "arn:aws:ssm:$(AWS_REGION):$(AWS_ACCOUNT_ID):parameter/kishax/slack/*",
        "arn:aws:ssm:$(AWS_REGION):$(AWS_ACCOUNT_ID):parameter/kishax/web/*"
      ]
    }
  ]
}
```
