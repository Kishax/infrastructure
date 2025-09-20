# Kishax Infrastructure Makefile

include .env

# ECRリポジトリ
AWS_ECR_DISCORD_BOT := $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/$(AWS_ECR_REPO_DISCORD_BOT_NAME)
AWS_ECR_GATHER_BOT := $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/$(AWS_ECR_REPO_GATHER_BOT_NAME)
AWS_ECR_WEB := $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/$(AWS_ECR_REPO_WEB_BOT_NAME)
AWS_ECR_AUTH := $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/$(AWS_ECR_REPO_AUTH_NAME)
AWS_ECR_API := $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/$(AWS_ECR_REPO_API_NAME)

.PHONY: help
help: ## ヘルプを表示
	@echo "Infrastructure Makefile"
	@echo ""
	@echo "利用可能なコマンド:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)


## =============================================================================
## Git関連
## =============================================================================
.PHONY: sync
sync: ## Gitサブモジュールを最新に同期
	@echo "🔄 Gitサブモジュール同期中..."
	git submodule update --remote --merge

## =============================================================================
## その他
## =============================================================================
.PHONY: test-auth
test-auth:
	curl -s -o /dev/null -w "%{http_code}\n" "https://auth.kishax.net"

## =============================================================================
## ログイン
## =============================================================================
.PHONY: login
login: ## AWS SSOログイン
	@echo "🔐 AWS SSOログイン中..."
	aws sso login --profile $(AWS_PROFILE)

## =============================================================================
## RDS
## =============================================================================
.PHONY: rds-connect
rds-connect: ## RDSに接続 (psql)
	@echo "🔗 RDSに接続中..."
	aws ssm start-session \
		--target "$(AWS_RDS_JUMP_EC2_INSTANCE_ID)" \
		--document-name AWS-StartPortForwardingSessionToRemoteHost \
		--parameters '{ "portNumber":["5432"], "localPortNumber":["5433"], "host":["$(AWS_RDS_HOST)"] }' \
		--profile $(AWS_PROFILE)

.PHONY: rds-stop
rds-stop: ## RDS Jump EC2インスタンスを停止
	@echo "⏹️ RDS Jump EC2インスタンスを停止中..."
	aws ec2 stop-instances --instance-ids $(AWS_RDS_JUMP_EC2_INSTANCE_ID) --profile $(AWS_PROFILE)
	@echo "✅ RDS Jump EC2インスタンスの停止を要求しました"

.PHONY: rds-start
rds-start: ## RDS Jump EC2インスタンスを開始
	@echo "▶️ RDS Jump EC2インスタンスを開始中..."
	aws ec2 start-instances --instance-ids $(AWS_RDS_JUMP_EC2_INSTANCE_ID) --profile $(AWS_PROFILE)
	@echo "✅ RDS Jump EC2インスタンスの開始を要求しました"

.PHONY: rds-restart
rds-restart: ## RDS Jump EC2インスタンスを再起動
	@echo "🔄 RDS Jump EC2インスタンスを再起動中..."
	aws ec2 reboot-instances --instance-ids $(AWS_RDS_JUMP_EC2_INSTANCE_ID) --profile $(AWS_PROFILE)
	@echo "✅ RDS Jump EC2インスタンスの再起動を要求しました"

.PHONY: status-rds-jump-ec2
status-rds-jump-ec2: ## RDS Jump EC2インスタンスのステータスを確認
	@echo "📊 RDS Jump EC2インスタンスのステータス確認中..."
	aws ec2 describe-instances \
		--instance-ids $(AWS_RDS_JUMP_EC2_INSTANCE_ID) \
		--profile $(AWS_PROFILE) \
		--query 'Reservations[0].Instances[0].{InstanceId:InstanceId,State:State.Name,InstanceType:InstanceType,PublicIpAddress:PublicIpAddress,PrivateIpAddress:PrivateIpAddress,LaunchTime:LaunchTime}' \
		--output table

.PHONY: rds-reset-auth
rds-reset-auth:
	@echo "🔄 RDSのkeycloakデータベースをリセット中..."
	export PGPASSWORD=$(AWS_RDS_MASTER_PASSWORD) && \
	psql -h localhost -p 5433 -U postgres -c "SELECT pg_terminate_backend(pg_stat_activity.pid) FROM pg_stat_activity WHERE pg_stat_activity.datname = 'keycloak' AND pid <> pg_backend_pid();" && \
	psql -h localhost -p 5433 -U postgres -c "DROP DATABASE keycloak;" && \
	psql -h localhost -p 5433 -U postgres -c "CREATE DATABASE keycloak;"

