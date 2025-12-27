#!/bin/bash

# Kishax Infrastructure - 全ポートフォワーディング停止スクリプト
# 全てのSSMポートフォワーディングセッションを停止します

set -e

# 色コード
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🛑 Kishax Infrastructure - 全ポートフォワーディング停止${NC}"
echo ""

LOG_DIR="$HOME/.kishax-ssm-logs"
PID_FILE="$LOG_DIR/pids.txt"

if [ ! -f "$PID_FILE" ]; then
    echo -e "${YELLOW}⚠️  PIDファイルが見つかりません${NC}"
    echo -e "${BLUE}💡 プロセス名で検索して停止します...${NC}"
    echo ""
    
    # aws ssm start-session プロセスを検索
    PIDS=$(pgrep -f "aws ssm start-session.*AWS-StartPortForwardingSessionToRemoteHost" || true)
    
    if [ -z "$PIDS" ]; then
        echo -e "${GREEN}✅ 実行中のポートフォワーディングセッションはありません${NC}"
        exit 0
    fi
    
    echo -e "${BLUE}🔍 実行中のセッション:${NC}"
    ps -p $PIDS -o pid,etime,command | grep -v grep || true
    echo ""
    
    read -p "これらのプロセスを停止しますか？ (y/N): " answer
    if [ "$answer" != "y" ] && [ "$answer" != "Y" ]; then
        echo -e "${YELLOW}キャンセルしました${NC}"
        exit 0
    fi
    
    echo ""
    echo -e "${BLUE}🛑 セッションを停止中...${NC}"
    for pid in $PIDS; do
        echo -e "  Stopping PID: $pid"
        kill $pid 2>/dev/null || true
    done
    
    echo ""
    echo -e "${GREEN}✅ 全てのセッションを停止しました${NC}"
    exit 0
fi

echo -e "${BLUE}📋 PIDファイルから停止対象を読み込み中...${NC}"
echo ""

STOPPED_COUNT=0
FAILED_COUNT=0

while read pid; do
    if [ -n "$pid" ]; then
        if kill -0 $pid 2>/dev/null; then
            echo -e "${BLUE}🛑 Stopping PID: $pid${NC}"
            kill $pid 2>/dev/null || true
            STOPPED_COUNT=$((STOPPED_COUNT + 1))
        else
            echo -e "${YELLOW}⚠️  PID $pid は既に停止しています${NC}"
            FAILED_COUNT=$((FAILED_COUNT + 1))
        fi
    fi
done < "$PID_FILE"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✅ ポートフォワーディング停止完了${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "  停止: $STOPPED_COUNT"
echo -e "  既に停止済み: $FAILED_COUNT"
echo ""

# PIDファイルをクリーンアップ
rm -f "$PID_FILE"
echo -e "${GREEN}✅ PIDファイルをクリーンアップしました${NC}"
echo ""

# ログファイルも削除するか確認
echo -e "${BLUE}ログファイルを削除しますか？${NC}"
echo -e "  場所: $LOG_DIR"
read -p "削除しますか？ (y/N): " answer
if [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
    rm -rf "$LOG_DIR"
    echo -e "${GREEN}✅ ログファイルを削除しました${NC}"
else
    echo -e "${YELLOW}⏭️  ログファイルは保持されます${NC}"
fi
echo ""

