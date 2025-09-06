#!/bin/bash

#############################################################################
# Neovim起動時間測定・分析スクリプト
# 機能概要: Neovim起動時間を測定し、パフォーマンス分析結果を出力
# 設定内容: プラグイン別時間、初期化段階別時間、比較機能
# 使用方法: ./scripts/nvim_startup_benchmark.sh [--compare] [--detail] [--times N]
#############################################################################

set -euo pipefail

# 設定
readonly NVIM_CONFIG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly LOG_DIR="${NVIM_CONFIG_DIR}/logs"
readonly BENCHMARK_LOG="${LOG_DIR}/startup_benchmark.log"
readonly BASELINE_FILE="${LOG_DIR}/startup_baseline.txt"
readonly TEMP_DIR="/tmp/nvim_benchmark_$$"

# パフォーマンス要件 (milliseconds)
readonly PERFORMANCE_TARGET_MS=1000
readonly PERFORMANCE_WARNING_MS=1500
readonly PERFORMANCE_CRITICAL_MS=2000

# オプション設定
COMPARE_MODE=false
DETAIL_MODE=false
RUN_TIMES=5
QUIET_MODE=false

# ヘルプメッセージ
show_help() {
    cat << EOF
Neovim起動時間ベンチマークツール

使用方法:
  $0 [オプション]

オプション:
  -c, --compare     ベースラインとの比較を実行
  -d, --detail      詳細分析を表示（プラグイン別時間など）
  -t, --times N     測定回数を指定 (デフォルト: 5)
  -q, --quiet       簡潔な出力
  -h, --help        このヘルプを表示

例:
  $0                    # 基本的な測定
  $0 --compare          # ベースラインとの比較
  $0 --detail --times 10  # 詳細分析、10回測定

パフォーマンス基準:
  - 目標: < ${PERFORMANCE_TARGET_MS}ms
  - 警告: < ${PERFORMANCE_WARNING_MS}ms  
  - 重要: > ${PERFORMANCE_CRITICAL_MS}ms (要改善)
EOF
}

# ログディレクトリの作成
init_logging() {
    mkdir -p "${LOG_DIR}"
    mkdir -p "${TEMP_DIR}"
    
    # ログファイルの初期化
    {
        echo "=== Neovim Startup Benchmark ==="
        echo "Date: $(date)"
        echo "Config Dir: ${NVIM_CONFIG_DIR}"
        echo "Neovim Version: $(nvim --version | head -1)"
        echo ""
    } > "${BENCHMARK_LOG}"
}

# クリーンアップ
cleanup() {
    rm -rf "${TEMP_DIR}" 2>/dev/null || true
}
trap cleanup EXIT

# 単一測定の実行
measure_startup() {
    local log_file="$1"
    local run_number="$2"
    
    # nvim --startuptime でログ出力
    nvim --headless --startuptime "${log_file}" +qall 2>/dev/null || {
        echo "ERROR: Neovim起動がタイムアウトしました (run #${run_number})" >&2
        return 1
    }
}

