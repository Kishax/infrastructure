# Player Event Tests Integration Test Makefile

include .env

.PHONY: help test-player-events test-player-join test-player-leave test-multiple-player-events clean-test setup-test debug-aws test-report

help: ## Player Event Tests統合テストヘルプを表示
	@echo "Player Event Tests Integration Commands"
	@echo ""
	@echo "利用可能なコマンド:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  \033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

## =============================================================================
## Player Event Tests 統合テスト実行
## =============================================================================

test-player-events: ## 全Player Event Tests統合テストを実行
	@echo "🚀 Player Event Tests統合テスト開始..."
	@echo ""
	@echo "テスト対象:"
	@echo "  - プレイヤー参加イベント (player_join)"
	@echo "  - プレイヤー離脱イベント (player_leave)"
	@echo "  - 複数プレイヤーイベント処理"
	@echo ""
	@echo "テストフロー: API Gateway → SQS → Discord Bot"
	@echo ""
	./gradlew clean integrationTest --info
	@echo ""
	@echo "✅ Player Event Tests統合テスト完了"

test-player-join: ## プレイヤー参加イベント統合テスト
	@echo "🎮 プレイヤー参加イベント統合テスト実行..."
	@echo "テスト内容: player_join イベント → Discord Bot処理"
	./gradlew clean test --tests "*shouldSendPlayerJoinEventAndReceiveInSqs*" --info

test-player-leave: ## プレイヤー離脱イベント統合テスト
	@echo "🚪 プレイヤー離脱イベント統合テスト実行..."
	@echo "テスト内容: player_leave イベント → Discord Bot処理"
	./gradlew clean test --tests "*shouldSendPlayerLeaveEventAndReceiveInSqs*" --info

test-multiple-player-events: ## 複数プレイヤーイベント処理テスト
	@echo "🔄 複数プレイヤーイベント処理テスト実行..."
	@echo "テスト内容: join/leave イベントの並行処理"
	./gradlew clean test --tests "*shouldHandleMultiplePlayerEventsViaApiGateway*" --info

## =============================================================================
## テスト結果とレポート
## =============================================================================

test-report: ## テスト結果レポート表示
	@echo "📊 Player Event Tests統合テスト結果レポート:"
	@echo ""
	@if [ -f build/reports/tests/integrationTest/index.html ]; then \
		echo "📄 HTML レポート: build/reports/tests/integrationTest/index.html"; \
		echo "📊 カバレッジ: build/reports/jacoco/test/html/index.html"; \
		echo ""; \
		echo "ブラウザで確認: open build/reports/tests/integrationTest/index.html"; \
	else \
		echo "❌ テスト結果が見つかりません。先に 'make test-player-events' を実行してください"; \
	fi

clean-test: ## テスト結果とビルド成果物をクリア
	@echo "🧹 テスト結果をクリア中..."
	./gradlew clean
	@echo "✅ テスト結果をクリアしました"

## =============================================================================
## デバッグとトラブルシューティング
## =============================================================================

debug-aws: ## AWS接続確認
	@echo "🔍 AWS接続確認中..."
	@echo "Profile: $(AWS_PROFILE)"
	aws sts get-caller-identity --profile $(AWS_PROFILE) || echo "❌ AWS認証に失敗しました"
	@echo ""
	@echo "API Gateway 接続確認:"
	aws apigateway get-rest-apis --profile $(AWS_PROFILE) --query 'items[?name==`kishax-infrastructure-api`].{id:id,name:name}' --output table || echo "❌ API Gateway接続に失敗しました"
	@echo ""
	@echo "SQS キュー確認:"
	aws sqs list-queues --profile $(AWS_PROFILE) --queue-name-prefix kishax || echo "❌ SQS接続に失敗しました"

setup-test: ## テスト環境セットアップチェック
	@echo "🔧 Player Event Tests環境セットアップチェック..."
	@echo ""
	@echo "必要な環境変数:"
	@echo "  - AWS_PROFILE: $(AWS_PROFILE)"
	@echo "  - AWS_REGION: $(AWS_REGION)"
	@echo "  - AWS_ACCOUNT_ID: $(AWS_ACCOUNT_ID)"
	@echo ""
	@echo "Java版本確認:"
	java -version
	@echo ""
	@echo "Gradle版本確認:"
	./gradlew --version | head -5
	@echo ""
	@echo "✅ セットアップチェック完了"
