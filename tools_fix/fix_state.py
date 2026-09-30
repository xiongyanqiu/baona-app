# -*- coding: utf-8 -*-
import io
p = r'C:\Users\xilisi\Doubao\chats\2026-09-27\new-chat\baona-app\lib\chat.dart'
s = io.open(p, encoding='utf-8').read()
old = 'class _ChatPageState extends State<ChatPage> {'
new = 'class _ChatPageState extends State<ConversationPage> {'
assert old in s, 'match fail'
s = s.replace(old, new)
io.open(p, 'w', encoding='utf-8', newline='').write(s)
print('state base class fixed')
