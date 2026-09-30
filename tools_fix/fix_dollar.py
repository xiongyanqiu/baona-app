# -*- coding: utf-8 -*-
import io

p = r'C:\Users\xilisi\Doubao\chats\2026-09-27\new-chat\baona-app\lib\douyin.dart'
s = io.open(p, encoding='utf-8').read()
bad = "\\${"
n = s.count(bad)
s = s.replace(bad, "${")
io.open(p, 'w', encoding='utf-8', newline='').write(s)
print(f'fixed {n} escaped interpolations')

# 复核
s2 = io.open(p, encoding='utf-8').read()
for i, line in enumerate(s2.splitlines(), 1):
    if '\\${' in line:
        print(f'REMAIN L{i}: {line.strip()}')
print('no remaining escaped $' if '\\${' not in s2 else 'STILL HAS BAD')
