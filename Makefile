# Kishax Infrastructure Makefile
# Terraform + EC2環境用

.PHONY: help
help: ## ヘルプを表示
	@echo "Kishax Infrastructure Makefile (Terraform + EC2)"
	@echo ""
	@echo "利用可能なコマンド:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  \033[36m%-25s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

## =============================================================================
## AWS認証
## =============================================================================

.PHONY: login
login: ## AWS SSOログイン
	@echo "🔐 AWS SSOログイン中..."
	aws sso login --profile AdministratorAccess-126112056177

.PHONY: whoami
whoami: ## 現在のAWS認証情報を確認
	@echo "👤 現在のAWS認証情報:"
	aws sts get-caller-identity --profile AdministratorAccess-126112056177

## =============================================================================
## Git関連
## =============================================================================

.PHONY: sync
sync: ## Gitサブモジュールを最新に同期
	@echo "🔄 Gitサブモジュール同期中..."
	git submodule update --remote --merge

.PHONY: submodule-init
submodule-init: ## Gitサブモジュールを初期化
	@echo "🔧 Gitサブモジュール初期化中..."
	git submodule update --init --recursive

## =============================================================================
## Terraform
## =============================================================================

.PHONY: tf-init
tf-init: ## Terraformを初期化
	@echo "🔧 Terraform初期化中..."
	cd terraform && terraform init

.PHONY: tf-plan
tf-plan: ## Terraformプランを生成
	@echo "📝 Terraformプラン生成中..."
	cd terraform && terraform plan -out=tfplan

.PHONY: tf-apply
tf-apply: ## Terraformプランを適用
	@echo "🚀 Terraformプラン適用中..."
	cd terraform && terraform apply tfplan

.PHONY: tf-apply-auto
tf-apply-auto: ## Terraformプランを自動承認で適用
	@echo "🚀 Terraformプラン適用中（自動承認）..."
	cd terraform && terraform apply -auto-approve

.PHONY: tf-destroy
tf-destroy: ## Terraformリソースを削除
	@echo "⚠️  Terraformリソース削除中..."
	@read -p "本当に削除しますか？ [y/N]: " confirm && [ "$$confirm" = "y" ] || exit 1
	cd terraform && terraform destroy

.PHONY: tf-output
tf-output: ## Terraform出力を表示
	@echo "📊 Terraform出力:"
	cd terraform && terraform output

.PHONY: tf-fmt
tf-fmt: ## Terraformファイルをフォーマット
	@echo "✨ Terraformファイルフォーマット中..."
	cd terraform && terraform fmt -recursive

.PHONY: tf-validate
tf-validate: ## Terraformファイルを検証
	@echo "✅ Terraformファイル検証中..."
	cd terraform && terraform validate

## =============================================================================
## EC2管理
## =============================================================================

.PHONY: ec2-list
ec2-list: ## EC2インスタンス一覧を表示
	@echo "📋 EC2インスタンス一覧:"
	aws ec2 describe-instances \
		--profile AdministratorAccess-126112056177 \
		--query 'Reservations[*].Instances[*].[Tags[?Key==`Name`].Value|[0],InstanceId,InstanceType,State.Name,PublicIpAddress,PrivateIpAddress]' \
		--output table

.PHONY: ec2-connect-api
ec2-connect-api: ## i-b (API Server)にSSM接続
	@echo "🔗 i-b (API Server)に接続中..."
	@INSTANCE_ID=$$(cd terraform && terraform output -raw api_server_id 2>/dev/null); \
	if [ -z "$$INSTANCE_ID" ]; then \
		echo "❌ API ServerのインスタンスIDが取得できませんでした"; \
		exit 1; \
	fi; \
	aws ssm start-session --target $$INSTANCE_ID --profile AdministratorAccess-126112056177

.PHONY: ec2-connect-web
ec2-connect-web: ## i-c (Web Server)にSSM接続
	@echo "🔗 i-c (Web Server)に接続中..."
	@INSTANCE_ID=$$(cd terraform && terraform output -raw web_server_id 2>/dev/null); \
	if [ -z "$$INSTANCE_ID" ]; then \
		echo "❌ Web ServerのインスタンスIDが取得できませんでした"; \
		exit 1; \
	fi; \
	aws ssm start-session --target $$INSTANCE_ID --profile AdministratorAccess-126112056177

.PHONY: ec2-connect-mc
ec2-connect-mc: ## i-a (MC Server)にSSM接続
	@echo "🔗 i-a (MC Server)に接続中..."
	@INSTANCE_ID=$$(cd terraform && terraform output -raw mc_server_id 2>/dev/null); \
	if [ -z "$$INSTANCE_ID" ]; then \
		echo "❌ MC ServerのインスタンスIDが取得できませんでした"; \
		exit 1; \
	fi; \
	aws ssm start-session --target $$INSTANCE_ID --profile AdministratorAccess-126112056177

