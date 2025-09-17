#!/bin/bash

set -e

# ECSサービス操作用テンプレートスクリプト
# 使用法: ./ecs-service.sh <action> <service> <cluster> <profile> [count]
# action: restart|enable|disable|start|stop
# service: サービス名
# cluster: クラスター名
# profile: AWS profile名
# count: desired-count (enable/disable/startで使用)

ACTION=$1
SERVICE=$2
CLUSTER=${3:-"kishax-infrastructure-cluster"}
PROFILE=${4:-$AWS_PROFILE}
COUNT=${5:-1}

if [ -z "$ACTION" ] || [ -z "$SERVICE" ]; then
  echo "Usage: $0 <action> <service> [cluster] [profile] [count]"
  echo "Actions: restart, enable, disable, start, stop"
  exit 1
fi

case $ACTION in
"restart")
  echo "🔄 ${SERVICE}サービスを再起動中..."
  aws ecs update-service \
    --cluster "$CLUSTER" \
    --service "$SERVICE" \
    --force-new-deployment \
    --profile "$PROFILE" >/dev/null
  echo "✅ ${SERVICE}サービスの再起動を要求しました (新しいタスクで再開)"
  ;;

"enable")
  echo "🟢 ${SERVICE}サービスを有効化中..."
  aws ecs update-service \
    --cluster "$CLUSTER" \
    --service "$SERVICE" \
    --desired-count "$COUNT" \
    --profile "$PROFILE" >/dev/null
  echo "✅ ${SERVICE}サービスを有効化しました"
  ;;

"disable")
  echo "🔴 ${SERVICE}サービスを無効化中..."
  aws ecs update-service \
    --cluster "$CLUSTER" \
    --service "$SERVICE" \
    --desired-count 0 \
    --profile "$PROFILE" >/dev/null
  echo "✅ ${SERVICE}サービスを無効化しました"
  ;;

"start")
  echo "▶️ ${SERVICE}サービスを開始中..."
  CURRENT_COUNT=$(aws ecs describe-services \
    --cluster "$CLUSTER" \
    --services "$SERVICE" \
    --profile "$PROFILE" \
    --query "services[0].desiredCount" \
    --output text)

  if [ "$CURRENT_COUNT" = "0" ]; then
    aws ecs update-service \
      --cluster "$CLUSTER" \
      --service "$SERVICE" \
      --desired-count "$COUNT" \
      --profile "$PROFILE" >/dev/null
    echo "✅ ${SERVICE}サービスを開始しました"
  else
    echo "ℹ️ ${SERVICE}サービスは既に実行中です (desired-count=$CURRENT_COUNT)"
  fi
  ;;

"stop")
  echo "⏹️ ${SERVICE}実行中タスクを即座停止中..."
  TASK_ARNS=$(aws ecs list-tasks \
    --cluster "$CLUSTER" \
    --service "$SERVICE" \
    --profile "$PROFILE" \
    --query "taskArns" \
    --output text)

  if [ "$TASK_ARNS" != "" ] && [ "$TASK_ARNS" != "None" ]; then
    aws ecs stop-task \
      --cluster "$CLUSTER" \
      --task "$TASK_ARNS" \
      --profile "$PROFILE" >/dev/null
    echo "✅ ${SERVICE}タスクを停止しました"
  else
    echo "ℹ️ ${SERVICE}の実行中タスクはありません"
  fi
  ;;

*)
  echo "❌ 不正なアクション: $ACTION"
  echo "使用可能なアクション: restart, enable, disable, start, stop"
  exit 1
  ;;
esac

