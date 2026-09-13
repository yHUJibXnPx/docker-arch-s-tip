#!/usr/bin/env bash
# =============================================================================
# s-tip.sh — SSH 巡检 + 多渠道推送
# =============================================================================
# 设计原则：s-tip 只负责"连接、执行、收集、推送"，不做任何业务判断。
# "要不要推送"完全由用户的脚本控制：
#   - 脚本有输出  → 追加到 result.txt → 推送
#   - 脚本无输出  → 跳过，不推送
#
# 必填环境变量：
#   HOSTS_JSON   主机列表（JSON）
#
# 可选环境变量：
#   SCRIPT       全局脚本片段，对所有主机生效，拼接在最前执行
#   ENABLE_TG    true/false，是否启用 Telegram 推送（默认 true）
#   ENABLE_EMAIL true/false，是否启用邮件推送（默认 true）
#
# HOSTS_JSON 格式（每台主机的脚本字段全部并存、按序拼接执行）：
# {
#   "info": [
#     {
#       "host":        "server1.com",
#       "username":    "root",
#       "port":        22,
#       "password":    "xxx",
#       "script":      "echo hello",          # 可选，内联脚本，拼接在全局 SCRIPT 之后
#       "script_file": "/scripts/a.sh"        # 可选，字符串或数组，拼接在 script 之后
#     }
#   ]
# }
# 最终脚本 = 全局SCRIPT + script字段 + script_file(s)，不填的自动跳过
# =============================================================================
set -euo pipefail
source "$(dirname "$0")/common.sh"

compare_time() {
    log_info "当前时间: $(date '+%Y-%m-%d %T') <-> 上海时间: $(TZ='Asia/Shanghai' date '+%Y-%m-%d %T')"
}

log_info '开始执行 server 登陆进程'
compare_time

TEMPDIR=$(mktemp -d)
trap 'rm -rf "${TEMPDIR}"' EXIT
pushd "${TEMPDIR}" > /dev/null

# ── 必填：HOSTS_JSON ──────────────────────────────────────────────────────────
# set -u 下直接用 $VAR 会在变量未设置时立即 crash（-z 判断根本执行不到）
# 统一用 ${VAR:-} 展开，让 -z 正确捕获"未设置 or 空值"两种情况
if [[ -z "${HOSTS_JSON:-}" ]]; then
    log_error "请设置 'HOSTS_JSON'，否则无法知道要登录哪些服务器"
    exit 1
fi
log_info "HOSTS_JSON ok"

# ── 可选：独立推送开关 ────────────────────────────────────────────────────────
# 明确设为 false 才禁用；其他任何值（含 true 或未设置）均视为启用
ENABLE_TG="${ENABLE_TG:-true}"
ENABLE_EMAIL="${ENABLE_EMAIL:-true}"

# ── 可选：全局脚本片段（所有主机都会拼接在最前） ─────────────────────────────
GLOBAL_SCRIPT="${SCRIPT:-}"
if [[ -z "$GLOBAL_SCRIPT" ]]; then
    log_info "'SCRIPT' 未设置，全局脚本片段为空"
else
    log_info "'SCRIPT' ok"
fi

