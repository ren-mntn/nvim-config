#!/bin/bash

#############################################################################
# Neovimエラー検出・アラートシステム
# 機能概要: Neovim `:messages` 監視とエラー自動検出・分析・通知
# 設定内容: エラー分類、アラート条件、修復提案、統合検証
# 使用方法: ./scripts/nvim_error_monitor.sh [--watch] [--analyze] [--fix-suggestions]
#############################################################################

set -eo pipefail

# 設定
readonly NVIM_CONFIG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly LOG_DIR="${NVIM_CONFIG_DIR}/logs"
readonly ERROR_LOG="${LOG_DIR}/nvim_errors.log"
readonly ALERT_LOG="${LOG_DIR}/error_alerts.log"
readonly TEMP_MESSAGES="/tmp/nvim_messages_$$"

# エラーパターン設定（連想配列の代替実装）
get_error_pattern() {
    case "$1" in
        "syntax_error") echo "E[0-9]+:.*syntax.*error|E[0-9]+:.*unexpected.*token|E[0-9]+:.*parse.*error" ;;
        "plugin_error") echo "Error.*plugin|Failed.*plugin|plugin.*failed|Plugin.*not.*found" ;;
        "lsp_error") echo "LSP.*error|Language.*server.*error|client.*[0-9]+.*quit.*with.*exit.*code|No.*client.*with.*id" ;;
        "lua_error") echo "Error.*lua|lua.*error|E[0-9]+:.*Error.*lua|attempt.*to.*call.*nil" ;;
        "config_error") echo "Invalid.*config|Config.*error|bad.*config|configuration.*failed" ;;
        "memory_warning") echo "warning.*memory|memory.*leak|out.*of.*memory|allocation.*failed" ;;
        "performance_warning") echo "slow.*startup|timeout.*loading|performance.*warning|took.*too.*long" ;;
        *) echo "" ;;
    esac
}

get_alert_level() {
    case "$1" in
        "syntax_error"|"lua_error") echo "CRITICAL" ;;
        "plugin_error"|"lsp_error"|"config_error") echo "HIGH" ;;
        "memory_warning") echo "MEDIUM" ;;
        "performance_warning") echo "LOW" ;;
        *) echo "INFO" ;;
    esac
}

get_fix_suggestion() {
    case "$1" in
        "syntax_error") echo "構文エラーを修正してください。luac -p <file> で事前チェック可能です。" ;;
        "plugin_error") echo "プラグイン設定を確認してください。:Lazy reload <plugin-name> で再読み込み可能です。" ;;
        "lsp_error") echo "LSP設定を確認してください。:LspInfo でサーバー状態を確認できます。" ;;
        "lua_error") echo "Lua設定エラーです。設定ファイルの構文を確認してください。" ;;
        "config_error") echo "設定エラーです。./scripts/nvim_config_validator.sh で検証してください。" ;;
        "memory_warning") echo "メモリ使用量を確認してください。起動時間測定で重いプラグインを特定可能です。" ;;
        "performance_warning") echo "パフォーマンスが低下しています。./scripts/nvim_startup_benchmark.sh で測定してください。" ;;
        *) echo "問題の詳細を確認してください。" ;;
    esac
}

# エラータイプのリスト
readonly ERROR_TYPES="syntax_error plugin_error lsp_error lua_error config_error memory_warning performance_warning"

# 統計変数
ERROR_COUNT=0
WARNING_COUNT=0
CRITICAL_COUNT=0
LAST_CHECK_TIME=0

# オプション設定
WATCH_MODE=false
ANALYZE_MODE=false
FIX_SUGGESTIONS_MODE=false
QUIET_MODE=false
VERBOSE_MODE=false

# カラーコード
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m' # No Color

