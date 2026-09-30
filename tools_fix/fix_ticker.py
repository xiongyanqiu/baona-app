# -*- coding: utf-8 -*-
import io

p = r'C:\Users\xilisi\Doubao\chats\2026-09-27\new-chat\baona-app\lib\main.dart'
s = io.open(p, encoding='utf-8').read()

old = "class _HomePageState extends State<HomePage> {"
new = "class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {"
assert old in s, 'mixin anchor fail'
s = s.replace(old, new)
io.open(p, 'w', encoding='utf-8', newline='').write(s)
print('_HomePageState 加 SingleTickerProviderStateMixin')
