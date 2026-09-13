#!/usr/bin/env bash
set -euo pipefail

# 获取当前日期
CURRENT_DATE=$(date +"%Y-%m-%d")

# 定义彩色日志输出函数
DEBUG='\033[0;37m'   # 灰色
INFO='\033[0;34m'    # 蓝色
SUCCESS='\033[0;32m' # 绿色
WARNING='\033[0;33m' # 黄色
ERROR='\033[0;31m'   # 红色
CRITICAL='\033[1;41m' # 红底白字
NC='\033[0m'         # 无色，重置颜色

# 日志函数
log_debug() { echo -e "${DEBUG}[DEBUG] $(date) - $1${NC}"; }
log_info() { echo -e "${INFO}[INFO] $(date) - $1${NC}"; }
log_success() { echo -e "${SUCCESS}[SUCCESS] $(date) - $1${NC}"; }
log_warning() { echo -e "${WARNING}[WARNING] $(date) - $1${NC}"; }
log_error() { echo -e "${ERROR}[ERROR] $(date) - $1${NC}"; }
log_critical() { echo -e "${CRITICAL}[CRITICAL] $(date) - $1${NC}"; }

# 检查命令是否存在
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# ── 核心新增：Secret 文件解析函数 ────────────────────────────────────────────
# 用法: file_env "变量名" "默认值(可选)"
# 自动检测 VAR_FILE，如果存在则读取文件内容覆盖到 VAR
file_env() {
    local var="$1"
    local fileVar="${var}_FILE"
    local def="${2:-}"

    # 防止冲突：同时设置了明文和文件
    if [[ -n "${!var:-}" ]] && [[ -n "${!fileVar:-}" ]]; then
        log_error "同时设置了 $var 和 $fileVar，这两个变量互斥，请只保留一个"
        exit 1
    fi

    local val="$def"
    if [[ -n "${!var:-}" ]]; then
        val="${!var}"
    elif [[ -n "${!fileVar:-}" ]]; then
        if [[ -f "${!fileVar}" ]]; then
            val="$(tr -d '\r' < "${!fileVar}")"
        else
            log_error "Secret 文件不存在: ${!fileVar}"
            exit 1
        fi
    fi

    export "$var"="$val"
}