## =============================================================================
## 監視・ステータス確認
## =============================================================================

.PHONY: billing-current
billing-current: ## 現在の課金量を確認（今月・先月）
	@echo "💰 AWS課金情報を取得中..."
	@START_DATE=$$(date -v-1m +"%Y-%m-01" 2>/dev/null || date -d "$(date +%Y-%m-01) -1 month" +"%Y-%m-01"); \
	END_DATE=$$(date +"%Y-%m-01"); \
	CURRENT_END_DATE=$$(date -v+1d +"%Y-%m-%d" 2>/dev/null || date -d "tomorrow" +"%Y-%m-%d"); \
	echo "📊 課金情報 ($$START_DATE から $$CURRENT_END_DATE まで):"; \
	aws ce get-cost-and-usage \
		--time-period Start=$$START_DATE,End=$$CURRENT_END_DATE \
		--granularity MONTHLY \
		--metrics BlendedCost \
		--group-by Type=DIMENSION,Key=SERVICE \
		--profile $(AWS_PROFILE) \
		--query 'ResultsByTime[*].{Period:TimePeriod.Start,TotalCost:Total.BlendedCost.Amount,Currency:Total.BlendedCost.Unit,Services:Groups[?Metrics.BlendedCost.Amount!=`0.0`].{Service:Keys[0],Cost:Metrics.BlendedCost.Amount}}' \
		--output table

.PHONY: billing-month-to-date
billing-month-to-date: ## 今月の累計課金額を確認（今日まで）
	@echo "💰 今月の累計課金額を取得中..."
	@THIS_MONTH_START=$$(date +"%Y-%m-01"); \
	TODAY_PLUS_1=$$(date -v+1d +"%Y-%m-%d" 2>/dev/null || date -d "tomorrow" +"%Y-%m-%d"); \
	echo "📊 今月累計課金額 ($$THIS_MONTH_START から今日まで):"; \
	TOTAL_COST=$$(aws ce get-cost-and-usage \
		--time-period Start=$$THIS_MONTH_START,End=$$TODAY_PLUS_1 \
		--granularity MONTHLY \
		--metrics BlendedCost \
		--profile $(AWS_PROFILE) \
		--query 'ResultsByTime[0].Total.BlendedCost.Amount' \
		--output text); \
	CURRENCY=$$(aws ce get-cost-and-usage \
		--time-period Start=$$THIS_MONTH_START,End=$$TODAY_PLUS_1 \
		--granularity MONTHLY \
		--metrics BlendedCost \
		--profile $(AWS_PROFILE) \
		--query 'ResultsByTime[0].Total.BlendedCost.Unit' \
		--output text); \
	echo "💵 合計: $$TOTAL_COST $$CURRENCY"; \
	echo ""; \
	echo "📋 サービス別詳細:"; \
	aws ce get-cost-and-usage \
		--time-period Start=$$THIS_MONTH_START,End=$$TODAY_PLUS_1 \
		--granularity MONTHLY \
		--metrics BlendedCost \
		--group-by Type=DIMENSION,Key=SERVICE \
		--profile $(AWS_PROFILE) \
		--query 'ResultsByTime[0].Groups[?Metrics.BlendedCost.Amount!=`0.0`].{Service:Keys[0],Cost:Metrics.BlendedCost.Amount,Currency:Metrics.BlendedCost.Unit}' \
		--output table

.PHONY: status-cloudformation
status-cloudformation: ## CloudFormationスタックステータスを確認
	@echo "📊 CloudFormationスタックステータス確認中..."
	aws cloudformation describe-stacks \
		--stack-name kishax-infrastructure \
		--profile $(AWS_PROFILE) \
		--query 'Stacks[0].{StackStatus:StackStatus,StackStatusReason:StackStatusReason,LastUpdatedTime:LastUpdatedTime}' \
		--output table
	@echo "📋 最新のスタックイベント:"
	aws cloudformation describe-stack-events \
		--stack-name kishax-infrastructure \
		--profile $(AWS_PROFILE) \
		--max-items 10 \
		--query 'StackEvents[].{Timestamp:Timestamp,LogicalResourceId:LogicalResourceId,ResourceStatus:ResourceStatus,ResourceStatusReason:ResourceStatusReason}' \
		--output table

