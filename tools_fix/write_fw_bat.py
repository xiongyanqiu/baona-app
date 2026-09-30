# -*- coding: utf-8 -*-
# 生成 GBK 编码的 bat（cmd 默认代码页 936，GBK 中文才能正常显示）
content = """@echo off
rem 包娜·放行8633端口（抖音视频服务）——双击运行，自动请求管理员
net session >nul 2>&1
if %errorlevel% neq 0 (
  echo 正在请求管理员权限，请在弹出的窗口点“是”...
  powershell -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)
netsh advfirewall firewall delete rule name="Baona8633" >nul 2>&1
netsh advfirewall firewall add rule name="Baona8633" dir=in action=allow protocol=TCP localport=8633 profile=private,domain
echo.
echo 8633 端口已放行，抖音视频可以用了
echo 如果提示“已存在”，说明之前放过，直接能用。
timeout /t 4 >nul
"""
with open(r'C:\Users\xilisi\Desktop\放行8633端口-抖音视频.bat', 'wb') as f:
    f.write(content.encode('gbk'))
print('bat 已重写（GBK + 自动提权）')
