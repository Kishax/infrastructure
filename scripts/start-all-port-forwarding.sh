#!/bin/bash

# Kishax Infrastructure - 全ポートフォワーディング起動スクリプト
# 全てのSSMポートフォワーディングセッションを起動します

set -e

# 設定
AWS_PROFILE="${AWS_PROFILE:-AdministratorAccess-126112056177}"
AWS_REGION="${AWS_REGION:-ap-northeast-1}"
ENVIRONMENT="${ENVIRONMENT:-production}"

# 色コード
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Kishax Infrastructure - 全ポートフォワーディング起動${NC}"
echo ""

# .env.autoをロード
if [ -f .env.auto ]; then
    source .env.auto
    echo -e "${GREEN}✅ .env.autoを読み込みました${NC}"
else
    echo -e "${RED}❌ .env.autoが見つかりません${NC}"
    echo -e "${YELLOW}💡 'make env-load' を実行してください${NC}"
    exit 1
fi

# Jump ServerのインスタンスIDを取得
echo ""
echo -e "${BLUE}🔍 Jump Serverを確認中...${NC}"
INSTANCE_ID_D=$(aws ec2 describe-instances \
    --profile "$AWS_PROFILE" \
    --region "$AWS_REGION" \
    --filters "Name=tag:Name,Values=kishax-${ENVIRONMENT}-jump-server" "Name=instance-state-name,Values=running" \
    --query 'Reservations[0].Instances[0].InstanceId' \
    --output text 2>/dev/null)

if [ -z "$INSTANCE_ID_D" ] || [ "$INSTANCE_ID_D" = "None" ]; then
    echo -e "${RED}❌ Jump Serverが起動していません${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Jump Server: $INSTANCE_ID_D${NC}"

# プライベートIPを取得
echo ""
echo -e "${BLUE}🔍 プライベートIPを取得中...${NC}"

PRIVATE_IP_A=$(aws ec2 describe-instances \
    --profile "$AWS_PROFILE" \
    --region "$AWS_REGION" \
    --filters "Name=tag:Name,Values=kishax-${ENVIRONMENT}-mc-server" \
    --query 'Reservations[0].Instances[0].PrivateIpAddress' \
    --output text 2>/dev/null)

PRIVATE_IP_B=$(aws ec2 describe-instances \
    --profile "$AWS_PROFILE" \
    --region "$AWS_REGION" \
    --filters "Name=tag:Name,Values=kishax-${ENVIRONMENT}-api-server" \
    --query 'Reservations[0].Instances[0].PrivateIpAddress' \
    --output text 2>/dev/null)

PRIVATE_IP_C=$(aws ec2 describe-instances \
    --profile "$AWS_PROFILE" \
    --region "$AWS_REGION" \
    --filters "Name=tag:Name,Values=kishax-${ENVIRONMENT}-web-server" \
    --query 'Reservations[0].Instances[0].PrivateIpAddress' \
    --output text 2>/dev/null)

echo -e "${GREEN}✅ MC Server (i-a):  $PRIVATE_IP_A${NC}"
echo -e "${GREEN}✅ API Server (i-b): $PRIVATE_IP_B${NC}"
echo -e "${GREEN}✅ Web Server (i-c): $PRIVATE_IP_C${NC}"
echo -e "${GREEN}✅ RDS MySQL:        $RDS_MYSQL_HOST${NC}"
echo -e "${GREEN}✅ RDS PostgreSQL:   $RDS_POSTGRES_HOST${NC}"

# ログディレクトリの作成
LOG_DIR="$HOME/.kishax-ssm-logs"
mkdir -p "$LOG_DIR"

echo ""
echo -e "${BLUE}🚀 ポートフォワーディングを起動中...${NC}"
echo ""

