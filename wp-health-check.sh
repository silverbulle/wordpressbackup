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
    echo "---------- 🔧 关键服务运行状态 ----------"
    # 检查 Apache2 状态
    if systemctl is-active --quiet apache2; then
        echo "✅ Web Server (apache2): 运行中"
    else
        echo "❌ Web Server (apache2): 异常/停止"
    fi

    # 检查 MySQL 状态
    if systemctl is-active --quiet mysql; then
        echo "✅ 数据库 (mysql): 运行中"
    else
        echo "❌ 数据库 (mysql): 异常/停止"
    fi

    # 检查本地 Web 页面连通性
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 http://127.0.0.1/ || echo "000")
    if [[ "$HTTP_CODE" =~ ^[23] ]]; then
        echo "✅ Web 页面连通性: 正常 (状态码: $HTTP_CODE)"
    else
        echo "❌ Web 页面连通性: 异常 (状态码: $HTTP_CODE)"
    fi
    echo ""
    echo "---------- 🚨 安全：过去 24 小时【成功】的 SSH 登录记录 ----------"
    # 统计成功的 SSH 登录记录
    SUCCESS_SSH=$(journalctl -u ssh --since "1 day ago" 2>/dev/null | grep "Accepted" | awk '{print $1,$2,$3, "用户:",$9, "IP:",$11}' || true)
    if [ -n "$SUCCESS_SSH" ]; then
        echo "⚠️ 警告：检测到有成功的 SSH 登录，请核对是否为您本人的操作！"
        echo "$SUCCESS_SSH"
    else
        echo "无成功登录记录"
    fi
    echo ""
    echo "---------- 🛡️ 安全：过去 24 小时【失败】的 SSH 登录尝试 (Top 10 IP) ----------"
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
