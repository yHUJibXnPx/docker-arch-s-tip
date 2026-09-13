#!/usr/bin/env sh
# =============================================================================
# check_disk.sh — 磁盘使用率超阈值告警
# =============================================================================
# 用法：在 HOSTS_JSON 的主机条目中设置：
#   "script_file": "/scripts/check_disk.sh"
#
# 推送控制：
#   有分区超阈  → echo 输出超阈分区信息  → s-tip 推送
#   全部正常    → 无任何输出              → s-tip 静默跳过
# =============================================================================

THRESHOLD=80  # 使用率超过此百分比则告警

ALERTS=""

# df -h 输出示例：
# /dev/sda1        50G   42G  5.3G  89% /
df -h | tail -n +2 | while IFS= read -r line; do
  # 提取使用率数字（去掉 %）
  usage=$(echo "$line" | awk '{print $5}' | tr -d '%')
  mount=$(echo "$line" | awk '{print $6}')

  # 跳过无法解析的行（tmpfs 等可能格式不同）
  echo "$usage" | grep -qE '^[0-9]+$' || continue

  if [ "$usage" -ge "$THRESHOLD" ]; then
    echo "[disk] 磁盘告警: ${mount}  使用率 ${usage}%  (阈值 ${THRESHOLD}%)"
    echo "  $(echo "$line" | awk '{print "总量:"$2, "已用:"$3, "可用:"$4}')"
  fi
done