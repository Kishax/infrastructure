#!/bin/bash

# Kishax Infrastructure - ポートフォワーディング状態確認スクリプト
# 実行中のSSMポートフォワーディングセッションの状態を確認します

set -e

# 色コード
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}📊 Kishax Infrastructure - ポートフォワーディング状態確認${NC}"
echo ""

LOG_DIR="$HOME/.kishax-ssm-logs"
PID_FILE="$LOG_DIR/pids.txt"

# ポート使用状況を確認する関数
check_port() {
    local port=$1
    local name=$2
    local pid=$(lsof -ti:$port 2>/dev/null)
    
    if [ -n "$pid" ]; then
        echo -e "${GREEN}✅ $name (localhost:$port) - 実行中 (PID: $pid)${NC}"
        return 0
    else
        echo -e "${RED}❌ $name (localhost:$port) - 停止中${NC}"
        return 1
    fi
}

echo -e "${BLUE}🔍 ポート使用状況:${NC}"
echo ""

RUNNING_COUNT=0
STOPPED_COUNT=0

if check_port 2222 "MC Server"; then
    RUNNING_COUNT=$((RUNNING_COUNT + 1))
else
    STOPPED_COUNT=$((STOPPED_COUNT + 1))
fi

if check_port 2223 "API Server"; then
    RUNNING_COUNT=$((RUNNING_COUNT + 1))
else
    STOPPED_COUNT=$((STOPPED_COUNT + 1))
fi

if check_port 2224 "Web Server"; then
    RUNNING_COUNT=$((RUNNING_COUNT + 1))
else
    STOPPED_COUNT=$((STOPPED_COUNT + 1))
fi

if check_port 3307 "RDS MySQL"; then
    RUNNING_COUNT=$((RUNNING_COUNT + 1))
else
    STOPPED_COUNT=$((STOPPED_COUNT + 1))
fi

if check_port 5433 "RDS PostgreSQL"; then
    RUNNING_COUNT=$((RUNNING_COUNT + 1))
else
    STOPPED_COUNT=$((STOPPED_COUNT + 1))
fi

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}📊 サマリー${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}  実行中: $RUNNING_COUNT${NC}"
echo -e "${RED}  停止中: $STOPPED_COUNT${NC}"
echo ""

# プロセス一覧を表示
echo -e "${BLUE}🔍 実行中のSSMセッション:${NC}"
echo ""

PIDS=$(pgrep -f "aws ssm start-session.*AWS-StartPortForwardingSessionToRemoteHost" || true)

if [ -n "$PIDS" ]; then
    # macOSとLinuxの両方に対応
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        ps -p $PIDS -o pid,etime,comm | head -n 1
        ps -p $PIDS -o pid,etime,comm | grep -v PID || true
    else
        # Linux
        ps -p $PIDS -o pid,etime,command | head -n 1
        ps -p $PIDS -o pid,etime,command | grep -v PID || true
    fi
else
    echo -e "${YELLOW}  実行中のセッションはありません${NC}"
fi

echo ""

# PIDファイルの状態
if [ -f "$PID_FILE" ]; then
    echo -e "${BLUE}📋 PIDファイル: $PID_FILE${NC}"
    echo -e "${GREEN}  登録されているPID数: $(wc -l < "$PID_FILE" | tr -d ' ')${NC}"
else
    echo -e "${YELLOW}📋 PIDファイルは存在しません${NC}"
fi

echo ""

# ログディレクトリの状態
if [ -d "$LOG_DIR" ]; then
    echo -e "${BLUE}📝 ログディレクトリ: $LOG_DIR${NC}"
    LOG_COUNT=$(ls -1 "$LOG_DIR"/*.log 2>/dev/null | wc -l | tr -d ' ')
    echo -e "${GREEN}  ログファイル数: $LOG_COUNT${NC}"
    
    if [ "$LOG_COUNT" -gt 0 ]; then
        echo ""
        echo -e "${BLUE}  最新のログファイル:${NC}"
        ls -lht "$LOG_DIR"/*.log 2>/dev/null | head -5 | awk '{print "    " $9 " (" $5 ", " $6 " " $7 " " $8 ")"}'
        
        echo ""
        echo -e "${BLUE}  ログの最後の5行 (エラー確認用):${NC}"
        for log_file in $(ls -t "$LOG_DIR"/*.log 2>/dev/null | head -3); do
            echo -e "${YELLOW}    === $(basename $log_file) ===${NC}"
            tail -5 "$log_file" 2>/dev/null | sed 's/^/      /' || echo "      (読み取り不可)"
        done
    fi
else
    echo -e "${YELLOW}📝 ログディレクトリは存在しません${NC}"
fi

echo ""

# 接続情報
if [ $RUNNING_COUNT -gt 0 ]; then
    echo -e "${BLUE}📊 接続情報:${NC}"
    
    if lsof -ti:2222 >/dev/null 2>&1; then
        echo -e "  🖥️  MC Server:       ssh -i minecraft.pem -p 2222 ec2-user@localhost"
    fi
    
    if lsof -ti:2223 >/dev/null 2>&1; then
        echo -e "  🖥️  API Server:      ssh -i minecraft.pem -p 2223 ec2-user@localhost"
    fi
    
    if lsof -ti:2224 >/dev/null 2>&1; then
        echo -e "  🖥️  Web Server:      ssh -i minecraft.pem -p 2224 ec2-user@localhost"
    fi
    
    if lsof -ti:3307 >/dev/null 2>&1; then
        echo -e "  🗄️  MySQL:           mysql -h 127.0.0.1 -P 3307 -u root -p kishax_mc"
    fi
    
    if lsof -ti:5433 >/dev/null 2>&1; then
        echo -e "  🗄️  PostgreSQL:      psql -h 127.0.0.1 -p 5433 -U postgres -d kishax_web"
    fi
    
    echo ""
fi

