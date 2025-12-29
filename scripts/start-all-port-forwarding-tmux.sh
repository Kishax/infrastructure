#!/bin/bash

# Kishax Infrastructure - 全ポートフォワーディング起動スクリプト (tmux版)
# 全てのSSMポートフォワーディングセッションをtmuxセッション内で起動します

set -e

# 設定
AWS_PROFILE="${AWS_PROFILE:-AdministratorAccess-126112056177}"
AWS_REGION="${AWS_REGION:-ap-northeast-1}"
ENVIRONMENT="${ENVIRONMENT:-production}"
TMUX_SESSION_NAME="kishax-ssm-forwarding"

# 色コード
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Kishax Infrastructure - 全ポートフォワーディング起動 (tmux版)${NC}"
echo ""

# tmuxがインストールされているか確認
if ! command -v tmux &> /dev/null; then
    echo -e "${RED}❌ tmuxがインストールされていません${NC}"
    echo -e "${YELLOW}💡 インストール方法:${NC}"
    echo -e "   macOS: brew install tmux"
    echo -e "   Ubuntu/Debian: sudo apt-get install tmux"
    exit 1
fi

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

# 既存のtmuxセッションを確認
if tmux has-session -t "$TMUX_SESSION_NAME" 2>/dev/null; then
    echo ""
    echo -e "${YELLOW}⚠️  既存のtmuxセッション '$TMUX_SESSION_NAME' が見つかりました${NC}"
    read -p "停止して再起動しますか？ (y/N): " answer
    if [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
        tmux kill-session -t "$TMUX_SESSION_NAME"
        echo -e "${GREEN}✅ 既存のセッションを停止しました${NC}"
    else
        echo -e "${YELLOW}⏭️  スキップしました${NC}"
        echo -e "${BLUE}💡 セッションにアタッチするには: tmux attach -t $TMUX_SESSION_NAME${NC}"
        exit 0
    fi
fi

echo ""
echo -e "${BLUE}🚀 tmuxセッションを作成してポートフォワーディングを起動中...${NC}"
echo ""

# tmuxセッションを作成
tmux new-session -d -s "$TMUX_SESSION_NAME" -n "mc"

# 各ウィンドウでポートフォワーディングを起動
if [ -n "$PRIVATE_IP_A" ] && [ "$PRIVATE_IP_A" != "None" ]; then
    echo -e "${BLUE}🔗 MC Server (localhost:2222)${NC}"
    tmux send-keys -t "$TMUX_SESSION_NAME:mc" "aws ssm start-session --target $INSTANCE_ID_D --document-name AWS-StartPortForwardingSessionToRemoteHost --parameters '{\"host\":[\"$PRIVATE_IP_A\"],\"portNumber\":[\"22\"],\"localPortNumber\":[\"2222\"]}' --profile $AWS_PROFILE" C-m
fi

if [ -n "$PRIVATE_IP_B" ] && [ "$PRIVATE_IP_B" != "None" ]; then
    echo -e "${BLUE}🔗 API Server (localhost:2223)${NC}"
    tmux new-window -t "$TMUX_SESSION_NAME" -n "api"
    tmux send-keys -t "$TMUX_SESSION_NAME:api" "aws ssm start-session --target $INSTANCE_ID_D --document-name AWS-StartPortForwardingSessionToRemoteHost --parameters '{\"host\":[\"$PRIVATE_IP_B\"],\"portNumber\":[\"22\"],\"localPortNumber\":[\"2223\"]}' --profile $AWS_PROFILE" C-m
fi

if [ -n "$PRIVATE_IP_C" ] && [ "$PRIVATE_IP_C" != "None" ]; then
    echo -e "${BLUE}🔗 Web Server (localhost:2224)${NC}"
    tmux new-window -t "$TMUX_SESSION_NAME" -n "web"
    tmux send-keys -t "$TMUX_SESSION_NAME:web" "aws ssm start-session --target $INSTANCE_ID_D --document-name AWS-StartPortForwardingSessionToRemoteHost --parameters '{\"host\":[\"$PRIVATE_IP_C\"],\"portNumber\":[\"22\"],\"localPortNumber\":[\"2224\"]}' --profile $AWS_PROFILE" C-m
fi

if [ -n "$RDS_MYSQL_HOST" ] && [ "$RDS_MYSQL_HOST" != "None" ]; then
    echo -e "${BLUE}🔗 RDS MySQL (localhost:3307)${NC}"
    tmux new-window -t "$TMUX_SESSION_NAME" -n "mysql"
    tmux send-keys -t "$TMUX_SESSION_NAME:mysql" "aws ssm start-session --target $INSTANCE_ID_D --document-name AWS-StartPortForwardingSessionToRemoteHost --parameters '{\"host\":[\"$RDS_MYSQL_HOST\"],\"portNumber\":[\"${RDS_MYSQL_PORT:-3306}\"],\"localPortNumber\":[\"3307\"]}' --profile $AWS_PROFILE" C-m
fi

if [ -n "$RDS_POSTGRES_HOST" ] && [ "$RDS_POSTGRES_HOST" != "None" ]; then
    echo -e "${BLUE}🔗 RDS PostgreSQL (localhost:5433)${NC}"
    tmux new-window -t "$TMUX_SESSION_NAME" -n "postgres"
    tmux send-keys -t "$TMUX_SESSION_NAME:postgres" "aws ssm start-session --target $INSTANCE_ID_D --document-name AWS-StartPortForwardingSessionToRemoteHost --parameters '{\"host\":[\"$RDS_POSTGRES_HOST\"],\"portNumber\":[\"${RDS_POSTGRES_PORT:-5432}\"],\"localPortNumber\":[\"5433\"]}' --profile $AWS_PROFILE" C-m
fi

# 起動を待つ
echo ""
echo -e "${YELLOW}⏳ ポートフォワーディングの起動を待機中... (10秒)${NC}"
sleep 10

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
echo -e "${BLUE}📝 tmux操作:${NC}"
echo -e "  セッション確認:     tmux ls"
echo -e "  セッションにアタッチ: tmux attach -t $TMUX_SESSION_NAME"
echo -e "  セッションから離脱: Ctrl+B → D"
echo -e "  ウィンドウ切り替え: Ctrl+B → 数字キー"
echo -e "  セッション停止:     make ssm-stop-all"
echo ""
echo -e "${YELLOW}⚠️  注意:${NC}"
echo -e "  - ポートフォワーディングはtmuxセッション内で実行されています"
echo -e "  - ターミナルを閉じてもセッションは継続します"
echo -e "  - 停止するには: make ssm-stop-all または tmux kill-session -t $TMUX_SESSION_NAME"
echo ""

