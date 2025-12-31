#!/bin/bash
# 単一のSSMポートフォワーディングセッションを起動するヘルパースクリプト

TARGET="$1"
HOST="$2"
PORT="$3"
LOCAL_PORT="$4"
AWS_PROFILE="$5"
LOG_FILE="$6"

exec aws ssm start-session \
    --target "$TARGET" \
    --document-name AWS-StartPortForwardingSessionToRemoteHost \
    --parameters "{\"host\":[\"$HOST\"],\"portNumber\":[\"$PORT\"],\"localPortNumber\":[\"$LOCAL_PORT\"]}" \
    --profile "$AWS_PROFILE" \
    >> "$LOG_FILE" 2>&1

