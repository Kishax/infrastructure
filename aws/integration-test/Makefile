# Integration Test Makefile

include .env

.PHONY: help test-integration test-mc-plugins test-api-gateway test-discord-bot test-web test-player-leave test-player-join clean-test setup-test

help: ## 統合テストヘルプを表示
	@echo "Integration Test Commands"
	@echo ""
	@echo "利用可能なコマンド:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  \033[36m%-25s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

## =============================================================================
## 統合テスト実行
## =============================================================================

test-integration: ## 全統合テストを実行
	@echo "🚀 統合テスト開始..."
	@echo ""
	@echo "テスト対象:"
	@echo "  - mc-discord: MC → Discord通信（API Gateway経由）"
	@echo "  - mc-web-bidirectional: MC ↔ Web双方向通信（SQS直接）"
	@echo "  - web-mc-auth: Web → MC認証（API Gateway経由）"
	@echo "  - legacy: 既存テスト（後方互換性）"
	@echo ""
	./gradlew clean integrationTest --info
	@echo ""
	@echo "✅ 全統合テスト完了"

test-mc-plugins: ## Minecraftプラグイン統合テスト
	@echo "🎮 Minecraft Plugin → API Gateway 統合テスト実行..."
	./gradlew clean test --tests "*McPlugin*" --info

test-api-gateway: ## API Gateway統合テスト
	@echo "🌐 API Gateway → Lambda → SQS 統合テスト実行..."
	./gradlew clean test --tests "*ApiGateway*" --info

test-mc-discord: ## MC→Discord通信統合テスト
	@echo "🤖 MC→Discord通信統合テスト実行..."
	./gradlew clean test --tests "*McDiscordCommunication*" --info

test-discord-bot: ## Discord Bot統合テスト（後方互換性）
	@echo "🤖 Discord Bot SQS処理統合テスト実行..."
	./gradlew clean test --tests "*DiscordBot*" --info

test-discord-events: ## 全Discordメッセージイベント統合テスト
	@echo "🎮 全Discordメッセージイベント統合テスト実行..."
	@echo "テスト対象: player_join, player_leave, server_status"
	./gradlew clean test --tests "*shouldHandleMultipleMessageTypesViaApiGateway*" --info

test-player-leave: ## Player Leave メッセージ統合テスト
	@echo "🚪 Player Leave メッセージ統合テスト実行..."
	@echo "テスト対象: player_leave イベント"
	./gradlew clean test --tests "*shouldSendPlayerLeaveMessageViaApiGateway*" --info

test-player-join: ## Player Join メッセージ統合テスト
	@echo "🎮 Player Join メッセージ統合テスト実行..."
	@echo "テスト対象: player_join イベント"
	./gradlew clean test --tests "*shouldSendPlayerJoinMessageViaApiGateway*" --info

test-mc-web-bidirectional: ## MC↔Web双方向通信統合テスト
	@echo "🔄 MC↔Web双方向通信統合テスト実行..."
	./gradlew clean test --tests "*McWebBidirectional*" --info

test-web-mc-auth: ## Web→MC認証統合テスト
	@echo "🔐 Web→MC認証統合テスト実行..."
	./gradlew clean test --tests "*WebMcAuth*" --info

test-web: ## Web アプリケーション統合テスト（後方互換性）
	@echo "🌍 Web Application 統合テスト実行..."
	./gradlew clean test --tests "*Web*" --info

## =============================================================================
## 通信パターン別テスト
## =============================================================================

test-all-communication-patterns: ## 全通信パターンテスト実行
	@echo "🔄 全通信パターン統合テスト実行..."
	@echo "実行順序: MC→Discord, MC↔Web, Web→MC"
	make test-mc-discord
	make test-mc-web-bidirectional  
	make test-web-mc-auth
	@echo "✅ 全通信パターンテスト完了"

## =============================================================================
## 個別コンポーネントテスト（後方互換性）
## =============================================================================

test-full-flow: ## 完全フロー統合テスト（MC → Discord）
	@echo "🔄 完全統合フローテスト実行..."
	@echo "フロー: Minecraft Plugin → API Gateway → Lambda → SQS → Discord Bot"
	./gradlew clean test --tests "*FullFlow*" --info

test-auth-flow: ## 認証フロー統合テスト
	@echo "🔐 認証フロー統合テスト実行..."
	./gradlew clean test --tests "*Auth*" --info

## =============================================================================
## テスト結果とレポート
## =============================================================================

test-report: ## テスト結果レポート表示
	@echo "📊 統合テスト結果レポート:"
	@echo ""
	@if [ -f build/reports/tests/integrationTest/index.html ]; then \
		echo "📄 HTML レポート: build/reports/tests/integrationTest/index.html"; \
		echo "📊 カバレッジ: build/reports/jacoco/test/html/index.html"; \
	else \
		echo "❌ テスト結果が見つかりません。先に 'make test-integration' を実行してください"; \
	fi

test-logs: ## テストログ確認
	@echo "📋 統合テストログ:"
	@if [ -f build/reports/tests/integrationTest/index.html ]; then \
		find build/test-results -name "*.xml" -exec echo "📄 {}" \; -exec cat {} \; | head -50; \
	else \
		echo "❌ テストログが見つかりません"; \
	fi

## =============================================================================
## デバッグとトラブルシューティング
## =============================================================================

debug-aws: ## AWS接続確認
	@echo "🔍 AWS接続確認中..."
	@echo "Profile: $(AWS_PROFILE)"
	aws sts get-caller-identity --profile $(AWS_PROFILE) || echo "❌ AWS認証に失敗しました"
	aws apigateway get-rest-api --rest-api-id 043t0plyrl --profile $(AWS_PROFILE) --query '{id:id,name:name}' || echo "❌ API Gateway接続に失敗しました"
	aws sqs get-queue-attributes --queue-url $(shell aws ssm get-parameter --name "/kishax/sqs/queue-url" --with-decryption --profile $(AWS_PROFILE) --query 'Parameter.Value' --output text) --attribute-names QueueArn --profile $(AWS_PROFILE) || echo "❌ SQS接続に失敗しました"
