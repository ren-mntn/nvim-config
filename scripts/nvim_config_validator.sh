#!/bin/bash

#############################################################################
# Neovim設定ファイル構文検証スクリプト
# 機能概要: Lua設定ファイルの構文エラーと設定問題を検出・分析
# 設定内容: selene静的解析、stylua書式チェック、Neovim設定ロード検証
# 使用方法: ./scripts/nvim_config_validator.sh [--fix] [--strict] [--file <path>]
#############################################################################

set -euo pipefail

# 設定
readonly NVIM_CONFIG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly LOG_DIR="${NVIM_CONFIG_DIR}/logs"
readonly VALIDATION_LOG="${LOG_DIR}/config_validation.log"
readonly STYLUA_CONFIG="${NVIM_CONFIG_DIR}/stylua.toml"
readonly SELENE_CONFIG="${NVIM_CONFIG_DIR}/selene.toml"

# バリデーション結果
TOTAL_FILES=0
PASSED_FILES=0
FAILED_FILES=0
WARNING_FILES=0

# オプション設定
FIX_MODE=false
STRICT_MODE=false
SINGLE_FILE=""
QUIET_MODE=false
VERBOSE_MODE=false

# カラーコード（ANSI エスケープシーケンス）
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
Neovim設定ファイル構文検証ツール

使用方法:
  $0 [オプション] [ファイルパス]

オプション:
  -f, --fix           自動修正モード（styluaフォーマット適用）
  -s, --strict        厳格モード（警告もエラー扱い）
  -q, --quiet         簡潔な出力
  -v, --verbose       詳細出力
  --file <path>       特定ファイルのみ検証
  -h, --help          このヘルプを表示

検証項目:
  ✓ Lua構文エラー
  ✓ Selene静的解析（未定義変数、型エラーなど）
  ✓ Styluaコードスタイル
  ✓ LazyVim設定パターン準拠
  ✓ Neovim設定実際ロード検証

例:
  $0                           # 全設定ファイルを検証
  $0 --fix                     # 自動修正付きで検証
  $0 --file lua/plugins/lsp.lua  # 特定ファイルのみ検証
  $0 --strict                  # 厳格モードで検証
EOF
}

# ログ初期化
init_logging() {
    mkdir -p "${LOG_DIR}"
    
    {
        echo "=== Neovim Configuration Validation ==="
        echo "Date: $(date)"
        echo "Config Dir: ${NVIM_CONFIG_DIR}"
        echo "Validation Mode: $([ "${STRICT_MODE}" = true ] && echo "Strict" || echo "Normal")"
        echo "Auto Fix: $([ "${FIX_MODE}" = true ] && echo "Enabled" || echo "Disabled")"
        echo ""
    } > "${VALIDATION_LOG}"
}

# カラー出力関数
print_status() {
    local status="$1"
    local message="$2"
    
    if [[ "${QUIET_MODE}" == "true" ]]; then
        return
    fi
    
    case "${status}" in
        "success"|"pass")
            echo -e "${GREEN}✅ ${message}${NC}"
            ;;
        "error"|"fail")
            echo -e "${RED}❌ ${message}${NC}"
            ;;
        "warning"|"warn")
            echo -e "${YELLOW}⚠️  ${message}${NC}"
            ;;
        "info")
            echo -e "${BLUE}ℹ️  ${message}${NC}"
            ;;
        "header")
            echo -e "${BOLD}${PURPLE}🔍 ${message}${NC}"
            ;;
    esac
}

# Lua構文チェック
check_lua_syntax() {
    local file_path="$1"
    
    if ! luac -p "${file_path}" 2>/dev/null; then
        local error_output
        error_output=$(luac -p "${file_path}" 2>&1 || true)
        print_status "error" "Lua構文エラー: ${file_path}"
        if [[ "${VERBOSE_MODE}" == "true" ]]; then
            echo -e "${RED}  ${error_output}${NC}"
        fi
        return 1
    fi
    return 0
}