.PHONY: status-services
status-services: ## ECSサービスステータスを確認
	@echo "🏃 ECSサービスステータス確認中..."
	aws ecs describe-services \
		--cluster kishax-infrastructure-cluster \
		--services kishax-discord-bot-service-v2 kishax-gather-bot-service-v2 kishax-web-service-v2 kishax-auth-service-v2 kishax-api-service-v2 \
		--profile $(AWS_PROFILE) \
		--query 'services[].{ServiceName:serviceName,DesiredCount:desiredCount,RunningCount:runningCount,Status:status}' \
		--output table

# =============================================================================
# サービス再起動 (force-new-deployment)
# =============================================================================

.PHONY: restart-discord
restart-discord: ## Discord Botサービスを再起動 (force-new-deployment)
	@scripts/ecs-service.sh restart kishax-discord-bot-service-v2 kishax-infrastructure-cluster $(AWS_PROFILE)

.PHONY: restart-gather-bot
restart-gather-bot: ## Gather Botサービスを再起動 (force-new-deployment)
	@scripts/ecs-service.sh restart kishax-gather-bot-service-v2 kishax-infrastructure-cluster $(AWS_PROFILE)

.PHONY: restart-web
restart-web: ## Webサービスを再起動 (force-new-deployment)
	@scripts/ecs-service.sh restart kishax-web-service-v2 kishax-infrastructure-cluster $(AWS_PROFILE)

.PHONY: restart-auth
restart-auth: ## Authサービスを再起動 (force-new-deployment)
	@scripts/ecs-service.sh restart kishax-auth-service-v2 kishax-infrastructure-cluster $(AWS_PROFILE)

.PHONY: restart-all-services
restart-all-services: restart-discord restart-gather-bot restart-web restart-auth ## 全ECSサービスを再起動 (force-new-deployment)
	@echo "✅ 全サービスの再起動を要求しました"

# =============================================================================
# サービス有効/無効化 (desired-count操作)
# =============================================================================

.PHONY: enable-discord
enable-discord: ## Discord Botサービスを有効化 (desired-count=1)
	@scripts/ecs-service.sh enable kishax-discord-bot-service-v2 kishax-infrastructure-cluster $(AWS_PROFILE)

.PHONY: enable-gather-bot
enable-gather-bot: ## Gather Botサービスを有効化 (desired-count=1)
	@scripts/ecs-service.sh enable kishax-gather-bot-service-v2 kishax-infrastructure-cluster $(AWS_PROFILE)

.PHONY: enable-web
enable-web: ## Webサービスを有効化 (desired-count=1)
	@scripts/ecs-service.sh enable kishax-web-service-v2 kishax-infrastructure-cluster $(AWS_PROFILE)

.PHONY: enable-auth
enable-auth: ## Authサービスを有効化 (desired-count=1)
	@scripts/ecs-service.sh enable kishax-auth-service-v2 kishax-infrastructure-cluster $(AWS_PROFILE)

.PHONY: enable-api
enable-api: ## APIサービスを有効化 (desired-count=1)
	@scripts/ecs-service.sh enable kishax-api-service-v2 kishax-infrastructure-cluster $(AWS_PROFILE)

.PHONY: enable-all-services
enable-all-services: enable-discord enable-gather-bot enable-web enable-auth enable-api ## 全ECSサービスを有効化
	@echo "✅ 全サービスの有効化を完了しました"

.PHONY: disable-discord
disable-discord: ## Discord Botサービスを無効化 (desired-count=0)
	@scripts/ecs-service.sh disable kishax-discord-bot-service-v2 kishax-infrastructure-cluster $(AWS_PROFILE)

.PHONY: disable-gather-bot
disable-gather-bot: ## Gather Botサービスを無効化 (desired-count=0)
	@scripts/ecs-service.sh disable kishax-gather-bot-service-v2 kishax-infrastructure-cluster $(AWS_PROFILE)

.PHONY: disable-web
disable-web: ## Webサービスを無効化 (desired-count=0)
	@scripts/ecs-service.sh disable kishax-web-service-v2 kishax-infrastructure-cluster $(AWS_PROFILE)

