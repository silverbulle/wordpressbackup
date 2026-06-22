#!/bin/bash
set -euo pipefail

# 允许传入第一个参数作为自定义状态（供备份脚本调用）。如果不传，则默认为日常巡检。
TASK_STATUS=${1:-"🛡️ 日常设备健康巡检"}

echo "正在生成系统状态报告..."
REPORT_FILE="/tmp/wp-health-report.txt"

{
    echo "==================================="
    echo " 📊 服务器健康与状态巡检报告"
    echo "==================================="
    echo "时间: $(date +'%Y-%m-%d %H:%M:%S')"
    echo "状态: $TASK_STATUS"
    echo ""
    echo "---------- 💾 存储使用情况 ----------"
    df -h /
    echo ""
    echo "---------- ⚡ 性能使用情况 ----------"
    uptime
    echo ""
    free -m
    echo ""
    echo "---------- 🛡️ 安全：过去 24 小时非法 SSH 登录尝试 (Top 10 IP) ----------"
    # 统计 SSH 爆破失败的 IP 列表
    journalctl -u ssh --since "1 day ago" 2>/dev/null | grep "Failed password" | awk '{for(i=1;i<=NF;i++) if($i=="from") print $(i+1)}' | sort | uniq -c | sort -nr | head -10 || echo "无记录"
    echo "==================================="
} > "$REPORT_FILE"

# 如果配置了邮件脚本，则发送邮件
REPORT_SCRIPT="$(dirname "$0")/wp-report.py"
if [ -f "$REPORT_SCRIPT" ]; then
    # 运行 Python 脚本发送邮件
    # 如果是巡检则以巡检为标题，如果是备份脚本传来的状态则以备份状态为标题
    if [[ "$TASK_STATUS" == *"巡检"* ]]; then
        SUBJECT="【健康巡检】服务器日常状态报告 - $(date +'%m-%d')"
    else
        SUBJECT="【备份通知】$TASK_STATUS - $(date +'%m-%d')"
    fi
    
    python3 "$REPORT_SCRIPT" "$SUBJECT" "$REPORT_FILE" || true
else
    echo "错误：未找到 $REPORT_SCRIPT，跳过邮件发送。"
fi
