#!/bin/bash
# ================================================================
# MC Server World Data Upload to S3
# ================================================================
# 既存のMCサーバーワールドデータをS3にアップロードするスクリプト
# ================================================================

set -e

# 設定
BUCKET="kishax-production-world-backups"
REGION="ap-northeast-1"
AWS_PROFILE="AdministratorAccess-126112056177"
DATE=$(date +%Y%m%d)
YEAR_MONTH=$(date +%Y%m)
VERSION="1"

# ローカルデータディレクトリ
DATA_DIR="./data"

# カラー出力
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ヘルパー関数
print_header() {
    echo -e "${BLUE}=== $1 ===${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# 前提条件チェック
check_prerequisites() {
    print_header "前提条件チェック"
    
    # AWS CLI
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI がインストールされていません"
        exit 1
    fi
    print_success "AWS CLI インストール済み"
    
    # データディレクトリ
    if [ ! -d "$DATA_DIR" ]; then
        print_error "データディレクトリが見つかりません: $DATA_DIR"
        exit 1
    fi
    print_success "データディレクトリ確認: $DATA_DIR"
    
    # AWS認証
    if ! aws sts get-caller-identity --profile "$AWS_PROFILE" &> /dev/null; then
        print_error "AWS認証に失敗しました"
        print_info "以下のコマンドを実行してください:"
        print_info "  aws sso login --profile $AWS_PROFILE"
        exit 1
    fi
    print_success "AWS認証確認"
    
    echo ""
}

# データサイズ確認
check_data_size() {
    print_header "データサイズ確認"
    
    echo "📊 サーバーごとのサイズ:"
    for server_dir in "$DATA_DIR"/*; do
        if [ -d "$server_dir" ]; then
            server_name=$(basename "$server_dir")
            size=$(du -sh "$server_dir" | cut -f1)
            echo "  - $server_name: $size"
        fi
    done
    
    total_size=$(du -sh "$DATA_DIR" | cut -f1)
    echo ""
    echo "💾 合計サイズ: $total_size"
    echo ""
}

# アップロード先の確認
show_upload_destination() {
    print_header "アップロード先"
    
    echo "📍 S3バケット: s3://$BUCKET/"
    echo "📂 プレフィックス: deployment/$YEAR_MONTH/$VERSION/"
    echo ""
    
    for server_dir in "$DATA_DIR"/*; do
        if [ -d "$server_dir" ]; then
            server_name=$(basename "$server_dir")
            echo "  $server_name → s3://$BUCKET/deployment/$YEAR_MONTH/$VERSION/$server_name/"
        fi
    done
    echo ""
}

# アップロード（サーバー単位）
upload_server() {
    local server_name=$1
    local server_dir="$DATA_DIR/$server_name"
    local s3_prefix="deployment/$YEAR_MONTH/$VERSION/$server_name"
    
    print_header "アップロード: $server_name"
    
    # ワールドディレクトリを検出
    world_dirs=$(find "$server_dir" -name "world*" -type d -maxdepth 1)
    
    if [ -z "$world_dirs" ]; then
        print_warning "ワールドディレクトリが見つかりません: $server_dir"
        return
    fi
    
    # 各ワールドディレクトリをアップロード
    for world_dir in $world_dirs; do
        world_name=$(basename "$world_dir")
        
        print_info "📦 $world_name をアップロード中..."
        
        # ドライラン（オプション）
        if [ "$DRY_RUN" = "true" ]; then
            aws s3 sync "$world_dir/" "s3://$BUCKET/$s3_prefix/$world_name/" \
                --profile "$AWS_PROFILE" \
                --region "$REGION" \
                --dryrun
        else
            aws s3 sync "$world_dir/" "s3://$BUCKET/$s3_prefix/$world_name/" \
                --profile "$AWS_PROFILE" \
                --region "$REGION" \
                --no-progress
        fi
        
        if [ $? -eq 0 ]; then
            print_success "$world_name アップロード完了"
        else
            print_error "$world_name アップロード失敗"
            return 1
        fi
    done
    
    # メタデータファイル作成
    if [ "$DRY_RUN" != "true" ]; then
        print_info "📝 メタデータファイル作成中..."
        
        cat > /tmp/metadata.json <<EOF
{
  "server": "$server_name",
  "upload_date": "$DATE",
  "year_month": "$YEAR_MONTH",
  "version": "$VERSION",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "worlds": [
EOF
        
        first=true
        for world_dir in $world_dirs; do
            world_name=$(basename "$world_dir")
            if [ "$first" = true ]; then
                first=false
            else
                echo "," >> /tmp/metadata.json
            fi
            echo "    \"$world_name\"" >> /tmp/metadata.json
        done
        
        cat >> /tmp/metadata.json <<EOF

  ]
}
EOF
        
        aws s3 cp /tmp/metadata.json "s3://$BUCKET/$s3_prefix/metadata.json" \
            --profile "$AWS_PROFILE" \
            --region "$REGION"
        
        rm /tmp/metadata.json
        
        print_success "メタデータファイル作成完了"
    fi
    
    echo ""
}

# __IMPORT_ENABLED__ フラグ作成
create_import_flag() {
    local server_name=$1
    local s3_prefix="deployment/$YEAR_MONTH/$VERSION/$server_name"
    
    print_info "🏁 インポートフラグ作成: $server_name"
    
    if [ "$DRY_RUN" != "true" ]; then
        echo "Uploaded at $(date)" | aws s3 cp - "s3://$BUCKET/$s3_prefix/__IMPORT_ENABLED__" \
            --profile "$AWS_PROFILE" \
            --region "$REGION"
        
        if [ $? -eq 0 ]; then
            print_success "__IMPORT_ENABLED__ 作成完了"
        else
            print_warning "__IMPORT_ENABLED__ 作成失敗"
        fi
    else
        print_info "(dryrun) __IMPORT_ENABLED__ 作成をスキップ"
    fi
    
    echo ""
}

# アップロード結果確認
verify_upload() {
    local server_name=$1
    local s3_prefix="deployment/$YEAR_MONTH/$VERSION/$server_name"
    
    print_header "アップロード結果確認: $server_name"
    
    if [ "$DRY_RUN" != "true" ]; then
        aws s3 ls "s3://$BUCKET/$s3_prefix/" \
            --profile "$AWS_PROFILE" \
            --region "$REGION" \
            --recursive \
            --summarize \
            --human-readable | tail -10
    else
        print_info "(dryrun) 結果確認をスキップ"
    fi
    
    echo ""
}

# メイン処理
main() {
    clear
    
    print_header "MC Server World Data Upload to S3"
    echo "📅 日付: $DATE"
    echo "📍 バケット: $BUCKET"
    echo "🔧 AWS Profile: $AWS_PROFILE"
    echo ""
    
    # 前提条件チェック
    check_prerequisites
    
    # データサイズ確認
    check_data_size
    
    # アップロード先確認
    show_upload_destination
    
    # 確認プロンプト
    if [ "$DRY_RUN" = "true" ]; then
        print_warning "🧪 ドライランモード（実際にはアップロードしません）"
        echo ""
    else
        print_warning "⚠️  実際にS3にアップロードします"
        read -p "続行しますか？ (yes/no): " answer
        if [ "$answer" != "yes" ]; then
            print_info "キャンセルしました"
            exit 0
        fi
        echo ""
    fi
    
    # 各サーバーのアップロード
    for server_dir in "$DATA_DIR"/*; do
        if [ -d "$server_dir" ]; then
            server_name=$(basename "$server_dir")
            
            # アップロード
            upload_server "$server_name"
            
            # インポートフラグ作成
            create_import_flag "$server_name"
            
            # 結果確認
            verify_upload "$server_name"
        fi
    done
    
    # 完了
    print_header "完了"
    print_success "全サーバーのアップロードが完了しました！"
    echo ""
    print_info "次のステップ:"
    print_info "1. S3の内容を確認:"
    print_info "   aws s3 ls s3://$BUCKET/deployment/$YEAR_MONTH/$VERSION/ --profile $AWS_PROFILE"
    print_info ""
    print_info "2. EC2でワールドデータをインポート:"
    print_info "   - servers.json で s3import: true に設定"
    print_info "   - Docker コンテナを起動"
    echo ""
}

# オプション解析
DRY_RUN=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --dry-run    実際にはアップロードせず、何が実行されるか確認"
            echo "  --help       このヘルプを表示"
            echo ""
            echo "Examples:"
            echo "  $0 --dry-run    # ドライラン"
            echo "  $0              # 実際にアップロード"
            exit 0
            ;;
        *)
            print_error "不明なオプション: $1"
            print_info "$0 --help でヘルプを表示"
            exit 1
            ;;
    esac
done

# メイン処理実行
main