.PHONY: disable-auth
disable-auth: ## Authサービスを無効化 (desired-count=0)
	@scripts/ecs-service.sh disable kishax-auth-service-v2 kishax-infrastructure-cluster $(AWS_PROFILE)

.PHONY: disable-api
disable-api: ## APIサービスを無効化 (desired-count=0)
	@scripts/ecs-service.sh disable kishax-api-service-v2 kishax-infrastructure-cluster $(AWS_PROFILE)

.PHONY: disable-all-services
disable-all-services: disable-discord disable-gather-bot disable-web disable-auth disable-api ## 全ECSサービスを無効化
	@echo "✅ 全サービスの無効化を完了しました"

# =============================================================================
# サービス開始/停止 (タスク操作)
# =============================================================================

.PHONY: start-discord
start-discord: ## Discord Bot停止中サービスを開始
	@scripts/ecs-service.sh start kishax-discord-bot-service-v2 kishax-infrastructure-cluster $(AWS_PROFILE)

.PHONY: start-gather-bot
start-gather-bot: ## Gather Bot停止中サービスを開始
	@scripts/ecs-service.sh start kishax-gather-bot-service-v2 kishax-infrastructure-cluster $(AWS_PROFILE)

.PHONY: start-web
start-web: ## Web停止中サービスを開始
	@scripts/ecs-service.sh start kishax-web-service-v2 kishax-infrastructure-cluster $(AWS_PROFILE)

.PHONY: start-auth
start-auth: ## Auth停止中サービスを開始
	@scripts/ecs-service.sh start kishax-auth-service-v2 kishax-infrastructure-cluster $(AWS_PROFILE)

.PHONY: start-all-services
start-all-services: start-discord start-gather-bot start-web start-auth ## 全停止中サービスを開始
	@echo "✅ 全サービスの開始チェックを完了しました"

.PHONY: stop-discord
stop-discord: ## Discord Bot実行中タスクを即座に停止
	@scripts/ecs-service.sh stop kishax-discord-bot-service-v2 kishax-infrastructure-cluster $(AWS_PROFILE)

.PHONY: stop-gather-bot
stop-gather-bot: ## Gather Bot実行中タスクを即座に停止
	@scripts/ecs-service.sh stop kishax-gather-bot-service-v2 kishax-infrastructure-cluster $(AWS_PROFILE)

.PHONY: stop-web
stop-web: ## Web実行中タスクを即座に停止
	@scripts/ecs-service.sh stop kishax-web-service-v2 kishax-infrastructure-cluster $(AWS_PROFILE)

.PHONY: stop-auth
stop-auth: ## Auth実行中タスクを即座に停止
	@scripts/ecs-service.sh stop kishax-auth-service-v2 kishax-infrastructure-cluster $(AWS_PROFILE)

.PHONY: stop-all-services
stop-all-services: stop-discord stop-gather-bot stop-web stop-auth ## 全実行中タスクを即座に停止
	@echo "✅ 全タスクの停止を完了しました"

.PHONY: cancel-stack-update
cancel-stack-update: ## CloudFormationスタック更新をキャンセル
	@echo "❌ CloudFormationスタック更新をキャンセル中..."
	aws cloudformation cancel-update-stack \
		--stack-name kishax-infrastructure \
		--profile $(AWS_PROFILE)
	@echo "✅ スタック更新のキャンセルを要求しました"

## =============================================================================
## デプロイメント
## =============================================================================

.PHONY: deploy-all
deploy-all: deploy-discord deploy-gather-bot deploy-web deploy-auth deploy-api ## 全サービスをデプロイ
	@echo "✅ 全サービスのデプロイが完了しました"

.PHONY: deploy-discord
deploy-discord: ## Discordをデプロイ
	@scripts/docker-deploy.sh discord $(AWS_ECR_DISCORD_BOT) kishax-infrastructure-cluster kishax-discord-bot-service-v2 $(AWS_PROFILE) $(AWS_REGION)

.PHONY: deploy-gather-bot
deploy-gather-bot: ## Gather Botをデプロイ
	@scripts/docker-deploy.sh gather $(AWS_ECR_GATHER_BOT) kishax-infrastructure-cluster kishax-gather-bot-service-v2 $(AWS_PROFILE) $(AWS_REGION)

.PHONY: deploy-web
deploy-web: ## Web アプリケーションをデプロイ
	@scripts/docker-deploy.sh web $(AWS_ECR_WEB) kishax-infrastructure-cluster kishax-web-service-v2 $(AWS_PROFILE) $(AWS_REGION)

