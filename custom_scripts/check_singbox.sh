#!/usr/bin/env sh
# =============================================================================
# check_singbox.sh — sing-box 版本更新检测
# =============================================================================
# 用法：在 HOSTS_JSON 的主机条目中设置：
#   "script_file": "/scripts/check_singbox.sh"
#
# 推送控制：
#   有新版本  → echo 输出版本信息  → s-tip 推送
#   无新版本  → 无任何输出         → s-tip 静默跳过
#
# 状态持久化：上次版本号保存在远端服务器 /tmp/.singbox_ver
# =============================================================================

STATE_FILE="/tmp/.singbox_ver"
RELEASES_URL="https://github.com/SagerNet/sing-box/releases"

# 抓取最新 release tag（取第一条即最新版）
LATEST=$(curl -sSfL "$RELEASES_URL" \
  | grep -oE '/SagerNet/sing-box/releases/tag/v[^"]+' \
  | head -1)

if [ -z "$LATEST" ]; then
  # 网络或解析失败，输出错误让 s-tip 推送告警
  echo "[check_singbox] 获取最新版本失败，请检查网络或 GitHub 页面结构"
  exit 0
fi

LAST=$(cat "$STATE_FILE" 2>/dev/null || true)

if [ "$LATEST" = "$LAST" ]; then
  # 版本未变，无输出 → s-tip 不推送
  exit 0
fi

# 版本有变化，输出信息 → s-tip 推送
if [ -z "$LAST" ]; then
  echo "[sing-box] 首次记录版本: ${LATEST}"
else
  echo "[sing-box] 检测到新版本!"
  echo "  旧版本: ${LAST}"
  echo "  新版本: ${LATEST}"
  echo "  发布页: https://github.com${LATEST}"
fi

# 更新状态文件
echo "$LATEST" > "$STATE_FILE"