.PHONY: ec2-connect-jump
ec2-connect-jump: ## i-d (Jump Server)にSSM接続
	@echo "🔗 i-d (Jump Server)に接続中..."
	@INSTANCE_ID=$$(cd terraform && terraform output -raw jump_server_id 2>/dev/null); \
	if [ -z "$$INSTANCE_ID" ]; then \
		echo "❌ Jump ServerのインスタンスIDが取得できませんでした"; \
		exit 1; \
	fi; \
	aws ssm start-session --target $$INSTANCE_ID --profile AdministratorAccess-126112056177

.PHONY: ec2-start-mc
ec2-start-mc: ## i-a (MC Server)を起動
	@echo "▶️  i-a (MC Server)起動中..."
	@INSTANCE_ID=$$(cd terraform && terraform output -raw mc_server_id 2>/dev/null); \
	aws ec2 start-instances --instance-ids $$INSTANCE_ID --profile AdministratorAccess-126112056177

.PHONY: ec2-stop-mc
ec2-stop-mc: ## i-a (MC Server)を停止
	@echo "⏹️  i-a (MC Server)停止中..."
	@INSTANCE_ID=$$(cd terraform && terraform output -raw mc_server_id 2>/dev/null); \
	aws ec2 stop-instances --instance-ids $$INSTANCE_ID --profile AdministratorAccess-126112056177

.PHONY: ec2-start-jump
ec2-start-jump: ## i-d (Jump Server)を起動
	@echo "▶️  i-d (Jump Server)起動中..."
	@INSTANCE_ID=$$(cd terraform && terraform output -raw jump_server_id 2>/dev/null); \
	aws ec2 start-instances --instance-ids $$INSTANCE_ID --profile AdministratorAccess-126112056177

.PHONY: ec2-stop-jump
ec2-stop-jump: ## i-d (Jump Server)を停止
	@echo "⏹️  i-d (Jump Server)停止中..."
	@INSTANCE_ID=$$(cd terraform && terraform output -raw jump_server_id 2>/dev/null); \
	aws ec2 stop-instances --instance-ids $$INSTANCE_ID --profile AdministratorAccess-126112056177

## =============================================================================
## RDS管理
## =============================================================================

.PHONY: rds-status
rds-status: ## RDSインスタンスのステータス確認
	@echo "📊 RDSステータス:"
	aws rds describe-db-instances \
		--profile AdministratorAccess-126112056177 \
		--query 'DBInstances[*].[DBInstanceIdentifier,DBInstanceStatus,Engine,DBInstanceClass,Endpoint.Address]' \
		--output table

.PHONY: rds-connect-postgres
rds-connect-postgres: ## RDS PostgreSQLにポートフォワード接続
	@echo "🔗 RDS PostgreSQLに接続中（ローカルポート5433）..."
	@INSTANCE_ID=$$(cd terraform && terraform output -raw jump_server_id 2>/dev/null); \
	RDS_ENDPOINT=$$(cd terraform && terraform output -raw rds_postgres_endpoint 2>/dev/null); \
	aws ssm start-session \
		--target $$INSTANCE_ID \
		--document-name AWS-StartPortForwardingSessionToRemoteHost \
		--parameters "{\"portNumber\":[\"5432\"],\"localPortNumber\":[\"5433\"],\"host\":[\"$$RDS_ENDPOINT\"]}" \
		--profile AdministratorAccess-126112056177

.PHONY: rds-connect-mysql
rds-connect-mysql: ## RDS MySQLにポートフォワード接続
	@echo "🔗 RDS MySQLに接続中（ローカルポート3307）..."
	@INSTANCE_ID=$$(cd terraform && terraform output -raw jump_server_id 2>/dev/null); \
	RDS_ENDPOINT=$$(cd terraform && terraform output -raw rds_mysql_endpoint 2>/dev/null); \
	aws ssm start-session \
		--target $$INSTANCE_ID \
		--document-name AWS-StartPortForwardingSessionToRemoteHost \
		--parameters "{\"portNumber\":[\"3306\"],\"localPortNumber\":[\"3307\"],\"host\":[\"$$RDS_ENDPOINT\"]}" \
		--profile AdministratorAccess-126112056177

## =============================================================================
## SQS管理
## =============================================================================

.PHONY: sqs-list
sqs-list: ## SQSキュー一覧を表示
	@echo "📋 SQSキュー一覧:"
	aws sqs list-queues --profile AdministratorAccess-126112056177