# ヘルプメッセージ
show_help() {
    cat << EOF
Neovimエラー検出・アラートシステム

使用方法:
  $0 [オプション]

オプション:
  -w, --watch         継続監視モード（リアルタイムエラー検出）
  -a, --analyze       既存エラーログ分析モード
  -f, --fix-suggestions  修復提案を表示
  -q, --quiet         簡潔な出力
  -v, --verbose       詳細出力
  -h, --help          このヘルプを表示

検出エラータイプ:
  🔥 CRITICAL: 構文エラー、Luaランタイムエラー
  ⚠️ HIGH:     プラグインエラー、LSPエラー、設定エラー
  ⚡ MEDIUM:   メモリ警告
  📊 LOW:      パフォーマンス警告

例:
  $0                           # 単発チェック
  $0 --watch                   # リアルタイム監視開始
  $0 --analyze                 # 過去のエラーを分析
  $0 --fix-suggestions         # 修復提案付きで分析
EOF
}

# ログ初期化
init_logging() {
    mkdir -p "${LOG_DIR}"
    
    {
        echo "=== Neovim Error Monitor ==="
        echo "Date: $(date)"
        echo "Config Dir: ${NVIM_CONFIG_DIR}"
        echo "Mode: $([ "${WATCH_MODE}" = true ] && echo "Watch" || echo "Check")"
        echo ""
    } > "${ERROR_LOG}"
}

# クリーンアップ
cleanup() {
    rm -f "${TEMP_MESSAGES}" 2>/dev/null || true
}
trap cleanup EXIT

# カラー出力関数
print_alert() {
    local level="$1"
    local message="$2"
    
    if [[ "${QUIET_MODE}" == "true" ]]; then
        return
    fi
    
    case "${level}" in
        "CRITICAL")
            echo -e "${RED}🔥 CRITICAL: ${message}${NC}"
            ;;
        "HIGH")
            echo -e "${YELLOW}⚠️ HIGH: ${message}${NC}"
            ;;
        "MEDIUM")
            echo -e "${BLUE}⚡ MEDIUM: ${message}${NC}"
            ;;
        "LOW")
            echo -e "${CYAN}📊 LOW: ${message}${NC}"
            ;;
        "INFO")
            echo -e "${GREEN}ℹ️ INFO: ${message}${NC}"
            ;;
    esac
}

# Neovimメッセージの取得
get_nvim_messages() {
    # Neovim headlessモードでメッセージを取得
    nvim --headless -c 'redir! > '"${TEMP_MESSAGES}"' | messages | redir END | qall' 2>/dev/null || {
        # メッセージファイルが空の場合の処理
        touch "${TEMP_MESSAGES}"
    }
    
    # メッセージファイルが存在して読み取り可能な場合のみ処理
    if [[ -f "${TEMP_MESSAGES}" && -r "${TEMP_MESSAGES}" ]]; then
        cat "${TEMP_MESSAGES}"
    fi
}

# エラーパターンマッチング
match_error_patterns() {
    local message="$1"
    local matched_patterns=()
    
    for pattern_name in ${ERROR_TYPES}; do
        local pattern=$(get_error_pattern "${pattern_name}")
        
        # grep -E でマッチングを行う
        if [[ -n "${pattern}" ]] && echo "${message}" | grep -qiE "${pattern}"; then
            matched_patterns+=("${pattern_name}")
        fi
    done
    
    # マッチしたパターンを返す
    printf '%s\n' "${matched_patterns[@]}"
}

