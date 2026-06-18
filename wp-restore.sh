#!/bin/bash
set -euo pipefail

if [ "$#" -lt 2 ]; then
    echo "用法: $0 <网站文件备份_tar.gz> <数据库备份_sql.gz> [恢复目标目录(默认:/var/www/html)]"
    echo "示例: $0 files_backup_2026-06-18.tar.gz db_backup_2026-06-18.sql.gz /var/www/html"
    exit 1
fi

FILES_BACKUP="$1"
DB_BACKUP="$2"
WP_DIR="${3:-/var/www/html}"

if [ ! -f "$FILES_BACKUP" ]; then
    echo "错误: 找不到网站文件备份 $FILES_BACKUP"
    exit 1
fi

if [ ! -f "$DB_BACKUP" ]; then
    echo "错误: 找不到数据库备份 $DB_BACKUP"
    exit 1
fi

echo "================================================="
echo "准备恢复 WordPress 备份"
echo "网站文件备份: $FILES_BACKUP"
echo "数据库备份:   $DB_BACKUP"
echo "恢复目标目录: $WP_DIR"
echo "================================================="
read -p "警告: 这将覆盖现有的网站文件和同名数据库！确定要继续吗？(y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "已取消恢复。"
    exit 0
fi

echo "[1/3] 正在解压网站文件到 $WP_DIR ..."
sudo mkdir -p "$WP_DIR"
sudo tar -xzf "$FILES_BACKUP" -C "$WP_DIR"

echo "[2/3] 正在从恢复的 wp-config.php 中读取数据库凭据..."
if [ ! -f "$WP_DIR/wp-config.php" ]; then
    echo "错误: 恢复的文件中找不到 wp-config.php。请检查备份压缩包是否完整。"
    exit 1
fi

# 提取备份中的数据库凭据
DB_NAME_CFG=$(sudo sed -n "s/^[[:space:]]*define([[:space:]]*['\"]DB_NAME['\"][[:space:]]*,[[:space:]]*['\"]\(.*\)['\"][[:space:]]*);.*/\1/p" "$WP_DIR/wp-config.php")
DB_USER_CFG=$(sudo sed -n "s/^[[:space:]]*define([[:space:]]*['\"]DB_USER['\"][[:space:]]*,[[:space:]]*['\"]\(.*\)['\"][[:space:]]*);.*/\1/p" "$WP_DIR/wp-config.php")
DB_PASSWORD_CFG=$(sudo sed -n "s/^[[:space:]]*define([[:space:]]*['\"]DB_PASSWORD['\"][[:space:]]*,[[:space:]]*['\"]\(.*\)['\"][[:space:]]*);.*/\1/p" "$WP_DIR/wp-config.php")
DB_HOST_CFG=$(sudo sed -n "s/^[[:space:]]*define([[:space:]]*['\"]DB_HOST['\"][[:space:]]*,[[:space:]]*['\"]\(.*\)['\"][[:space:]]*);.*/\1/p" "$WP_DIR/wp-config.php")

echo "-------------------------------------------------"
echo "从备份的 wp-config.php 中提取到以下配置："
echo "数据库名: $DB_NAME_CFG"
echo "用户名:   $DB_USER_CFG"
echo "主机:     $DB_HOST_CFG"
echo "-------------------------------------------------"
read -p "如果您在同一台机器上原样恢复，请直接按回车；如果是迁移到新环境，您可能需要提供新的连接凭据。是否使用上面的配置？(Y/n) " use_cfg

if [[ $use_cfg =~ ^[Nn]$ ]]; then
    read -p "请输入新的数据库主机 (默认: localhost): " input_host
    DB_HOST=${input_host:-localhost}
    read -p "请输入新的数据库名: " DB_NAME
    read -p "请输入新的数据库用户: " DB_USER
    read -s -p "请输入新的数据库密码: " DB_PASSWORD
    echo
else
    DB_NAME=$DB_NAME_CFG
    DB_USER=$DB_USER_CFG
    DB_PASSWORD=$DB_PASSWORD_CFG
    DB_HOST=$DB_HOST_CFG
fi

if [ -z "$DB_NAME" ] || [ -z "$DB_USER" ]; then
    echo "错误: 数据库凭据缺失，无法进行恢复。"
    exit 1
fi

echo "[3/3] 正在清空并导入数据库 ($DB_NAME) ..."
# 直接将解压流管道导入 mysql
gunzip -c "$DB_BACKUP" | MYSQL_PWD="$DB_PASSWORD" mysql -h "$DB_HOST" -u "$DB_USER" "$DB_NAME"

echo "================================================="
echo "🎉 恢复圆满完成！"
echo "请在浏览器中检查网站是否能够正常访问。"
