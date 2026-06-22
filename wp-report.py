#!/usr/bin/env python3
import sys
import os
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

# ================= 配置区 =================
# 请在此处填入您的 SMTP 邮箱配置
SMTP_SERVER = "smtp.gmail.com"      # 例如: smtp.gmail.com 或 smtp.qq.com
SMTP_PORT = 465                     # 常见端口: 465 (SSL) 或 587 (TLS/STARTTLS)
SMTP_USER = "your_email@gmail.com"  # 您的发件箱账号
SMTP_PASS = "your_app_password"     # 您的邮箱授权码（非登录密码）
TO_EMAIL = "your_email@gmail.com"   # 接收报告的邮箱
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

msg = MIMEMultipart()
msg['From'] = SMTP_USER
msg['To'] = TO_EMAIL
msg['Subject'] = subject

msg.attach(MIMEText(report_content, 'plain', 'utf-8'))

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
