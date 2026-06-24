#!/usr/bin/env python3
import sys
import os
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

# ================= 配置区 =================
# 请在此处填入您的 SMTP 邮箱配置
SMTP_SERVER = "smtp.gmail.com"      # 例如: smtp.gmail.com 或 smtp.qq.com
SMTP_PORT = 587                     # 常见端口: 465 (SSL) 或 587 (TLS/STARTTLS)
SMTP_USER = "zh904666694@gmail.com"  # 您的发件箱账号
SMTP_PASS = "wekd eysz orem znlf"     # 您的邮箱授权码（非登录密码）
TO_EMAIL = "904666694@qq.com"   # 接收报告的邮箱
# ==========================================

if len(sys.argv) < 3:
    print(f"Usage: {sys.argv[0]} <Subject> <Report_File>")
    sys.exit(1)

subject = sys.argv[1]
report_file = sys.argv[2]

try:
    with open(report_file, 'r', encoding='utf-8') as f:
        report_content = f.read()
except Exception as e:
    report_content = f"无法读取报告文件: {e}"

msg = MIMEMultipart('alternative')
msg['From'] = SMTP_USER
msg['To'] = TO_EMAIL
msg['Subject'] = subject

# 自动将 Bash 纯文本报告转换为美观的 HTML 格式
html_content = f"""
<html>
<body style="font-family: 'Helvetica Neue', Helvetica, Arial, sans-serif; background-color: #f4f6f8; padding: 20px; margin: 0;">
    <div style="max-width: 800px; margin: 0 auto; background-color: #ffffff; padding: 30px; border-radius: 8px; box-shadow: 0 4px 10px rgba(0,0,0,0.1);">
        <h2 style="color: #2c3e50; border-bottom: 2px solid #3498db; padding-bottom: 10px; margin-top: 0;">📊 服务器巡检与备份报告</h2>
        <div style="font-size: 14px; line-height: 1.6; color: #34495e;">
"""

for line in report_content.split('\n'):
    if "⚠️ 警告" in line:
        html_content += f'<div style="color: white; background-color: #e74c3c; padding: 12px; border-radius: 5px; font-weight: bold; font-size: 15px; margin: 10px 0;">🚨 {line}</div>'
    elif "✅" in line:
        html_content += f'<div style="color: #27ae60; font-weight: bold; padding: 4px 0;">{line}</div>'
    elif "❌" in line:
        html_content += f'<div style="color: #c0392b; font-weight: bold; padding: 4px 0;">{line}</div>'
    elif "----------" in line:
        title = line.replace("-", "").strip()
        html_content += f'<h3 style="color: #2980b9; margin-top: 30px; margin-bottom: 15px; border-left: 4px solid #2980b9; padding-left: 10px;">{title}</h3>'
    elif "===" in line or "📊" in line:
        continue
    else:
        if line.strip():
            # 普通输出使用等宽字体，保持表格对齐效果
            html_content += f'<div style="background-color: #f8f9fa; font-family: Consolas, Courier, monospace; padding: 4px 8px; margin-bottom: 2px; border-radius: 3px; font-size: 13px; white-space: pre-wrap;">{line}</div>'
        else:
            html_content += '<div style="height: 10px;"></div>'

html_content += """
        </div>
        <div style="margin-top: 40px; padding-top: 20px; border-top: 1px solid #eee; font-size: 12px; color: #95a5a6; text-align: center;">
            由 WordPress GDrive Backup 自动生成
        </div>
    </div>
</body>
</html>
"""

# 同时附加纯文本和 HTML 版本（邮件客户端会优先显示 HTML）
msg.attach(MIMEText(report_content, 'plain', 'utf-8'))
msg.attach(MIMEText(html_content, 'html', 'utf-8'))

try:
    # 尝试 SSL 端口
    if SMTP_PORT == 465:
        server = smtplib.SMTP_SSL(SMTP_SERVER, SMTP_PORT)
    else:
        server = smtplib.SMTP(SMTP_SERVER, SMTP_PORT)
        server.starttls()
        
    server.login(SMTP_USER, SMTP_PASS)
    server.sendmail(SMTP_USER, TO_EMAIL, msg.as_string())
    server.quit()
    print("邮件发送成功！")
except Exception as e:
    print(f"邮件发送失败: {e}")
    sys.exit(1)