# Selene静的解析
check_with_selene() {
    local file_path="$1"
    
    if ! command -v selene &> /dev/null; then
        print_status "warning" "Seleneが見つかりません。静的解析をスキップします。"
        return 0
    fi
    
    if [[ ! -f "${SELENE_CONFIG}" ]]; then
        print_status "warning" "selene.tomlが見つかりません。デフォルト設定で実行します。"
    fi
    
    local selene_output
    local exit_code=0
    
    selene_output=$(selene "${file_path}" --display-style=rich --color=never 2>&1) || exit_code=$?
    
    if [[ ${exit_code} -ne 0 ]] && [[ -n "${selene_output}" ]]; then
        # エラーと警告を分類
        local error_count
        local warning_count
        
        error_count=$(echo "${selene_output}" | grep "error\[" | wc -l 2>/dev/null || echo "0")
        warning_count=$(echo "${selene_output}" | grep "warning\[" | wc -l 2>/dev/null || echo "0")
        
        # 空白文字を除去
        error_count=$(echo "${error_count}" | tr -d ' \t\n\r')
        warning_count=$(echo "${warning_count}" | tr -d ' \t\n\r')
        
        if [[ "${error_count}" -gt "0" ]]; then
            print_status "error" "Seleneエラー ${error_count}件: ${file_path}"
            if [[ "${VERBOSE_MODE}" == "true" ]]; then
                echo "${selene_output}" | grep "error\[" | head -5
            fi
            return 1
        elif [[ "${warning_count}" -gt "0" ]]; then
            print_status "warning" "Selene警告 ${warning_count}件: ${file_path}"
            if [[ "${VERBOSE_MODE}" == "true" ]]; then
                echo "${selene_output}" | grep "warning\[" | head -3
            fi
            if [[ "${STRICT_MODE}" == "true" ]]; then
                return 1
            fi
            return 2  # 警告のみ
        fi
    fi
    
    return 0
}

# Styluaフォーマットチェック
check_with_stylua() {
    local file_path="$1"
    
    if ! command -v stylua &> /dev/null; then
        print_status "warning" "Styluaが見つかりません。フォーマットチェックをスキップします。"
        return 0
    fi
    
    local stylua_config_arg=""
    if [[ -f "${STYLUA_CONFIG}" ]]; then
        stylua_config_arg="--config-path=${STYLUA_CONFIG}"
    fi
    
    # フォーマットが必要かチェック
    if ! stylua --check ${stylua_config_arg} "${file_path}" 2>/dev/null; then
        print_status "warning" "フォーマットが必要: ${file_path}"
        
        # 自動修正モードの場合
        if [[ "${FIX_MODE}" == "true" ]]; then
            if stylua ${stylua_config_arg} "${file_path}" 2>/dev/null; then
                print_status "success" "フォーマット適用完了: ${file_path}"
            else
                print_status "error" "フォーマット適用失敗: ${file_path}"
                return 1
            fi
        else
            if [[ "${STRICT_MODE}" == "true" ]]; then
                return 1
            fi
            return 2  # 警告のみ
        fi
    fi
    
    return 0
}

# LazyVim設定パターンチェック
check_lazyvim_patterns() {
    local file_path="$1"
    local issues=0
    
    # プラグインディレクトリ内のファイルのみチェック
    if [[ ! "${file_path}" =~ lua/plugins/ ]]; then
        return 0
    fi
    
    local file_content
    file_content=$(cat "${file_path}")
    
    # 必須パターンのチェック
    if echo "${file_content}" | grep -q "opts\s*=\s*{" && ! echo "${file_content}" | grep -q "opts\s*=\s*function"; then
        print_status "warning" "LazyVim継承パターン未使用（opts = function推奨）: ${file_path}"
        ((issues++))
    fi
    
    # vim.tbl_deep_extendの使用チェック
    if echo "${file_content}" | grep -q "opts\s*=\s*function" && ! echo "${file_content}" | grep -q "vim\.tbl_deep_extend"; then
        print_status "warning" "設定マージパターン未使用（vim.tbl_deep_extend推奨）: ${file_path}"
        ((issues++))
    fi
    
    # return optsの確認
    if echo "${file_content}" | grep -q "opts\s*=\s*function" && ! echo "${file_content}" | grep -q "return opts"; then
        print_status "warning" "opts返却パターン未使用（return opts必須）: ${file_path}"
        ((issues++))
    fi
    
    if [[ "${issues}" -gt "0" ]]; then
        if [[ "${STRICT_MODE}" == "true" ]]; then
            return 1
        fi
        return 2  # 警告のみ
    fi
    
    return 0
}

