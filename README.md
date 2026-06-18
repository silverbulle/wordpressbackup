# WordPress Google Drive Backup

一个轻量级的 Bash 脚本，用于将 WordPress 网站文件和 MySQL 数据库打包压缩，并通过 `rclone` 自动上传至 Google Drive。它旨在通过系统 Cron 提供定期且可靠的增量化备份解决方案。

## 特性

- **自动解析配置**：自动从 `wp-config.php` 提取数据库账密，无需在脚本中硬编码密码。
- **安全健壮**：采用了 `set -euo pipefail`、过滤单引号转义及注释行，极大降低数据意外丢失的风险。
- **防止磁盘溢出**：备份上传后会自动清理本地副本，即使网络上传失败也会定期清理（默认7天）。
- **云端按需清理**：Google Drive 上的备份默认保留 30 天，自动执行轮转，并利用 `--fast-list` 优化 API 开销。
- **低依赖**：只需安装了标准的 `tar`、`gzip`、`mysqldump` 和 `rclone` 即可运行。

## 依赖条件

- `mysqldump`
- `tar`
- `gzip`
- `rclone`

## 安装与配置

1. **克隆此仓库**并赋予脚本执行权限：
   ```bash
   git clone git@github.com:silverbulle/wordpressbackup.git
   cd wordpressbackup
   chmod +x wp-backup.sh
   ```

2. **配置 Rclone 授权**：
   运行以下命令，添加 Google Drive 访问权限（需要浏览器交互，按照屏幕引导操作）：
   ```bash
   rclone config
   ```
   **注意**：在配置中将您的 Remote 命名为 `gdrive`，或者如果您使用了其他名称，请相应地修改 `wp-backup.sh` 中的 `RCLONE_REMOTE` 变量。

3. **设置定时任务 (Cron)**：
   运行 `crontab -e` 并在末尾添加（例如每周三周六凌晨 2 点执行）：
   ```bash
   0 2 * * 3,6 /home/ubuntu/project/02-wp-gdrive-backup/wp-backup.sh >> /var/log/wp-backup.log 2>&1
   ```

## 环境变量配置

您可以通过直接执行命令时注入环境变量来调整默认行为，无需直接修改脚本：

- `WP_DIR`：WordPress 安装目录（默认 `/var/www/html`）
- `BACKUP_DIR`：本地临时备份路径（默认 `/tmp/wp-backups`）
- `RCLONE_REMOTE`：rclone 中的目标配置（默认 `gdrive:wp-backups`）

例如：
```bash
WP_DIR=/home/www/mysite ./wp-backup.sh
```

## 灾难恢复

遇到网站故障或数据丢失时，我们提供了一个全自动的通用恢复脚本 `wp-restore.sh`，极大简化了恢复流程。

### 1. 从 Google Drive 拉取备份

```bash
# 请将日期替换为具体想要恢复的日期（例如 2026-06-18）
rclone copy "gdrive:wp-backups/2026-06-18/db_backup_2026-06-18.sql.gz" ./
rclone copy "gdrive:wp-backups/2026-06-18/files_backup_2026-06-18.tar.gz" ./
```

### 2. 恢复选项

我们提供了两种恢复方式，您可以选择使用全自动的一键恢复脚本，或手动执行命令：

#### 选项 A：使用一键恢复脚本（推荐）

提供下载好的两个文件路径给恢复脚本。它会自动解压文件，并读取出备份中 `wp-config.php` 的原数据库配置，随后**它会询问您是否继续使用原配置**。
如果您是原机故障恢复，直接回车使用原配置即可；如果您是迁移到了新的服务器，您可以输入 `n` 然后手动输入新服务器的数据库账密来完成导入。

```bash
chmod +x wp-restore.sh
./wp-restore.sh files_backup_2026-06-18.tar.gz db_backup_2026-06-18.sql.gz /var/www/html
```

#### 选项 B：手动恢复

如果您更喜欢精细控制，可以手动执行以下命令：

1. **恢复 WordPress 文件**
   ```bash
   # 将网站文件解压回原目录
   sudo tar -xzf files_backup_2026-06-18.tar.gz -C /var/www/html
   ```

2. **恢复数据库**
   ```bash
   # 解压 SQL 文件并导入到 MySQL 中
   gunzip < db_backup_2026-06-18.sql.gz | mysql -u <数据库用户名> -p <数据库名>
   ```

   **💡 如何查看您的数据库账号和密码？**
   
   如果您忘记了数据库凭据，可以从 WordPress 的配置文件 `wp-config.php` 中查找。该文件通常位于您的网站根目录（例如 `/var/www/html`）。
   使用以下命令即可快速查看：
   
   ```bash
   grep -E "DB_NAME|DB_USER|DB_PASSWORD" /var/www/html/wp-config.php
   ```
   
   您会看到类似如下的输出：
   ```php
   define( 'DB_NAME', 'wordpress_db' );     // 您的数据库名
   define( 'DB_USER', 'wp_user' );          // 您的数据库用户名
   define( 'DB_PASSWORD', 'your_password' );// 您的数据库密码
   ```
   根据输出的内容，将上述命令中的 `<数据库用户名>` 和 `<数据库名>` 替换掉，并在提示输入密码时粘贴您的 `DB_PASSWORD` 即可。
