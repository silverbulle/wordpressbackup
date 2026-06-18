#!/bin/bash
set -e

# Default variables
WP_DIR="/var/www/html"
BACKUP_DIR="/tmp/wp-backups"
RCLONE_REMOTE="gdrive:wp-backups"
DATE=$(date +"%Y-%m-%d")

# Check dependencies
for cmd in mysqldump tar gzip rclone; do
    if ! command -v $cmd &> /dev/null; then
        echo "Error: $cmd is not installed."
        exit 1
    fi
done

echo "All dependencies met."