# エラー分析
analyze_error() {
    local message="$1"
    local timestamp="$2"
    
    # パターンマッチング
    local matched_patterns
    matched_patterns=$(match_error_patterns "${message}")
    
    if [[ -n "${matched_patterns}" ]]; then
        while IFS= read -r pattern; do
            local level=$(get_alert_level "${pattern}")
            local suggestion=$(get_fix_suggestion "${pattern}")
            
            # アラート出力
            print_alert "${level}" "${pattern}: ${message}"
            
            # 修復提案の表示
            if [[ "${FIX_SUGGESTIONS_MODE}" == "true" ]]; then
                echo -e "  💡 ${suggestion}"
            fi
            
            # 統計更新
            case "${level}" in
                "CRITICAL")
                    ((CRITICAL_COUNT++))
                    ;;
                "HIGH"|"MEDIUM")
                    ((ERROR_COUNT++))
                    ;;
                "LOW")
                    ((WARNING_COUNT++))
                    ;;
            esac
            
            # アラートログに記録
            {
                echo "${timestamp} [${level}] ${pattern}: ${message}"
                if [[ "${FIX_SUGGESTIONS_MODE}" == "true" ]]; then
                    echo "    Suggestion: ${suggestion}"
                fi
                echo ""
            } >> "${ALERT_LOG}"
            
        done <<< "${matched_patterns}"
    fi
}

# 既存エラーログの分析
analyze_existing_errors() {
    print_alert "INFO" "既存エラーログの分析を開始します..."
    
    local messages
    messages=$(get_nvim_messages)
    
    if [[ -z "${messages}" ]]; then
        print_alert "INFO" "現在のNeovimメッセージは空です。"
        return 0
    fi
    
    local current_time
    current_time=$(date)
    
    # 各行を分析
    while IFS= read -r line; do
        if [[ -n "${line}" ]]; then
            analyze_error "${line}" "${current_time}"
        fi
    done <<< "${messages}"
}

# 継続監視モード
watch_mode() {
    print_alert "INFO" "Neovimエラー継続監視を開始します... (Ctrl+C で停止)"
    local pattern_count=$(echo "${ERROR_TYPES}" | wc -w | tr -d ' \t\n\r')
    print_alert "INFO" "監視中のパターン: ${pattern_count}種類"
    
    local check_interval=5  # 秒
    
    while true; do
        local current_messages
        current_messages=$(get_nvim_messages)
        
        # 前回チェック時から新しいメッセージがあるかチェック
        local current_hash
        current_hash=$(echo "${current_messages}" | sha256sum | cut -d' ' -f1 2>/dev/null || echo "none")
        
        if [[ "${current_hash}" != "${LAST_CHECK_TIME}" ]]; then
            LAST_CHECK_TIME="${current_hash}"
            
            # メッセージが空でない場合のみ分析
            if [[ -n "${current_messages}" ]]; then
                local timestamp
                timestamp=$(date)
                
                while IFS= read -r line; do
                    if [[ -n "${line}" ]]; then
                        analyze_error "${line}" "${timestamp}"
                    fi
                done <<< "${current_messages}"
            fi
        fi
        
        sleep "${check_interval}"
    done
}

# Neovim設定統合検証
perform_integrated_check() {
    print_alert "INFO" "統合検証を実行します..."
    
    # 1. 構文チェック
    if [[ -x "${NVIM_CONFIG_DIR}/scripts/nvim_config_validator.sh" ]]; then
        print_alert "INFO" "設定ファイル構文検証を実行中..."
        "${NVIM_CONFIG_DIR}/scripts/nvim_config_validator.sh" --quiet > /dev/null || {
            print_alert "HIGH" "設定ファイルに構文エラーが検出されました"
            ((ERROR_COUNT++))
        }
    fi
    
    # 2. 起動時間チェック
    if [[ -x "${NVIM_CONFIG_DIR}/scripts/nvim_startup_benchmark.sh" ]]; then
        print_alert "INFO" "起動時間測定を実行中..."
        local startup_time
        startup_time=$("${NVIM_CONFIG_DIR}/scripts/nvim_startup_benchmark.sh" --quiet --times 1 2>/dev/null | \
            grep "平均時間:" | awk '{print $2}' | sed 's/ms//') 
            
        if [[ -n "${startup_time}" ]] && [[ "${startup_time}" =~ ^[0-9]+\.?[0-9]*$ ]]; then
            if (( $(echo "${startup_time} > 2000" | bc -l 2>/dev/null || echo 0) )); then
                print_alert "HIGH" "起動時間が遅すぎます (${startup_time}ms)"
                ((ERROR_COUNT++))
            elif (( $(echo "${startup_time} > 1000" | bc -l 2>/dev/null || echo 0) )); then
                print_alert "MEDIUM" "起動時間が長めです (${startup_time}ms)"
                ((WARNING_COUNT++))
            fi
        fi
    fi
    
    # 3. Neovimテストロード
    print_alert "INFO" "Neovim設定テストロードを実行中..."
    local load_result
    load_result=$(nvim --headless +qall 2>&1)
    
    if [[ -n "${load_result}" ]]; then
        print_alert "HIGH" "Neovim設定ロード時にメッセージが出力されました"
        if [[ "${VERBOSE_MODE}" == "true" ]]; then
            echo -e "${YELLOW}${load_result}${NC}"
        fi
        ((ERROR_COUNT++))
    fi
}

