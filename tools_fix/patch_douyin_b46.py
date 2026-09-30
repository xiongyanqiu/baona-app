# -*- coding: utf-8 -*-
import io

path = r'C:\Users\xilisi\Doubao\chats\2026-09-27\new-chat\baona-app\lib\douyin.dart'
s = io.open(path, encoding='utf-8').read()

old = '''        // 全屏网页
        Positioned.fill(child: WebViewWidget(controller: _wv)),'''
new = '''        // 全屏网页（从状态栏下面开始，网页顶部导航不被刘海挡住/可点）
        Positioned.fill(
          top: MediaQuery.of(context).padding.top,
          child: WebViewWidget(controller: _wv),
        ),'''

assert old in s, 'webview block not found'
s = s.replace(old, new)

io.open(path, 'w', encoding='utf-8', newline='').write(s)
print('safearea top patch ok, len=', len(s))