# Neovim設定実際ロード検証
check_nvim_load() {
    local file_path="$1"
    
    # 相対パスに変換
    local relative_path
    relative_path=$(echo "${file_path}" | sed "s|${NVIM_CONFIG_DIR}/||")
    
    # Luaモジュール形式に変換
    local module_path
    module_path=$(echo "${relative_path}" | sed 's|/|.|g' | sed 's|\.lua$||')
    
    # skip init.lua as it's the entry point
    if [[ "${module_path}" == "init" ]]; then
        return 0
    fi
    
    # Neovimでの実際のロードテスト
    local load_test
    load_test=$(nvim --headless -c "lua local ok, err = pcall(require, '${module_path}'); if not ok then print('ERROR: ' .. tostring(err)) else print('OK') end" +qall 2>&1)
    
    if echo "${load_test}" | grep -q "ERROR:"; then
        print_status "error" "Neovimロードエラー: ${file_path}"
        if [[ "${VERBOSE_MODE}" == "true" ]]; then
            echo -e "${RED}  ${load_test}${NC}"
        fi
        return 1
    fi
    
    return 0
}

# 単一ファイルの検証
validate_single_file() {
    local file_path="$1"
    local file_passed=true
    local has_warnings=false
    
    ((TOTAL_FILES++))
    
    if [[ "${QUIET_MODE}" != "true" ]]; then
        echo -n "  $(basename "${file_path}")... "
    fi
    
    # 1. Lua構文チェック
    if ! check_lua_syntax "${file_path}"; then
        file_passed=false
    fi
    
    # 2. Selene静的解析
    local selene_result=0
    check_with_selene "${file_path}" || selene_result=$?
    if [[ ${selene_result} -eq 1 ]]; then
        file_passed=false
    elif [[ ${selene_result} -eq 2 ]]; then
        has_warnings=true
    fi
    
    # 3. Styluaフォーマットチェック
    local stylua_result=0
    check_with_stylua "${file_path}" || stylua_result=$?
    if [[ ${stylua_result} -eq 1 ]]; then
        file_passed=false
    elif [[ ${stylua_result} -eq 2 ]]; then
        has_warnings=true
    fi
    
    # 4. LazyVim設定パターンチェック
    local pattern_result=0
    check_lazyvim_patterns "${file_path}" || pattern_result=$?
    if [[ ${pattern_result} -eq 1 ]]; then
        file_passed=false
    elif [[ ${pattern_result} -eq 2 ]]; then
        has_warnings=true
    fi
    
    # 5. Neovim設定実際ロード検証
    if [[ "${file_passed}" == "true" ]]; then
        if ! check_nvim_load "${file_path}"; then
            file_passed=false
        fi
    fi
    
    # 結果集計
    if [[ "${file_passed}" == "true" ]]; then
        ((PASSED_FILES++))
        if [[ "${has_warnings}" == "true" ]]; then
            ((WARNING_FILES++))
            if [[ "${QUIET_MODE}" != "true" ]]; then
                echo -e "${YELLOW}PASS (警告あり)${NC}"
            fi
        else
            if [[ "${QUIET_MODE}" != "true" ]]; then
                echo -e "${GREEN}PASS${NC}"
            fi
        fi
    else
        ((FAILED_FILES++))
        if [[ "${QUIET_MODE}" != "true" ]]; then
            echo -e "${RED}FAIL${NC}"
        fi
    fi
    
    # ログに記録
    {
        echo "File: ${file_path}"
        echo "Status: $([ "${file_passed}" = true ] && echo "PASS" || echo "FAIL")"
        echo "Warnings: $([ "${has_warnings}" = true ] && echo "YES" || echo "NO")"
        echo ""
    } >> "${VALIDATION_LOG}"
}