.PHONY: deploy-auth
deploy-auth: ## Auth サービスをデプロイ
	@scripts/docker-deploy.sh auth $(AWS_ECR_AUTH) kishax-infrastructure-cluster kishax-auth-service-v2 $(AWS_PROFILE) $(AWS_REGION)

.PHONY: deploy-api
deploy-api: ## API サービスをデプロイ
	@scripts/docker-deploy.sh api $(AWS_ECR_API) kishax-infrastructure-cluster kishax-api-service-v2 $(AWS_PROFILE) $(AWS_REGION)

## =============================================================================
## SAML・認証関連
## =============================================================================

.PHONY: download-saml-metadata
download-saml-metadata: ## Keycloak SAML metadataをダウンロード
	@echo "📥 Keycloak SAML metadataをダウンロード中..."
	@echo "🌐 本番環境 (https://auth.kishax.net):"
	@curl -s "https://auth.kishax.net/realms/kishax/protocol/saml/descriptor" \
		-o /tmp/keycloak-saml-metadata-prod.xml && \
	echo "✅ 本番環境のmetadataを /tmp/keycloak-saml-metadata-prod.xml に保存しました" || \
	echo "❌ 本番環境のmetadata取得に失敗しました"
	@echo ""
	@echo "🖥️  ローカル環境 (http://localhost:3000):"
	@curl -s "http://localhost:3000/realms/kishax/protocol/saml/descriptor" \
		-o /tmp/keycloak-saml-metadata-local.xml && \
	echo "✅ ローカル環境のmetadataを /tmp/keycloak-saml-metadata-local.xml に保存しました" || \
	echo "❌ ローカル環境のmetadata取得に失敗しました (サービスが起動していない可能性があります)"

.PHONY: validate-saml-metadata
validate-saml-metadata: ## ダウンロードしたSAML metadataの内容を確認
	@echo "🔍 SAML metadataの内容確認..."
	@if [ -f /tmp/keycloak-saml-metadata-prod.xml ]; then \
		echo "📄 本番環境 metadata:"; \
		xmllint --format /tmp/keycloak-saml-metadata-prod.xml | head -20; \
		echo ""; \
	fi
	@if [ -f /tmp/keycloak-saml-metadata-local.xml ]; then \
		echo "📄 ローカル環境 metadata:"; \
		xmllint --format /tmp/keycloak-saml-metadata-local.xml | head -20; \
	fi

## =============================================================================
## テスト・動作確認
## =============================================================================

.PHONY: test-sqs-queues
test-sqs-queues: ## SQSキュー状態確認
	@echo "📊 SQS キュー状態確認中..."
	@echo ""
	@echo "📋 Web → MC キュー:"
	@aws sqs get-queue-attributes \
		--queue-url "https://sqs.$(AWS_REGION).amazonaws.com/$(AWS_ACCOUNT_ID)/kishax-web-to-mc-queue-v2" \
		--attribute-names ApproximateNumberOfMessages ApproximateNumberOfMessagesNotVisible \
		--profile $(AWS_PROFILE) \
		--query 'Attributes.{Messages:ApproximateNumberOfMessages,Processing:ApproximateNumberOfMessagesNotVisible}' \
		--output table
	@echo ""
	@echo "📋 MC → Web キュー:"
	@aws sqs get-queue-attributes \
		--queue-url "https://sqs.$(AWS_REGION).amazonaws.com/$(AWS_ACCOUNT_ID)/kishax-mc-to-web-queue-v2" \
		--attribute-names ApproximateNumberOfMessages ApproximateNumberOfMessagesNotVisible \
		--profile $(AWS_PROFILE) \
		--query 'Attributes.{Messages:ApproximateNumberOfMessages,Processing:ApproximateNumberOfMessagesNotVisible}' \
		--output table

## =============================================================================
## 監視・デバッグ
## =============================================================================

.PHONY: logs-discord
logs-discord: ## Discord Botログを表示
	aws logs tail /ecs/kishax-discord-bot-v2 --follow --profile $(AWS_PROFILE)

.PHONY: logs-gather-bot
logs-gather-bot: ## Gather Botログを表示
	aws logs tail /ecs/kishax-gather-bot-v2 --follow --profile $(AWS_PROFILE)