.PHONY: sqs-status
sqs-status: ## SQSキューのメッセージ数を確認
	@echo "📊 SQSキューのステータス:"
	@TO_WEB_QUEUE=$$(cd terraform && terraform output -raw to_web_queue_url 2>/dev/null); \
	TO_MC_QUEUE=$$(cd terraform && terraform output -raw to_mc_queue_url 2>/dev/null); \
	TO_DISCORD_QUEUE=$$(cd terraform && terraform output -raw to_discord_queue_url 2>/dev/null); \
	echo "To Web Queue:"; \
	aws sqs get-queue-attributes --queue-url $$TO_WEB_QUEUE --attribute-names ApproximateNumberOfMessages --profile AdministratorAccess-126112056177; \
	echo "To MC Queue:"; \
	aws sqs get-queue-attributes --queue-url $$TO_MC_QUEUE --attribute-names ApproximateNumberOfMessages --profile AdministratorAccess-126112056177; \
	echo "To Discord Queue:"; \
	aws sqs get-queue-attributes --queue-url $$TO_DISCORD_QUEUE --attribute-names ApproximateNumberOfMessages --profile AdministratorAccess-126112056177

## =============================================================================
## CloudFront管理
## =============================================================================

.PHONY: cf-status
cf-status: ## CloudFrontディストリビューションのステータス確認
	@echo "📊 CloudFrontステータス:"
	aws cloudfront list-distributions \
		--profile AdministratorAccess-126112056177 \
		--query 'DistributionList.Items[*].[Id,Status,DomainName,Comment]' \
		--output table

.PHONY: cf-invalidate
cf-invalidate: ## CloudFrontキャッシュを削除
	@echo "🔄 CloudFrontキャッシュ削除中..."
	@DIST_ID=$$(cd terraform && terraform output -raw cloudfront_distribution_id 2>/dev/null); \
	aws cloudfront create-invalidation \
		--distribution-id $$DIST_ID \
		--paths "/*" \
		--profile AdministratorAccess-126112056177

## =============================================================================
## Route53管理
## =============================================================================

.PHONY: route53-list
route53-list: ## Route53レコード一覧を表示
	@echo "📋 Route53レコード一覧:"
	@ZONE_ID=$$(cd terraform && terraform output -raw route53_zone_id 2>/dev/null); \
	aws route53 list-resource-record-sets \
		--hosted-zone-id $$ZONE_ID \
		--profile AdministratorAccess-126112056177 \
		--output table

## =============================================================================
## 監視・ステータス確認
## =============================================================================

.PHONY: billing-current
billing-current: ## 現在の課金量を確認（今月）
	@echo "💰 AWS課金情報を取得中..."
	@START_DATE=$$(date +"%Y-%m-01"); \
	END_DATE=$$(date -v+1d +"%Y-%m-%d" 2>/dev/null || date -d "tomorrow" +"%Y-%m-%d"); \
	echo "📊 課金情報 ($$START_DATE から $$END_DATE まで):"; \
	aws ce get-cost-and-usage \
		--time-period Start=$$START_DATE,End=$$END_DATE \
		--granularity DAILY \
		--metrics UnblendedCost \
		--profile AdministratorAccess-126112056177 \
		--output table

.PHONY: status-all
status-all: ## 全リソースのステータスを確認
	@echo "🔍 全リソースのステータス確認中..."
	@echo ""
	@$(MAKE) ec2-list
	@echo ""
	@$(MAKE) rds-status
	@echo ""
	@$(MAKE) cf-status

## =============================================================================
## SSM Parameter Store
## =============================================================================

.PHONY: ssm-list
ssm-list: ## SSM Parameter Store一覧を表示
	@echo "📋 SSM Parameter Store一覧:"
	aws ssm describe-parameters \
		--profile AdministratorAccess-126112056177 \
		--query 'Parameters[*].[Name,Type,LastModifiedDate]' \
		--output table

.PHONY: ssm-get
ssm-get: ## SSM Parameterの値を取得 (usage: make ssm-get PARAM=/path/to/param)
	@if [ -z "$(PARAM)" ]; then \
		echo "❌ PARAM変数を指定してください: make ssm-get PARAM=/path/to/param"; \
		exit 1; \
	fi
	@echo "🔍 SSM Parameter取得中: $(PARAM)"
	aws ssm get-parameter \
		--name "$(PARAM)" \
		--with-decryption \
		--profile AdministratorAccess-126112056177 \
		--query 'Parameter.Value' \
		--output text

## =============================================================================
## クリーンアップ
## =============================================================================

.PHONY: clean
clean: ## ローカルの一時ファイルを削除
	@echo "🧹 一時ファイル削除中..."
	rm -rf terraform/.terraform
	rm -f terraform/tfplan
	rm -f terraform/.terraform.lock.hcl
	@echo "✅ クリーンアップ完了"