# Luaファイル検索
find_lua_files() {
    if [[ -n "${SINGLE_FILE}" ]]; then
        if [[ -f "${SINGLE_FILE}" ]]; then
            echo "${SINGLE_FILE}"
        else
            echo "ERROR: File not found: ${SINGLE_FILE}" >&2
            exit 1
        fi
    else
        find "${NVIM_CONFIG_DIR}" -name "*.lua" -type f | sort
    fi
}

# メイン検証処理
main() {
    init_logging
    
    print_status "header" "Neovim設定ファイル構文検証開始"
    
    # ツールの存在確認
    local missing_tools=()
    if ! command -v luac &> /dev/null; then
        missing_tools+=("luac")
    fi
    if ! command -v selene &> /dev/null; then
        missing_tools+=("selene")
    fi
    if ! command -v stylua &> /dev/null; then
        missing_tools+=("stylua")
    fi
    
    if [[ "${#missing_tools[@]}" -gt "0" ]]; then
        print_status "warning" "一部のツールが見つかりません: ${missing_tools[*]}"
        print_status "info" "インストール: brew install ${missing_tools[*]// / }"
        echo ""
    fi
    
    # ファイル検証
    local lua_files=()
    local temp_file="/tmp/lua_files_$$"
    find_lua_files > "${temp_file}"
    while IFS= read -r file; do
        lua_files+=("$file")
    done < "${temp_file}"
    rm -f "${temp_file}"
    
    if [[ "${#lua_files[@]}" -eq "0" ]]; then
        print_status "error" "Luaファイルが見つかりませんでした。"
        exit 1
    fi
    
    print_status "info" "検証対象: ${#lua_files[@]}ファイル"
    echo ""
    
    for file_path in "${lua_files[@]}"; do
        validate_single_file "${file_path}"
    done
    
    # 結果サマリー
    echo ""
    print_status "header" "検証結果サマリー"
    echo "  📊 総ファイル数: ${TOTAL_FILES}"
    echo "  ✅ 成功: ${PASSED_FILES}"
    if [[ "${WARNING_FILES}" -gt "0" ]]; then
        echo "  ⚠️  警告あり: ${WARNING_FILES}"
    fi
    if [[ "${FAILED_FILES}" -gt "0" ]]; then
        echo "  ❌ 失敗: ${FAILED_FILES}"
    fi
    
    # 終了コード決定
    local exit_code=0
    if [[ "${FAILED_FILES}" -gt "0" ]]; then
        exit_code=1
        print_status "error" "検証に失敗しました。上記のエラーを修正してください。"
    elif [[ ${WARNING_FILES} -gt 0 ]] && [[ "${STRICT_MODE}" == "true" ]]; then
        exit_code=1
        print_status "error" "厳格モードで警告が検出されました。"
    else
        print_status "success" "全ての検証が完了しました。"
    fi
    
    echo ""
    echo "📝 詳細ログ: ${VALIDATION_LOG}"
    
    return ${exit_code}
}

# クリーンアップ
cleanup() {
    # 必要に応じてクリーンアップ処理
    :
}
trap cleanup EXIT

# コマンドライン引数の解析
while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--fix)
            FIX_MODE=true
            shift
            ;;
        -s|--strict)
            STRICT_MODE=true
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
        --file)
            if [[ -n "${2:-}" ]]; then
                SINGLE_FILE="$2"
                shift 2
            else
                echo "ERROR: --file requires a file path" >&2
                exit 1
            fi
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        --)
            shift
            break
            ;;
        -*)
            echo "ERROR: Unknown option: $1" >&2
            echo "Use --help for usage information." >&2
            exit 1
            ;;
        *)
            # 位置引数として解釈（ファイルパス）
            SINGLE_FILE="$1"
            shift
            ;;
    esac
done

# 依存関係チェック
if ! command -v luac &> /dev/null; then
    echo "ERROR: 'luac' command is required but not installed." >&2
    echo "Please install Lua: brew install lua" >&2
    exit 1
fi

# メイン実行
main "$@"