.PHONY: logs-web
logs-web: ## Web アプリケーションログを表示
	aws logs tail /ecs/kishax-web-v2 --follow --profile $(AWS_PROFILE)

.PHONY: status-ecs
status-ecs: ## ECSサービス状態を確認
	@echo "📊 ECSサービス状態:"
	@echo "\n🤖 Discord Bot:"
	aws ecs describe-services \
		--cluster kishax-infrastructure-cluster \
		--services kishax-discord-bot-service-v2 \
		--query 'services[0].{Status:status,Running:runningCount,Desired:desiredCount}' \
		--profile $(AWS_PROFILE)
	@echo "\n👥 Gather Bot:"
	aws ecs describe-services \
		--cluster kishax-infrastructure-cluster \
		--services kishax-gather-bot-service-v2 \
		--query 'services[0].{Status:status,Running:runningCount,Desired:desiredCount}' \
		--profile $(AWS_PROFILE)
	@echo "\n🌐 Web Application:"
	aws ecs describe-services \
		--cluster kishax-infrastructure-cluster \
		--services kishax-web-service-v2 \
		--query 'services[0].{Status:status,Running:runningCount,Desired:desiredCount}' \
		--profile $(AWS_PROFILE)

## =============================================================================
## 開発ツール
## =============================================================================

.PHONY: ssm-backup
ssm-backup: ## SSMパラメータをバックアップ
	@echo "💾 SSMパラメータをバックアップ中..."
	aws ssm get-parameters-by-path \
		--path "/kishax" \
		--recursive \
		--with-decryption \
		--profile $(AWS_PROFILE) \
		--query "Parameters[*].{Name:Name,Value:Value}" \
		--output json | \
	jq -r '.[] | "# " + .Name + "\n" + (.Name | gsub("/kishax/"; "") | gsub("/"; "_") | ascii_upcase) + "=" + .Value + "\n"' > .env.backup.new
	@echo "✅ SSMパラメータが .env.backup.new に保存されました"

.PHONY: validate-ssm
validate-ssm: ## SSMパラメータ設定を確認
	@echo "🔍 SSMパラメータ確認中..."
	aws ssm get-parameters-by-path \
		--path "/kishax" \
		--recursive \
		--profile $(AWS_PROFILE) \
		--query "Parameters[*].{Name:Name,Type:Type}" \
		--output table

## =============================================================================
## 環境設定
## =============================================================================

.PHONY: setup-aws-auth
setup-aws-auth: ## AWS認証設定ガイド表示
	@echo "🔐 AWS認証設定ガイド:"
	@echo ""
	@echo "1. AWS SSO ログイン:"
	@echo "   aws sso login --profile $(AWS_PROFILE)"
	@echo ""
	@echo "2. 認証状態確認:"
	@echo "   aws sts get-caller-identity --profile $(AWS_PROFILE)"

.PHONY: setup-prerequisites
setup-prerequisites: ## 前提条件チェック
	@echo "🔍 前提条件チェック中..."
	@command -v aws >/dev/null 2>&1 || { echo "❌ AWS CLI がインストールされていません"; exit 1; }
	@command -v docker >/dev/null 2>&1 || { echo "❌ Docker がインストールされていません"; exit 1; }
	@command -v node >/dev/null 2>&1 || { echo "❌ Node.js がインストールされていません"; exit 1; }
	@command -v java >/dev/null 2>&1 || { echo "❌ Java がインストールされていません"; exit 1; }
	@echo "✅ 全ての前提条件が満たされています"

## =============================================================================
## 初回セットアップ
## =============================================================================

.PHONY: setup-first-time
setup-first-time: setup-prerequisites setup-aws-auth ## 初回セットアップ
	@echo "🎉 初回セットアップを開始します"
	@echo ""
	@echo "次の手順を実行してください:"
	@echo "1. make setup-aws-auth の指示に従ってAWS認証を設定"
	@echo "2. DEPLOY.md を参考にSSMパラメータを設定"
	@echo "3. make deploy-all でサービスをデプロイ"
	@echo ""
	@echo "詳細な手順は DEPLOY.md を参照してください"


.PHONY: aws-install-deps
aws-install-deps: ## AWS設定生成ツールの依存関係をインストール
	@echo "📦 AWS設定生成ツールの依存関係をインストール中..."
	@cd scripts && npm install
	@echo "✅ 依存関係のインストールが完了しました"