# ── Telegram 推送函数 ─────────────────────────────────────────────────────────
tgsend() {
    local text="$1"
    # Telegram 4096 字符上限，超出截断并提示
    if [[ ${#text} -gt 4000 ]]; then
        text="${text:0:4000}"$'\n''...(内容过长，已截断，请查看邮件附件)'
    fi
    local token="${TELEGRAM_TOKEN:-}"
    local uid="${TELEGRAM_USERID:-}"
    if [[ -z "$token" || -z "$uid" ]]; then
        log_warning "TG Token 或 UserID 未配置，跳过 TG 推送"
        return 0
    fi
    local res
    res=$(timeout 20s curl -sf -X POST \
        "https://api.telegram.org/bot${token}/sendMessage" \
        -d chat_id="$uid" \
        -d parse_mode="HTML" \
        -d text="$text") || true
    if echo "$res" | jq -e '.ok == true' > /dev/null 2>&1; then
        log_info "TG 推送成功"
    else
        log_warning "TG 推送失败，请检查 Token/UserID；返回：$res"
    fi
}

# ── 邮件推送函数 ──────────────────────────────────────────────────────────────
mailsend() {
    local result_file="$1"
    # 逐一检查必填邮件配置，收集缺失项（用 ${!v:-} 避免 set -u crash）
    local required_vars=(MAILADDR MAILPORT MAILUSERNAME MAILPASSWORD MAILFROM MAILSENDTO)
    local missing=()
    for v in "${required_vars[@]}"; do
        [[ -z "${!v:-}" ]] && missing+=("$v")
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_warning "邮件配置不完整，缺少：${missing[*]}，跳过邮件推送"
        return 0
    fi

    python3 - "$result_file" <<'PY469138946ba5fa'
import smtplib, os, ssl, re, sys
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email.mime.base import MIMEBase
from email import encoders

def is_email(address):
    return bool(re.match(r"^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+$", address))

def authenticate_and_send(smtp, auth_type, username, password, message, mail_from, receiver):
    if auth_type == "oauth2":
        auth_string = f"user={username}\x01auth=Bearer {password}\x01\x01"
        smtp.docmd('AUTH XOAUTH2', auth_string)
    else:
        smtp.login(username, password)
    smtp.sendmail(mail_from, receiver, message.as_string())

def send_email(server, port, username, mail_from, auth_type, password, receiver, filenames):
    msg = MIMEMultipart()
    msg['From']    = mail_from
    msg['To']      = receiver
    msg['Subject'] = "s-tip 巡检报告"
    msg.attach(MIMEText("详见附件 result.txt", 'plain', 'utf-8'))

    for fname in filenames:
        if not os.path.isfile(fname):
            print(f"! 附件未找到: {fname}，跳过")
            continue
        with open(fname, 'rb') as f:
            part = MIMEBase('application', 'octet-stream')
            part.set_payload(f.read())
        encoders.encode_base64(part)
        part.add_header('Content-Disposition', f'attachment; filename="{os.path.basename(fname)}"')
        msg.attach(part)

    TIMEOUT = 30  # SMTP 连接 / 操作超时秒数，防止无限挂起
    use_ssl = (port == 465)
    try:
        if use_ssl:
            ctx = ssl.create_default_context()
            with smtplib.SMTP_SSL(server, port, context=ctx, timeout=TIMEOUT) as s:
                authenticate_and_send(s, auth_type, username, password, msg, mail_from, receiver)
        else:
            with smtplib.SMTP(server, port, timeout=TIMEOUT) as s:
                if port != 25:
                    s.starttls()
                authenticate_and_send(s, auth_type, username, password, msg, mail_from, receiver)
        print("√ 邮件发送成功")
    except Exception as e:
        print(f"✗ 邮件发送失败：{e}", file=sys.stderr)
        sys.exit(1)  # 非零退出让 bash 的 mailsend() 捕获到失败

if __name__ == "__main__":
    result_file = sys.argv[1] if len(sys.argv) > 1 else "result.txt"
    auth_type = os.getenv('AUTHTYPE', 'password')
    server    = os.getenv('MAILADDR', '')
    port      = int(os.getenv('MAILPORT', 587))
    username  = os.getenv('MAILUSERNAME', '')
    mail_from = os.getenv('MAILFROM', '')
    password  = os.getenv('MAILPASSWORD', '')
    receiver  = os.getenv('MAILSENDTO', '')

    if not mail_from:
        print("✗ MAILFROM 未配置，无法发送邮件", file=sys.stderr)
        sys.exit(1)
    if not is_email(receiver):
        print(f"✗ MAILSENDTO 格式不合法: {receiver}", file=sys.stderr)
        sys.exit(1)

    print(f"server={server} port={port} username={username} from={mail_from} to={receiver}")
    send_email(server, port, username, mail_from, auth_type, password, receiver, [result_file])
PY469138946ba5fa
}

# ── 主循环 ────────────────────────────────────────────────────────────────────
log_info "开始运行主任务..."

# jq | while 是子 shell，内部赋值对外层不可见
# 用文件标志传递"是否有内容需要推送"
HAS_OUTPUT_FLAG="${TEMPDIR}/.has_output"

while IFS= read -r info; do
    host=$(jq -cr '.host'     <<<"$info")
    user=$(jq -cr '.username' <<<"$info")
    port=$(jq -cr '.port'     <<<"$info")
    pass=$(jq -cr '.password' <<<"$info")

    # ── 拼接最终脚本：全局SCRIPT + 主机script字段 + 主机script_file(s) ────────
    # 三者全部并存，按序拼接，不填的自动跳过，无优先级之分
    run_script=""
    sources=()   # 记录脚本来源，用于日志

    # 统一开始追踪，但如果想要实现没有内容不推送就不能加入内容。
    #run_script+="echo '=== s-tip 开始 ($(date +%H:%M:%S)) ==='; "

    # 1. 全局 SCRIPT 环境变量（所有主机都执行，拼接在最前）
    if [[ -n "$GLOBAL_SCRIPT" ]]; then
        #           ↑ 单引号，$ 不展开，传到远端 sh 后才执行
        run_script+='echo "=== s-tip 开始执行 ($(date)) ==="; '
        run_script+="${GLOBAL_SCRIPT}"$'\n'
        sources+=("SCRIPT")
    fi

    # 2. 主机 script 字段（JSON 内联单行，拼在 SCRIPT 之后）
    host_script=$(jq -cr '.script // empty' <<<"$info")
    if [[ -n "$host_script" ]]; then
        run_script+="${host_script}"$'\n'
        sources+=("script")
    fi

    # 3. 主机 script_file 字段（字符串或数组，拼在最后）
    script_file_type=$(jq -cr 'if has("script_file") then .script_file | type else "null" end' <<<"$info")
    script_file_error=false

    case "$script_file_type" in
      string)
        sf=$(jq -cr '.script_file' <<<"$info")
        if [[ ! -f "$sf" ]]; then
            log_error "[${host}] script_file 不存在: ${sf}"
            script_file_error=true
        else
            # 如果想要实现没有内容不推送就不能加入内容。
            #run_script+="echo '[$(basename "$sf")] 开始执行'; "
            run_script+="$(cat "$sf")"
            run_script+="; echo '[$(basename "$sf")] 执行完毕'"$'\n'
            sources+=("script_file=\"${sf}\"")
        fi
        ;;
      array)
        missing_files=()
        while IFS= read -r sf; do
            if [[ ! -f "$sf" ]]; then
                missing_files+=("$sf")
            else
                # 如果想要实现没有内容不推送就不能加入内容。
                #run_script+="echo '[$(basename "$sf")] 开始执行'; "
                run_script+="$(cat "$sf")"
                run_script+="; echo '[$(basename "$sf")] 执行完毕'"$'\n'
                sources+=("script_file=\"${sf}\"")
            fi
        done < <(jq -cr '.script_file[]' <<<"$info")
        if [[ ${#missing_files[@]} -gt 0 ]]; then
            log_error "[${host}] script_file 以下文件不存在: ${missing_files[*]}"
            script_file_error=true
        fi
        ;;
      null) ;;  # 字段不存在，正常跳过
      *)
        log_error "[${host}] script_file 字段类型不合法（应为 string 或 array），实际: ${script_file_type}"
        script_file_error=true
        ;;
    esac

    if $script_file_error; then
        printf '配置错误！\n主机: %s\n用户: %s\n错误: script_file 存在不合法路径或类型，请检查挂载和配置\n---\n' \
            "$host" "$user" >> result.txt
        touch "${HAS_OUTPUT_FLAG}"
        continue
    fi

    # 三个字段都没配置时使用内置默认（系统信息巡检）
    if [[ -z "${run_script// /}" ]]; then
        run_script="echo '=== system ===' ; uname -a ; echo '=== disk ===' ; df -h ; echo '=== time ===' ; date ; echo '=== ps ===' ; ps"
        sources+=("内置默认")
    fi
    # 如果想要实现没有内容不推送就不能加入内容。
    #run_script+=$'echo "--- 执行确认 ---\\n主机: $(hostname)\\n检查时间: $(date)\\n状态文件: $(test -f /tmp/.singbox_ver && echo "已记录最新版" || echo "首次")\\n磁盘: $(df -h / | tail -1)"\n'
    log_info "处理主机: ${user}@${host}:${port}  脚本来源: [$(IFS=', '; echo "${sources[*]}")]"
    log_info "[${host}] 脚本拼接完成，长度: ${#run_script} 字符"
    # ── SSH 执行 ──────────────────────────────────────────────────────────────
    # 脚本通过 SSH stdin 发往远端，远端只需有 sh
    # 注意：
    #   不用 -t/-tt：伪终端会把 stdin 内容 echo 到输出，污染结果
    #   不用 -v：verbose 产生大量噪音
    #   2>&1：把 SSH 错误信息也纳入 raw_output，登录失败时能看到原因
    #   去掉 grep -vF：原本用于过滤 echo，现在不需要了
    ssh_ok=true
    raw_output=""

    # 1. 提前检查网络连通性。成功的输出直接丢弃，仅在失败时捕获错误日志
    ping_out=$(ping -c4 "$host" 2>&1) || { ssh_ok=false; raw_output="Ping 失败:\n$ping_out"; }
    
    if $ssh_ok; then
        nc_out=$(nc -zv "$host" "$port" 2>&1) || { ssh_ok=false; raw_output="端口不通:\n$nc_out"; }
    fi

    # 2. 如果网络通畅，再执行 SSH，获取纯净的脚本输出
    if $ssh_ok; then
        raw_output=$(
            sshpass -p "$pass" ssh -q \
              -o LogLevel=ERROR \
              -o HostKeyAlgorithms=+ssh-rsa \
              -o KexAlgorithms=+diffie-hellman-group1-sha1 \
              -o PubkeyAcceptedAlgorithms=+ssh-rsa \
              -o ServerAliveCountMax=10 \
              -o ServerAliveInterval=30 \
              -o StrictHostKeyChecking=no \
              -o UserKnownHostsFile=/dev/null \
              -p "$port" \
              "${user}@${host}" sh 2>&1 <<<"${run_script}"
        ) || ssh_ok=false
    fi

    if $ssh_ok; then
        log_info "登录成功: ${host}"
        
        # 优化判空逻辑：剔除可能存在的所有空白字符（空格、换行 \n、回车 \r、制表符 \t）
        clean_output=$(echo -n "$raw_output" | tr -d '[:space:]')
        
        # 如果剥离所有空白符后，内容为空，则判定为“无输出”，跳过推送
        if [[ -z "$clean_output" ]]; then
            log_info "[${host}] 脚本输出为空，跳过推送"
            continue
        fi
        
        entry="登录成功请检查! $(printf '\n主机: %s\n用户: %s\n日志:\n%s' "$host" "$user" "$raw_output")"
    else
        log_warning "登录失败: ${host}"
        # 登录失败本身就是需要通知的事，无论 raw_output 是否为空都推
        entry="登录失败请检查! $(printf '\n主机: %s\n用户: %s\n日志:\n%s' "$host" "$user" "$raw_output")"
    fi

    printf '%s\n---\n' "${entry}" >> result.txt
    touch "${HAS_OUTPUT_FLAG}"

done < <(jq -cr '.info[]' <<<"${HOSTS_JSON}")

# ── 推送 ──────────────────────────────────────────────────────────────────────
if [[ ! -f "${HAS_OUTPUT_FLAG}" ]]; then
    log_info "本次所有主机均无输出，不推送任何通知"
else
    echo '════════════ 登陆结果 ════════════'
    cat result.txt

    if [[ "$ENABLE_TG" == "false" ]]; then
        log_info "ENABLE_TG=false，跳过 TG 推送"
    else
        tgsend "$(cat result.txt)"
    fi

    if [[ "$ENABLE_EMAIL" == "false" ]]; then
        log_info "ENABLE_EMAIL=false，跳过邮件推送"
    else
        mailsend "result.txt"
    fi
fi

# ── 收尾 ──────────────────────────────────────────────────────────────────────
popd > /dev/null
# trap EXIT 已负责清理 TEMPDIR

if [[ -f /var/log/s-tip.log ]]; then
    tail -n 200 /var/log/s-tip.log > /var/log/s-tip.log.tmp
    mv /var/log/s-tip.log.tmp /var/log/s-tip.log
    echo "$(date '+%Y-%m-%d %T') 日志已清理，保留最近 200 行" >> /var/log/s-tip.log
fi

log_info '执行结束'
compare_time