# 結果サマリー
show_summary() {
    local total_issues=$((CRITICAL_COUNT + ERROR_COUNT + WARNING_COUNT))
    
    echo ""
    print_alert "INFO" "エラー監視結果サマリー"
    echo "  🔥 重要エラー: ${CRITICAL_COUNT}"
    echo "  ⚠️ エラー: ${ERROR_COUNT}"
    echo "  📊 警告: ${WARNING_COUNT}"
    echo "  📈 総問題数: ${total_issues}"
    
    if [[ "${total_issues}" -eq "0" ]]; then
        print_alert "INFO" "問題は検出されませんでした！ ✨"
    else
        print_alert "INFO" "詳細なアラートログ: ${ALERT_LOG}"
    fi
    
    # ログファイルに記録
    {
        echo "=== Summary ==="
        echo "Critical: ${CRITICAL_COUNT}"
        echo "Errors: ${ERROR_COUNT}"
        echo "Warnings: ${WARNING_COUNT}"
        echo "Total: ${total_issues}"
        echo "Check completed at: $(date)"
    } >> "${ERROR_LOG}"
}

# メイン処理
main() {
    init_logging
    
    if [[ "${WATCH_MODE}" == "true" ]]; then
        watch_mode
    else
        if [[ "${ANALYZE_MODE}" == "true" ]]; then
            analyze_existing_errors
        fi
        
        # 統合検証の実行
        perform_integrated_check
        
        # 結果表示
        show_summary
    fi
}

# シグナルハンドラー（Ctrl+C対応）
handle_interrupt() {
    echo ""
    print_alert "INFO" "監視を停止しています..."
    show_summary
    exit 0
}
trap handle_interrupt SIGINT SIGTERM

# コマンドライン引数の解析
while [[ $# -gt 0 ]]; do
    case $1 in
        -w|--watch)
            WATCH_MODE=true
            shift
            ;;
        -a|--analyze)
            ANALYZE_MODE=true
            shift
            ;;
        -f|--fix-suggestions)
            FIX_SUGGESTIONS_MODE=true
            shift
            ;;
        -q|--quiet)
            QUIET_MODE=true
            shift
            ;;
        -v|--verbose)
            VERBOSE_MODE=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "ERROR: Unknown option: $1" >&2
            echo "Use --help for usage information." >&2
            exit 1
            ;;
    esac
done

# 依存関係チェック
missing_deps=()
if ! command -v nvim &> /dev/null; then
    missing_deps+=("nvim")
fi
if ! command -v bc &> /dev/null; then
    missing_deps+=("bc")
fi

if [[ "${#missing_deps[@]}" -gt "0" ]]; then
    print_alert "HIGH" "必要なコマンドが見つかりません: ${missing_deps[*]}"
    print_alert "INFO" "インストール: brew install ${missing_deps[*]// / }"
    exit 1
fi

# メイン実行
main "$@"