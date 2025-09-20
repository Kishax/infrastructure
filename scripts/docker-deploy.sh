#!/bin/bash

set -e

# Docker build & deploy用テンプレートスクリプト
# 使用法: ./docker-deploy.sh <service> <ecr_repo> <cluster> <ecs_service> <profile> [region] [build_args]
# service: サービス名 (discord-bot, gather-bot, web, auth, api)
# ecr_repo: ECRリポジトリURL
# cluster: ECSクラスター名
# ecs_service: ECSサービス名
# profile: AWS profile名
# region: AWSリージョン (オプション)
# build_args: Docker build時の追加引数 (オプション)

SERVICE=$1
ECR_REPO=$2
CLUSTER=${3:-"kishax-infrastructure-cluster"}
ECS_SERVICE=$4
PROFILE=${5:-$AWS_PROFILE}
REGION=${6:-$AWS_REGION}
BUILD_ARGS=$7

if [ -z "$SERVICE" ] || [ -z "$ECR_REPO" ] || [ -z "$ECS_SERVICE" ]; then
  echo "Usage: $0 <service> <ecr_repo> <cluster> <ecs_service> <profile> [region] [build_args]"
  exit 1
fi

echo "🚀 ${SERVICE}をデプロイ中..."

# サービスディレクトリに移動
if [ ! -d "apps/$SERVICE" ]; then
  echo "❌ ディレクトリ apps/$SERVICE が見つかりません"
  exit 1
fi

cd "apps/$SERVICE"

# サービス固有の前処理
case $SERVICE in
"web")
  echo "📦 Web アプリケーション用の前処理..."
  npm install
  npx prisma generate
  ;;
"api")
  # API固有の処理があれば追加
  ;;
*)
  # その他のサービスは特別な前処理なし
  ;;
esac

# Docker build
echo "🔨 Dockerイメージをビルド中..."
if [ -n "$BUILD_ARGS" ]; then
  docker buildx build --platform linux/amd64 $BUILD_ARGS -t "kishax-$SERVICE" .
else
  docker buildx build --platform linux/amd64 -t "kishax-$SERVICE" .
fi

# ECRログイン
echo "🔑 ECRにログイン中..."
aws ecr get-login-password --region "$REGION" --profile "$PROFILE" |
  docker login --username AWS --password-stdin "$ECR_REPO"

# Docker tag & push
echo "📤 ECRにプッシュ中..."
docker tag "kishax-$SERVICE:latest" "$ECR_REPO:latest"
docker push "$ECR_REPO:latest"

# ECSサービス更新
echo "🔄 ECSサービスを更新中..."
aws ecs update-service \
  --cluster "$CLUSTER" \
  --service "$ECS_SERVICE" \
  --force-new-deployment \
  --profile "$PROFILE" >/dev/null

echo "✅ ${SERVICE}のデプロイが完了しました"

# 元のディレクトリに戻る
cd - >/dev/null
