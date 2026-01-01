# Terraria Server Makefile

.PHONY: download
download: ## S3から最新のTerrariaサーバデータをダウンロード
	@echo "🔍 S3から最新バージョンを検索中..."
	@LATEST_YEARMONTH=$$(aws s3 ls s3://kishax-production-terraria-backups/deployment/ | grep PRE | awk '{print $$2}' | sed 's/\///' | sort -r | head -n 1); \
	LATEST_VERSION=$$(aws s3 ls s3://kishax-production-terraria-backups/deployment/$$LATEST_YEARMONTH/ | grep PRE | awk '{print $$2}' | sed 's/\///' | sort -rn | head -n 1); \
	echo "📦 最新バージョン: $$LATEST_YEARMONTH/$$LATEST_VERSION"; \
	echo "📥 ダウンロード中..."; \
	aws s3 sync s3://kishax-production-terraria-backups/deployment/$$LATEST_YEARMONTH/$$LATEST_VERSION/terraria/ /opt/terraria/ --delete; \
	echo "✅ ダウンロード完了"

.PHONY: upload
upload: ## S3へTerrariaサーバデータをアップロード (--newで新バージョン作成)
	@if echo "$(filter-out upload,$(MAKECMDGOALS))" | grep -q "new"; then \
		echo "🆕 新バージョンを作成します"; \
		YEARMONTH=$$(date +%Y%m); \
		LATEST_VERSION=$$(aws s3 ls s3://kishax-production-terraria-backups/deployment/$$YEARMONTH/ 2>/dev/null | grep PRE | awk '{print $$2}' | sed 's/\///' | sort -rn | head -n 1); \
		if [ -z "$$LATEST_VERSION" ]; then NEW_VERSION=1; else NEW_VERSION=$$(($$LATEST_VERSION + 1)); fi; \
		echo "📦 新バージョン: $$YEARMONTH/$$NEW_VERSION"; \
		echo "📤 アップロード中..."; \
		aws s3 sync /opt/terraria/ s3://kishax-production-terraria-backups/deployment/$$YEARMONTH/$$NEW_VERSION/terraria/ --delete; \
	else \
		echo "🔍 S3から最新バージョンを検索中..."; \
		LATEST_YEARMONTH=$$(aws s3 ls s3://kishax-production-terraria-backups/deployment/ | grep PRE | awk '{print $$2}' | sed 's/\///' | sort -r | head -n 1); \
		LATEST_VERSION=$$(aws s3 ls s3://kishax-production-terraria-backups/deployment/$$LATEST_YEARMONTH/ | grep PRE | awk '{print $$2}' | sed 's/\///' | sort -rn | head -n 1); \
		echo "📦 既存バージョンに上書き: $$LATEST_YEARMONTH/$$LATEST_VERSION"; \
		echo "📤 アップロード中..."; \
		aws s3 sync /opt/terraria/ s3://kishax-production-terraria-backups/deployment/$$LATEST_YEARMONTH/$$LATEST_VERSION/terraria/ --delete; \
	fi; \
	echo "✅ アップロード完了"

# --new フラグをターゲットとして認識させないためのダミー
new:
	@:
