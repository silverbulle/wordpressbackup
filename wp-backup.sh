#!/bin/bash
set -euo pipefail

# 默认变量配置
WP_DIR="${WP_DIR:-/var/www/html}"
BACKUP_DIR="${BACKUP_DIR:-/tmp/wp-backups}"
RCLONE_REMOTE="${RCLONE_REMOTE:-serverbackup:wp-backups}"
DATE=$(date +"%Y-%m-%d")

# === 邮件报告与收尾逻辑 ===
function finish_and_report() {
    local exit_code=$?
    local status="✅ 备份任务成功"
    if [ $exit_code -ne 0 ]; then
        status="❌ 备份任务失败 (退出码: $exit_code)"
    fi

    echo "正在生成系统状态报告..."
    REPORT_FILE="/tmp/wp-backup-report.txt"
    {
        echo "==================================="
        echo " 📊 WordPress 备份与系统状态报告"
        echo "==================================="
        echo "时间: $(date +'%Y-%m-%d %H:%M:%S')"
        echo "状态: $status"
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
        python3 "$REPORT_SCRIPT" "【服务器报告】$status - $(date +'%m-%d')" "$REPORT_FILE" || true
    fi
}
trap finish_and_report EXIT
# ==========================

# 检查系统依赖
for cmd in mysqldump tar gzip rclone; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "错误: 未安装 $cmd。"
        exit 1
    fi
done

echo "所有依赖检查通过。"

echo "正在读取数据库凭据..."
if [ ! -f "$WP_DIR/wp-config.php" ]; then
    echo "错误: 在 $WP_DIR 下未找到 wp-config.php 文件"
    exit 1
fi

DB_NAME=$(sed -n "s/^[[:space:]]*define([[:space:]]*['\"]DB_NAME['\"][[:space:]]*,[[:space:]]*['\"]\(.*\)['\"][[:space:]]*);.*/\1/p" "$WP_DIR/wp-config.php")
DB_USER=$(sed -n "s/^[[:space:]]*define([[:space:]]*['\"]DB_USER['\"][[:space:]]*,[[:space:]]*['\"]\(.*\)['\"][[:space:]]*);.*/\1/p" "$WP_DIR/wp-config.php")
DB_PASSWORD=$(sed -n "s/^[[:space:]]*define([[:space:]]*['\"]DB_PASSWORD['\"][[:space:]]*,[[:space:]]*['\"]\(.*\)['\"][[:space:]]*);.*/\1/p" "$WP_DIR/wp-config.php")
DB_HOST=$(sed -n "s/^[[:space:]]*define([[:space:]]*['\"]DB_HOST['\"][[:space:]]*,[[:space:]]*['\"]\(.*\)['\"][[:space:]]*);.*/\1/p" "$WP_DIR/wp-config.php")

if [ -z "$DB_NAME" ] || [ -z "$DB_USER" ]; then
    echo "错误: 无法提取数据库凭据。"
    exit 1
fi
echo "凭据提取成功。"

# 创建本地备份目录
mkdir -p "$BACKUP_DIR"

DB_BACKUP_FILE="$BACKUP_DIR/db_backup_$DATE.sql.gz"
FILES_BACKUP_FILE="$BACKUP_DIR/files_backup_$DATE.tar.gz"

echo "正在导出数据库..."
# 添加 --no-tablespaces 参数以解决 PROCESS 权限报错
MYSQL_PWD="$DB_PASSWORD" mysqldump --no-tablespaces -h "$DB_HOST" -u "$DB_USER" "$DB_NAME" | gzip > "$DB_BACKUP_FILE"

echo "正在打包网站文件..."
tar -czf "$FILES_BACKUP_FILE" -C "$WP_DIR" --exclude="wp-content/cache" . || [[ $? -eq 1 ]]

echo "本地备份文件创建完毕。"

echo "正在通过 rclone 上传到云端..."
rclone copy "$DB_BACKUP_FILE" "$RCLONE_REMOTE/$DATE/"
rclone copy "$FILES_BACKUP_FILE" "$RCLONE_REMOTE/$DATE/"

echo "正在清理本地备份..."
rm -f "$DB_BACKUP_FILE" "$FILES_BACKUP_FILE"
find "$BACKUP_DIR" -type f -name "*.tar.gz" -mtime +7 -delete || true
find "$BACKUP_DIR" -type f -name "*.sql.gz" -mtime +7 -delete || true

echo "正在应用保留策略（云端保留最近 30 天）..."
rclone delete "$RCLONE_REMOTE" --min-age 30d --rmdirs --fast-list

echo "备份任务圆满完成。"
