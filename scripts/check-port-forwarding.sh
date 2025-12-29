#!/bin/bash

# ポート使用状況の詳細確認スクリプト

echo "=========================================="
echo "  SSM ポートフォワーディング 詳細確認"
echo "=========================================="
echo ""

echo "=== 1. 各ポートの使用状況 (lsof) ==="
echo ""

ports=(2222 2223 2224 3307 5433)
port_names=("MC Server" "API Server" "Web Server" "RDS MySQL" "RDS PostgreSQL")

for i in "${!ports[@]}"; do
    port="${ports[$i]}"
    name="${port_names[$i]}"
    
    echo "📊 Port $port ($name):"
    result=$(lsof -i :$port 2>/dev/null)
    if [ -n "$result" ]; then
        echo "$result"
    else
        echo "  ❌ ポートは使用されていません"
    fi
    echo ""
done

echo "=========================================="
echo ""
echo "=== 2. AWS SSM プロセス確認 ==="
echo ""

ssm_procs=$(ps aux | grep -E "(aws ssm start-session|session-manager-plugin)" | grep -v grep)
if [ -n "$ssm_procs" ]; then
    echo "$ssm_procs"
else
    echo "❌ AWS SSMプロセスが見つかりません"
fi
echo ""

echo "=========================================="
echo ""
echo "=== 3. PIDファイル確認 ==="
echo ""

if [ -f ~/.kishax-ssm-logs/pids.txt ]; then
    echo "📋 PID File: ~/.kishax-ssm-logs/pids.txt"
    echo ""
    echo "登録されているPID:"
    cat ~/.kishax-ssm-logs/pids.txt
    echo ""
    echo "各PIDの状態:"
    while read pid; do
        if [ -n "$pid" ]; then
            if ps -p $pid > /dev/null 2>&1; then
                echo "  ✅ PID $pid: 実行中"
                ps -p $pid -o pid,etime,command | grep -v PID
            else
                echo "  ❌ PID $pid: 停止"
            fi
        fi
    done < ~/.kishax-ssm-logs/pids.txt
else
    echo "❌ PIDファイルが見つかりません: ~/.kishax-ssm-logs/pids.txt"
fi
echo ""

echo "=========================================="
echo ""
echo "=== 4. ログファイル確認 ==="
echo ""

if [ -d ~/.kishax-ssm-logs ]; then
    echo "📁 ログディレクトリ: ~/.kishax-ssm-logs"
    echo ""
    
    log_files=(~/.kishax-ssm-logs/*.log)
    if [ -e "${log_files[0]}" ]; then
        for log_file in "${log_files[@]}"; do
            echo "📄 $(basename "$log_file"):"
            echo "   サイズ: $(ls -lh "$log_file" | awk '{print $5}')"
            echo "   更新: $(ls -l "$log_file" | awk '{print $6, $7, $8}')"
            
            if [ -s "$log_file" ]; then
                echo "   内容（最後の5行）:"
                tail -5 "$log_file" 2>/dev/null | sed 's/^/     /'
            else
                echo "   ⚠️  ログが空です"
            fi
            echo ""
        done
    else
        echo "❌ ログファイルが見つかりません"
    fi
else
    echo "❌ ログディレクトリが存在しません: ~/.kishax-ssm-logs"
fi
echo ""

echo "=========================================="
echo ""
echo "=== 5. tmuxセッション確認 ==="
echo ""

if command -v tmux &> /dev/null; then
    tmux_sessions=$(tmux ls 2>/dev/null)
    if [ $? -eq 0 ]; then
        echo "📺 tmuxセッション:"
        echo "$tmux_sessions"
        echo ""
        
        if tmux has-session -t kishax-ssm-forwarding 2>/dev/null; then
            echo "✅ kishax-ssm-forwarding セッションが存在します"
            echo ""
            echo "ウィンドウ一覧:"
            tmux list-windows -t kishax-ssm-forwarding
        else
            echo "❌ kishax-ssm-forwarding セッションは存在しません"
        fi
    else
        echo "❌ tmuxセッションが見つかりません"
    fi
else
    echo "❌ tmuxがインストールされていません"
fi
echo ""

echo "=========================================="
echo ""
echo "=== 推奨アクション ==="
echo ""

# ポートが使用されているかチェック
any_port_used=false
for port in "${ports[@]}"; do
    if lsof -i :$port >/dev/null 2>&1; then
        any_port_used=true
        break
    fi
done

if [ "$any_port_used" = true ]; then
    echo "✅ ポートフォワーディングは正常に動作しています"
    echo ""
    echo "接続方法:"
    echo "  make ssh-mc       # MC Server"
    echo "  make ssh-api      # API Server"
    echo "  make ssh-web      # Web Server"
    echo "  make ssh-mysql    # MySQL"
    echo "  make ssh-postgres # PostgreSQL"
else
    echo "❌ ポートフォワーディングが動作していません"
    echo ""
    echo "起動方法:"
    echo "  make ssm-start-all-tmux  # tmux版（推奨）"
    echo "  make ssm-start-all       # バックグラウンド版"
fi

echo ""

