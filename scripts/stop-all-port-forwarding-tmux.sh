#!/bin/bash

# Kishax Infrastructure - 全ポートフォワーディング停止スクリプト (tmux版)
# tmuxセッション内のポートフォワーディングセッションを停止します

set -e

TMUX_SESSION_NAME="kishax-ssm-forwarding"

# 色コード
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🛑 Kishax Infrastructure - 全ポートフォワーディング停止 (tmux版)${NC}"
echo ""

# tmuxセッションが存在するか確認
if ! tmux has-session -t "$TMUX_SESSION_NAME" 2>/dev/null; then
    echo -e "${YELLOW}⚠️  tmuxセッション '$TMUX_SESSION_NAME' が見つかりません${NC}"
    echo ""
    echo -e "${BLUE}💡 他の方法でポートフォワーディングが起動している可能性があります${NC}"
    echo -e "   プロセスを確認: lsof -i :2222,:2223,:2224,:3307,:5433"
    echo ""
    exit 0
fi

echo -e "${BLUE}📋 tmuxセッション情報:${NC}"
tmux list-windows -t "$TMUX_SESSION_NAME" 2>/dev/null || true
echo ""

read -p "このtmuxセッションを停止しますか？ (y/N): " answer
if [ "$answer" != "y" ] && [ "$answer" != "Y" ]; then
    echo -e "${YELLOW}キャンセルしました${NC}"
    exit 0
fi

echo ""
echo -e "${BLUE}🛑 tmuxセッションを停止中...${NC}"
tmux kill-session -t "$TMUX_SESSION_NAME"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✅ ポートフォワーディング停止完了${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

