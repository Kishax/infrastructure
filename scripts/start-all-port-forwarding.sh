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

# AWS認証確認
echo -e "${BLUE}🔐 AWS認証確認中...${NC}"
if ! aws sts get-caller-identity --profile "$AWS_PROFILE" >/dev/null 2>&1; then
    echo -e "${RED}❌ AWS認証に失敗しました${NC}"
    echo -e "${YELLOW}💡 以下のコマンドでログインしてください:${NC}"
    echo -e "   aws sso login --profile $AWS_PROFILE"
    exit 1
fi
echo -e "${GREEN}✅ AWS認証済み${NC}"

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

# プライベートIPを.env.autoから取得
echo ""
echo -e "${BLUE}🔍 プライベートIPを.env.autoから取得中...${NC}"

# .env.autoから環境変数を読み込み
PRIVATE_IP_A="${INSTANCE_ID_A_PRIVATE_IP}"
PRIVATE_IP_B="${INSTANCE_ID_B_PRIVATE_IP}"
PRIVATE_IP_C="${INSTANCE_ID_C_PRIVATE_IP}"
PRIVATE_IP_E="${INSTANCE_ID_E_PRIVATE_IP}"

echo -e "${GREEN}✅ MC Server (i-a):      ${PRIVATE_IP_A:-None}${NC}"
echo -e "${GREEN}✅ API Server (i-b):     ${PRIVATE_IP_B:-None}${NC}"
echo -e "${GREEN}✅ Web Server (i-c):     ${PRIVATE_IP_C:-None}${NC}"
echo -e "${GREEN}✅ Terraria Server (i-e): ${PRIVATE_IP_E:-None}${NC}"
echo -e "${GREEN}✅ RDS MySQL:            $RDS_MYSQL_HOST${NC}"
echo -e "${GREEN}✅ RDS PostgreSQL:       $RDS_POSTGRES_HOST${NC}"

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
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    if ! cleanup_port $local_port; then
        echo -e "${YELLOW}⏭️  $name のポートフォワーディングをスキップしました${NC}"
        return
    fi
    
    echo -e "${BLUE}🔗 $name (localhost:$local_port)${NC}"
    
    # ワーカースクリプトを使用してバックグラウンド実行
    "$script_dir/ssm-port-forward-worker.sh" \
        "$INSTANCE_ID_D" \
        "$host" \
        "$port" \
        "$local_port" \
        "$AWS_PROFILE" \
        "$log_file" &
    
    local pid=$!
    
    echo -e "   PID: $pid"
    echo -e "   Log: $log_file"
    
    # PIDファイルに保存
    echo "$pid" >> "$LOG_DIR/pids.txt"
    
    # 起動を少し待つ（ポートがリッスンを開始するまで）
    sleep 4
    
    # ポート接続確認
    local max_retries=10
    local retry_count=0
    while [ $retry_count -lt $max_retries ]; do
        if lsof -ti:$local_port >/dev/null 2>&1; then
            echo -e "   ${GREEN}✅ ポート $local_port がリッスン中${NC}"
            break
        fi
        
        # プロセスがまだ存在するか確認
        if ! kill -0 $pid 2>/dev/null; then
            echo -e "   ${RED}❌ プロセスが終了しました${NC}"
            echo -e "   ${YELLOW}💡 ログの内容:${NC}"
            if [ -f "$log_file" ] && [ -s "$log_file" ]; then
                tail -10 "$log_file" 2>/dev/null | sed 's/^/      /'
            else
                echo -e "      ${RED}(ログが空です - AWS Session Manager Pluginがインストールされているか確認してください)${NC}"
            fi
            break
        fi
        
        retry_count=$((retry_count + 1))
        if [ $retry_count -lt $max_retries ]; then
            echo -e "   ${YELLOW}⏳ 待機中... ($retry_count/$max_retries)${NC}"
            sleep 2
        else
            echo -e "   ${RED}⚠️  ポートのリッスンを確認できませんでした${NC}"
            echo -e "   ${YELLOW}💡 ログの内容:${NC}"
            if [ -f "$log_file" ] && [ -s "$log_file" ]; then
                tail -10 "$log_file" 2>/dev/null | sed 's/^/      /'
            else
                echo -e "      ${RED}(ログが空です - プロセスが正常に起動していない可能性があります)${NC}"
            fi
        fi
    done
    
    echo ""
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

if [ -n "$PRIVATE_IP_E" ] && [ "$PRIVATE_IP_E" != "None" ]; then
    start_port_forward "Terraria Server" "$PRIVATE_IP_E" "22" "2225"
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
echo -e "  🖥️  Terraria Server: ssh -i minecraft.pem -p 2225 ec2-user@localhost"
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