# 既存のセッションをクリーンアップする関数
cleanup_port() {
    local port=$1
    local pid=$(lsof -ti:$port 2>/dev/null)
    if [ -n "$pid" ]; then
        echo -e "${YELLOW}⚠️  ポート $port は既に使用中です (PID: $pid)${NC}"
        read -p "停止しますか？ (y/N): " answer
        if [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
            kill $pid 2>/dev/null || true
            sleep 2
            echo -e "${GREEN}✅ ポート $port を解放しました${NC}"
        else
            echo -e "${YELLOW}⏭️  ポート $port をスキップします${NC}"
            return 1
        fi
    fi
    return 0
}

# 各ポートフォワーディングを起動
start_port_forward() {
    local name=$1
    local host=$2
    local port=$3
    local local_port=$4
    local log_file="$LOG_DIR/ssm-${name}.log"
    
    if ! cleanup_port $local_port; then
        echo -e "${YELLOW}⏭️  $name のポートフォワーディングをスキップしました${NC}"
        return
    fi
    
    echo -e "${BLUE}🔗 $name (localhost:$local_port)${NC}"
    
    # バックグラウンドでSSMセッションを開始
    nohup aws ssm start-session \
        --target "$INSTANCE_ID_D" \
        --document-name AWS-StartPortForwardingSessionToRemoteHost \
        --parameters "{\"host\":[\"$host\"],\"portNumber\":[\"$port\"],\"localPortNumber\":[\"$local_port\"]}" \
        --profile "$AWS_PROFILE" \
        > "$log_file" 2>&1 &
    
    local pid=$!
    echo -e "   PID: $pid"
    echo -e "   Log: $log_file"
    echo ""
    
    # PIDファイルに保存
    echo "$pid" >> "$LOG_DIR/pids.txt"
    
    # 起動を少し待つ
    sleep 2
}

# PIDファイルの初期化
: > "$LOG_DIR/pids.txt"

# 各サーバーへのポートフォワーディングを起動
if [ -n "$PRIVATE_IP_A" ] && [ "$PRIVATE_IP_A" != "None" ]; then
    start_port_forward "MC Server" "$PRIVATE_IP_A" "22" "2222"
fi

if [ -n "$PRIVATE_IP_B" ] && [ "$PRIVATE_IP_B" != "None" ]; then
    start_port_forward "API Server" "$PRIVATE_IP_B" "22" "2223"
fi

if [ -n "$PRIVATE_IP_C" ] && [ "$PRIVATE_IP_C" != "None" ]; then
    start_port_forward "Web Server" "$PRIVATE_IP_C" "22" "2224"
fi

if [ -n "$RDS_MYSQL_HOST" ] && [ "$RDS_MYSQL_HOST" != "None" ]; then
    start_port_forward "RDS MySQL" "$RDS_MYSQL_HOST" "${RDS_MYSQL_PORT:-3306}" "3307"
fi

if [ -n "$RDS_POSTGRES_HOST" ] && [ "$RDS_POSTGRES_HOST" != "None" ]; then
    start_port_forward "RDS PostgreSQL" "$RDS_POSTGRES_HOST" "${RDS_POSTGRES_PORT:-5432}" "5433"
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✅ 全ポートフォワーディングを起動しました${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${BLUE}📊 接続情報:${NC}"
echo -e "  🖥️  MC Server:       ssh -i minecraft.pem -p 2222 ec2-user@localhost"
echo -e "  🖥️  API Server:      ssh -i minecraft.pem -p 2223 ec2-user@localhost"
echo -e "  🖥️  Web Server:      ssh -i minecraft.pem -p 2224 ec2-user@localhost"
echo -e "  🗄️  MySQL:           mysql -h 127.0.0.1 -P 3307 -u root -p kishax_mc"
echo -e "  🗄️  PostgreSQL:      psql -h 127.0.0.1 -p 5433 -U postgres -d kishax_web"
echo ""
echo -e "${BLUE}📝 ログファイル:${NC}"
echo -e "  $LOG_DIR"
echo ""
echo -e "${YELLOW}⚠️  注意:${NC}"
echo -e "  - ポートフォワーディングはバックグラウンドで実行されています"
echo -e "  - 停止するには: make ssm-stop-all"
echo -e "  - ステータス確認: make ssm-status"
echo ""

