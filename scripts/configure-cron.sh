#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

compare_time() {
    log_info "当前时间: $(date '+%Y-%m-%d %T') <-> 上海时间: $(TZ='Asia/Shanghai' date '+%Y-%m-%d %T')"
}

CRON_SCHEDULE="${CRON_SCHEDULE:-1 1 * * *}"
compare_time
log_info "设置的 crontab 时间为：$CRON_SCHEDULE"

if ! command -v supercronic > /dev/null; then
    log_warning "Cannot find supercronic daemon. supercronic will not run."
fi

touch /var/log/s-tip.log

# ── 核心新增：在此处解析可能存在的 _FILE 变量 ─────────────────────────────
file_env "HOSTS_JSON"
file_env "SCRIPT"
file_env "TELEGRAM_TOKEN"
file_env "MAILPASSWORD"

# 写入 crontab 文件
# 由于 file_env 已经将 Secret 文件的内容导出到了对应的原变量中
# ── 将环境变量安全地导出到专用文件 ──────────────────────────────────────
# 使用 printf %q 可以完美转义任何特殊字符（包含单引号、双引号、空格、$等）
{
    printf "export TZ=%q\n" "${TZ:-Asia/Shanghai}"
    printf "export CRON_SCHEDULE=%q\n" "${CRON_SCHEDULE}"
    printf "export HOSTS_JSON=%q\n" "${HOSTS_JSON:-}"
    printf "export SCRIPT=%q\n" "${SCRIPT:-}"
    printf "export ENABLE_TG=%q\n" "${ENABLE_TG:-true}"
    printf "export ENABLE_EMAIL=%q\n" "${ENABLE_EMAIL:-true}"
    printf "export TELEGRAM_TOKEN=%q\n" "${TELEGRAM_TOKEN:-}"
    printf "export TELEGRAM_USERID=%q\n" "${TELEGRAM_USERID:-}"
    printf "export AUTHTYPE=%q\n" "${AUTHTYPE:-password}"
    printf "export MAILADDR=%q\n" "${MAILADDR:-}"
    printf "export MAILPORT=%q\n" "${MAILPORT:-587}"
    printf "export MAILUSERNAME=%q\n" "${MAILUSERNAME:-}"
    printf "export MAILFROM=%q\n" "${MAILFROM:-}"
    printf "export MAILPASSWORD=%q\n" "${MAILPASSWORD:-}"
    printf "export MAILSENDTO=%q\n" "${MAILSENDTO:-}"
    printf "export HTTP_PROXY=%q\n" "${HTTP_PROXY:-}"
    printf "export HTTPS_PROXY=%q\n" "${HTTPS_PROXY:-}"
    printf "export ALL_PROXY=%q\n" "${ALL_PROXY:-}"
    printf "export http_proxy=%q\n" "${http_proxy:-}"
    printf "export https_proxy=%q\n" "${https_proxy:-}"
    printf "export all_proxy=%q\n" "${all_proxy:-}"
} > /etc/s-tip.env

# ── 写入最纯净的 crontab 文件 ──────────────────────────────────────────
# 任务执行时，先 source 环境变量文件，再执行主脚本
echo "$CRON_SCHEDULE . /etc/s-tip.env && /usr/local/bin/s-tip.sh" > /etc/cron.d/s-tip-task

chmod 0644 /etc/cron.d/s-tip-task
chmod 600 /etc/s-tip.env
log_info "crontab 文件已写入 /etc/cron.d/s-tip-task"

log_info "Starting supercronic with /etc/cron.d/s-tip-task"

if command -v inotifywait >/dev/null; then
    (
        while true; do
            inotifywait -e modify /etc/cron.d/s-tip-task
            pkill -f -o "supercronic /etc/cron.d/s-tip-task" || true
            supercronic /etc/cron.d/s-tip-task | tee -a /var/log/s-tip.log 2>&1 &
        done
    ) &
else
    log_warning "inotifywait not found，跳过 crontab 热更新"
fi

exec supercronic /etc/cron.d/s-tip-task 2>&1 | tee -a /var/log/s-tip.log