# 起動時間の解析
parse_startup_log() {
    local log_file="$1"
    
    # 総起動時間を取得
    local total_time
    if [[ -f "${log_file}" && -s "${log_file}" ]]; then
        total_time=$(tail -1 "${log_file}" | awk '{print $1}')
        # 数値でない場合は空行より前を確認
        if ! [[ "${total_time}" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
            total_time=$(tail -5 "${log_file}" | grep -E '^[0-9]+\.[0-9]+' | tail -1 | awk '{print $1}')
        fi
    else
        total_time="0"
    fi
    
    echo "${total_time}"
}

# 詳細分析（プラグイン別時間など）
analyze_detailed() {
    local log_file="$1"
    
    if [[ "${DETAIL_MODE}" != "true" ]]; then
        return
    fi
    
    echo ""
    echo "=== 詳細分析 ==="
    
    # プラグイン別時間トップ10
    echo ""
    echo "📦 プラグイン別読み込み時間 (Top 10):"
    grep "sourcing" "${log_file}" | \
        awk '{time=$1; $1=$2=""; gsub(/^[ \t]+/, ""); print time " " $0}' | \
        sort -nr | \
        head -10 | \
        awk '{printf "  %6.2fms  %s\n", $1, substr($0, index($0, $2))}'
    
    # 初期化段階別分析
    echo ""
    echo "🚀 初期化段階別分析:"
    
    # 基本設定読み込み時間
    local config_time
    config_time=$(grep "config/.*\.lua" "${log_file}" | awk '{sum+=$1} END {printf "%.2f", sum}')
    echo "  設定ファイル読み込み: ${config_time}ms"
    
    # プラグイン初期化時間
    local plugin_time  
    plugin_time=$(grep "plugins/.*\.lua" "${log_file}" | awk '{sum+=$1} END {printf "%.2f", sum}')
    echo "  プラグイン初期化: ${plugin_time}ms"
    
    # LSP設定時間
    local lsp_time
    lsp_time=$(grep -i "lsp\|language.*server" "${log_file}" | awk '{sum+=$1} END {printf "%.2f", sum}')
    echo "  LSP設定: ${lsp_time}ms"
}

# ベースラインとの比較
compare_with_baseline() {
    local current_time="$1"
    
    if [[ ! -f "${BASELINE_FILE}" ]]; then
        echo "⚠️  ベースラインファイルが存在しません。現在の結果をベースラインとして保存します..."
        echo "${current_time}" > "${BASELINE_FILE}"
        return
    fi
    
    local baseline_time
    baseline_time=$(cat "${BASELINE_FILE}")
    
    local diff_time
    diff_time=$(echo "${current_time} - ${baseline_time}" | bc -l 2>/dev/null || echo "0")
    
    local diff_percent
    if [[ "${baseline_time}" != "0" ]]; then
        diff_percent=$(echo "scale=1; (${current_time} - ${baseline_time}) / ${baseline_time} * 100" | bc -l 2>/dev/null || echo "0")
    else
        diff_percent="0"
    fi
    
    echo ""
    echo "=== ベースライン比較 ==="
    echo "  ベースライン: ${baseline_time}ms"
    echo "  現在の結果: ${current_time}ms"
    
    if (( $(echo "${diff_time} > 0" | bc -l) )); then
        echo "  📈 差分: +${diff_time}ms (+${diff_percent}%)"
        if (( $(echo "${diff_percent} > 20" | bc -l) )); then
            echo "  🚨 警告: 起動時間が20%以上悪化しています"
        fi
    else
        local abs_diff_time
        abs_diff_time=$(echo "${diff_time} * -1" | bc -l)
        local abs_diff_percent
        abs_diff_percent=$(echo "${diff_percent} * -1" | bc -l)
        echo "  📉 差分: -${abs_diff_time}ms (-${abs_diff_percent}%)"
        echo "  ✅ 改善されています"
    fi
}

# パフォーマンス評価
evaluate_performance() {
    local time_ms="$1"
    
    echo ""
    echo "=== パフォーマンス評価 ==="
    
    if (( $(echo "${time_ms} <= ${PERFORMANCE_TARGET_MS}" | bc -l) )); then
        echo "  ✅ 優秀 (<= ${PERFORMANCE_TARGET_MS}ms)"
    elif (( $(echo "${time_ms} <= ${PERFORMANCE_WARNING_MS}" | bc -l) )); then
        echo "  ⚠️  注意 (<= ${PERFORMANCE_WARNING_MS}ms)"
    elif (( $(echo "${time_ms} <= ${PERFORMANCE_CRITICAL_MS}" | bc -l) )); then
        echo "  🚨 警告 (<= ${PERFORMANCE_CRITICAL_MS}ms)"
    else
        echo "  🆘 重要 (> ${PERFORMANCE_CRITICAL_MS}ms) - 最適化が必要"
    fi
}

# 統計情報の計算
calculate_stats() {
    local times=("$@")
    local count=${#times[@]}
    
    if [[ ${count} -eq 0 ]]; then
        echo "0 0 0 0"
        return
    fi
    
    # 平均値
    local sum=0
    for time in "${times[@]}"; do
        # 数値でない値をスキップ
        if [[ "${time}" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
            sum=$(echo "${sum} + ${time}" | bc -l 2>/dev/null || echo "${sum}")
        fi
    done
    local average
    if [[ ${count} -gt 0 ]]; then
        average=$(echo "scale=2; ${sum} / ${count}" | bc -l 2>/dev/null || echo "0")
    else
        average="0"
    fi
    
    # 最小値・最大値
    local min=${times[0]}
    local max=${times[0]}
    for time in "${times[@]}"; do
        if [[ "${time}" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
            if (( $(echo "${time} < ${min}" | bc -l 2>/dev/null || echo 0) )); then
                min=${time}
            fi
            if (( $(echo "${time} > ${max}" | bc -l 2>/dev/null || echo 0) )); then
                max=${time}
            fi
        fi
    done
    
    # 標準偏差の計算（簡素化）
    local std_dev="0"
    if [[ ${count} -gt 1 ]]; then
        local variance_sum=0
        for time in "${times[@]}"; do
            if [[ "${time}" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
                local diff=$(echo "${time} - ${average}" | bc -l 2>/dev/null || echo "0")
                local squared=$(echo "${diff} * ${diff}" | bc -l 2>/dev/null || echo "0") 
                variance_sum=$(echo "${variance_sum} + ${squared}" | bc -l 2>/dev/null || echo "${variance_sum}")
            fi
        done
        local variance=$(echo "scale=4; ${variance_sum} / ${count}" | bc -l 2>/dev/null || echo "0")
        std_dev=$(echo "scale=2; sqrt(${variance})" | bc -l 2>/dev/null || echo "0")
    fi
    
    echo "${average} ${min} ${max} ${std_dev}"
}

# メイン測定処理
main() {
    init_logging
    
    echo "🚀 Neovim起動時間ベンチマーク開始..."
    echo "   測定回数: ${RUN_TIMES}回"
    echo ""
    
    local startup_times=()
    local failed_runs=0
    
    # 複数回測定
    for ((i=1; i<=RUN_TIMES; i++)); do
        local log_file="${TEMP_DIR}/startup_${i}.log"
        
        if [[ "${QUIET_MODE}" != "true" ]]; then
            echo -n "  測定 ${i}/${RUN_TIMES}... "
        fi
        
        if measure_startup "${log_file}" "${i}"; then
            local startup_time
            startup_time=$(parse_startup_log "${log_file}")
            startup_times+=("${startup_time}")
            
            if [[ "${QUIET_MODE}" != "true" ]]; then
                echo "${startup_time}ms"
            fi
            
            # 詳細分析（1回目のみ）
            if [[ ${i} -eq 1 ]]; then
                analyze_detailed "${log_file}"
            fi
        else
            ((failed_runs++))
            if [[ "${QUIET_MODE}" != "true" ]]; then
                echo "失敗"
            fi
        fi
    done
    
    # 結果が得られない場合の処理
    if [[ ${#startup_times[@]} -eq 0 ]]; then
        echo "❌ 全ての測定が失敗しました。Neovim設定に問題がある可能性があります。" >&2
        return 1
    fi
    
    # 統計情報の計算
    local stats
    stats=$(calculate_stats "${startup_times[@]}")
    read -r average min max std_dev <<< "${stats}"
    
    # 結果出力
    echo ""
    echo "=== 測定結果 ==="
    echo "  📊 統計情報:"
    echo "     平均時間: ${average}ms"
    echo "     最短時間: ${min}ms"
    echo "     最長時間: ${max}ms"  
    echo "     標準偏差: ${std_dev}ms"
    
    if [[ ${failed_runs} -gt 0 ]]; then
        echo "     失敗回数: ${failed_runs}/${RUN_TIMES}"
    fi
    
    # パフォーマンス評価
    evaluate_performance "${average}"
    
    # ベースライン比較
    if [[ "${COMPARE_MODE}" == "true" ]]; then
        compare_with_baseline "${average}"
    fi
    
    # ログファイルに記録
    {
        echo "Average: ${average}ms"
        echo "Min: ${min}ms"  
        echo "Max: ${max}ms"
        echo "StdDev: ${std_dev}ms"
        echo "Failed: ${failed_runs}/${RUN_TIMES}"
    } >> "${BENCHMARK_LOG}"
    
    echo ""
    echo "📝 詳細ログ: ${BENCHMARK_LOG}"
}

# コマンドライン引数の解析
while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--compare)
            COMPARE_MODE=true
            shift
            ;;
        -d|--detail)
            DETAIL_MODE=true
            shift
            ;;
        -t|--times)
            if [[ -n "${2:-}" ]] && [[ "${2}" =~ ^[0-9]+$ ]] && [[ "${2}" -gt 0 ]] && [[ "${2}" -le 50 ]]; then
                RUN_TIMES="$2"
                shift 2
            else
                echo "ERROR: --times requires a number between 1 and 50" >&2
                exit 1
            fi
            ;;
        -q|--quiet)
            QUIET_MODE=true
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

# bcコマンドの存在確認
if ! command -v bc &> /dev/null; then
    echo "ERROR: 'bc' command is required but not installed." >&2
    echo "Please install bc: brew install bc" >&2
    exit 1
fi

# メイン実行
main