.PHONY: generate-prod-configs
generate-prod-configs: ## 本番用AWS設定ファイルを動的生成
	@echo "🔧 本番用AWS設定ファイルを生成中..."
	@if [ ! -d "scripts/node_modules" ]; then \
		echo "⚠️  依存関係が見つかりません。インストールを実行します..."; \
		$(MAKE) aws-install-deps; \
	fi
	@cd scripts && npm run generate
	@echo "✅ 本番用設定ファイルの生成が完了しました"

.PHONY: update-infra
update-infra: generate-prod-configs ## CloudFormationスタックを更新
	@echo "🚀 CloudFormationスタックを更新中..."
	aws cloudformation update-stack \
		--profile $(AWS_PROFILE) \
		--region $(AWS_REGION) \
		--stack-name kishax-infrastructure \
		--template-body file://cloudformation-template.prod.yaml \
		--parameters file://cloudformation-parameters.prod.json \
		--capabilities CAPABILITY_NAMED_IAM
	@echo "✅ CloudFormationスタックの更新を開始しました"


.PHONY: update-ssm-param
update-ssm-param: ## SSMパラメータを更新 (引数なし:全て, 例: make update-ssm-param param=/kishax/discord/bot/token)
	@if ! command -v jq > /dev/null; then \
		echo "❌ 'jq' is not installed. Please install it to continue."; \
		exit 1; \
	fi
	@if [ -z "$(param)" ]; then \
		echo "⚠️  全てのSSMパラメータを更新しようとしています。"; \
		PARAM_COUNT=$$(jq '. | length' ssm-parameters.json); \
		echo "📊 更新対象: $$PARAM_COUNT 個のパラメータ"; \
		echo ""; \
		read -p "🤔 本当に全てのSSMパラメータを更新しますか? (y/N): " confirm; \
		if [ "$$confirm" != "y" ] && [ "$$confirm" != "Y" ]; then \
			echo "❌ 更新を中止しました"; \
			exit 1; \
		fi; \
		echo "🚀 全SSMパラメータを更新中..."; \
		jq -c '.[]' ssm-parameters.json | while read -r item; do \
			name=$$(echo $$item | jq -r '.Name'); \
			value=$$(echo $$item | jq -r '.Value'); \
			type=$$(echo $$item | jq -r '.Type'); \
			echo "Updating $$name..."; \
			aws ssm put-parameter \
				--name "$$name" \
				--value "$$value" \
				--type "$$type" \
				--profile $(AWS_PROFILE) \
				--overwrite > /dev/null; \
		done; \
		echo "✅ 全SSMパラメータの更新が完了しました"; \
	else \
		echo "🔍 パラメータ '$(param)' を検索中..."; \
		param_data=$$(jq -c '.[] | select(.Name == "$(param)")' ssm-parameters.json); \
		if [ -z "$$param_data" ]; then \
			echo "❌ パラメータ '$(param)' が ssm-parameters.json に見つかりません"; \
			exit 1; \
		fi; \
		name=$$(echo $$param_data | jq -r '.Name'); \
		value=$$(echo $$param_data | jq -r '.Value'); \
		type=$$(echo $$param_data | jq -r '.Type'); \
		echo "🚀 パラメータ '$$name' を更新中..."; \
		aws ssm put-parameter \
			--name "$$name" \
			--value "$$value" \
			--type "$$type" \
			--profile $(AWS_PROFILE) \
			--overwrite > /dev/null; \
		echo "✅ パラメータ '$$name' の更新が完了しました"; \
	fi

.PHONY: get-ssm-param
get-ssm-param: ## SSMパラメータを取得 (例: make get-ssm-param param=/kishax/discord/bot/token)
	@if [ -z "$(param)" ]; then \
		echo "❌ 'param' argument is required. (例: make get-ssm-param param=/kishax/discord/bot/token)"; \
		exit 1; \
	fi
	@echo "🔍 パラメータ '$(param)' を取得中..."
	@aws ssm get-parameter \
		--name "$(param)" \
		--with-decryption \
		--profile $(AWS_PROFILE) \
		--query 'Parameter.{Name:Name,Value:Value,Type:Type}' \
		--output table

