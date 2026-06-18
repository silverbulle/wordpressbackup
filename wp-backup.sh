#!/bin/bash
set -euo pipefail

# Default variables
WP_DIR="${WP_DIR:-/var/www/html}"
BACKUP_DIR="${BACKUP_DIR:-/tmp/wp-backups}"
RCLONE_REMOTE="${RCLONE_REMOTE:-gdrive:wp-backups}"
DATE=$(date +"%Y-%m-%d")

# Check dependencies
for cmd in mysqldump tar gzip rclone; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "Error: $cmd is not installed."
        exit 1
    fi
done

echo "All dependencies met."

echo "Reading database credentials..."
if [ ! -f "$WP_DIR/wp-config.php" ]; then
    echo "Error: wp-config.php not found at $WP_DIR"
    exit 1
fi

DB_NAME=$(sed -n "s/^[[:space:]]*define([[:space:]]*['\"]DB_NAME['\"][[:space:]]*,[[:space:]]*['\"]\(.*\)['\"][[:space:]]*);.*/\1/p" "$WP_DIR/wp-config.php")
DB_USER=$(sed -n "s/^[[:space:]]*define([[:space:]]*['\"]DB_USER['\"][[:space:]]*,[[:space:]]*['\"]\(.*\)['\"][[:space:]]*);.*/\1/p" "$WP_DIR/wp-config.php")
DB_PASSWORD=$(sed -n "s/^[[:space:]]*define([[:space:]]*['\"]DB_PASSWORD['\"][[:space:]]*,[[:space:]]*['\"]\(.*\)['\"][[:space:]]*);.*/\1/p" "$WP_DIR/wp-config.php")
DB_HOST=$(sed -n "s/^[[:space:]]*define([[:space:]]*['\"]DB_HOST['\"][[:space:]]*,[[:space:]]*['\"]\(.*\)['\"][[:space:]]*);.*/\1/p" "$WP_DIR/wp-config.php")

if [ -z "$DB_NAME" ] || [ -z "$DB_USER" ]; then
    echo "Error: Could not extract database credentials."
    exit 1
fi
echo "Credentials extracted successfully."