.PHONY: setup-ssm-completion
setup-ssm-completion: ## SSMパラメータのTAB補完を設定
	@echo "🔧 SSMパラメータのTAB補完を設定中..."
	@if ! command -v jq > /dev/null; then \
		echo "❌ 'jq' is not installed. Please install it to continue."; \
		exit 1; \
	fi
	@chmod +x scripts/make-completion
	@COMPLETION_FILE="$$PWD/scripts/make-completion"; \
	SHELL_RC=""; \
	if [ "$$SHELL" = "/bin/zsh" ] || [ "$$SHELL" = "/usr/bin/zsh" ]; then \
		SHELL_RC="$$HOME/.zshrc"; \
	elif [ "$$SHELL" = "/bin/bash" ] || [ "$$SHELL" = "/usr/bin/bash" ]; then \
		SHELL_RC="$$HOME/.bashrc"; \
	else \
		echo "⚠️  未対応のシェル: $$SHELL"; \
		echo "手動で以下を ~/.bashrc または ~/.zshrc に追加してください:"; \
		echo "source $$COMPLETION_FILE"; \
		exit 0; \
	fi; \
	if grep -q "source $$COMPLETION_FILE" "$$SHELL_RC" 2>/dev/null; then \
		echo "ℹ️  補完設定は既に $$SHELL_RC に存在します"; \
	else \
		echo "" >> "$$SHELL_RC"; \
		echo "# Kishax infrastructure make completion" >> "$$SHELL_RC"; \
		echo "source $$COMPLETION_FILE" >> "$$SHELL_RC"; \
		echo "✅ 補完設定を $$SHELL_RC に追加しました"; \
	fi; \
	echo "🔄 新しいターミナルを開くか、以下を実行してください:"; \
	echo "source $$SHELL_RC"

.PHONY: list-ssm-params
list-ssm-params: ## SSMパラメータ一覧を表示
	@echo "📋 利用可能なSSMパラメータ:"
	@if ! command -v jq > /dev/null; then \
		echo "❌ 'jq' is not installed. Please install it to continue."; \
		exit 1; \
	fi
	@jq -r '.[].Name' ssm-parameters.json | sort

## =============================================================================
## Docker (Buildx)
## =============================================================================

.PHONY: buildx-and-push
buildx-and-push: ## 指定されたサービスのDockerイメージをビルドし、ECRにプッシュします (例: make buildx-and-push service=web)
	@if [ -z "$(service)" ]; then \
		echo "❌ 'service' arugment is required. (e.g., make buildx-and-push service=web)"; \
		exit 1; \
	fi
	@echo "🚀 Building and pushing $(service) image for linux/amd64..."
	@{ \
		service_upper=$$(echo $(service) | tr '[:lower:]' '[:upper:]' | tr '-' '_'); \
		ecr_repo_var=ECR_REPO_$${service_upper}; \
		ecr_repo=$$($$(ecr_repo_var)); \
		\
		cd apps/$(service) && \
		docker buildx build --platform linux/amd64 -t kishax-$(service):latest-amd64 . && \
		aws ecr get-login-password --region $(AWS_REGION) --profile $(AWS_PROFILE) | \
			docker login --username AWS --password-stdin $${ecr_repo} && \
		docker tag kishax-$(service):latest-amd64 $${ecr_repo}:latest-amd64 && \
		docker push $${ecr_repo}:latest-amd64; \
	}
	@echo "✅ Successfully pushed kishax-$(service):latest-amd64 to ECR."
	@echo "ℹ️ 注: このコマンドはECSサービスを自動で更新しません。"
	@echo "   'make deploy-$(service)' を実行するか、手動でサービスを更新してください。"

##
.PHONY: wait-stack-completion
wait-stack-completion: ## CloudFormationスタックの更新完了を待機
	@echo "⏳ CloudFormationスタックの更新完了を待機中"
	aws cloudformation wait stack-update-complete \
		--stack-name kishax-infrastructure \
		--profile $(AWS_PROFILE)
	@echo "✅ CloudFormationスタックの更新が完了しました"

.PHONY: check-task
check-task-auth:
	aws ecs describe-services \
		--cluster kishax-infrastructure-cluster \
		--services kishax-auth-service-v2 \
		--profile $(AWS_PROFILE) \
		--query 'services[0].{ServiceName:serviceName,Status:status,DesiredCount:desiredCount,RunningCount:runningCount,PendingCount:pendingCount,Events:events[0:2]}' \
		--output json
