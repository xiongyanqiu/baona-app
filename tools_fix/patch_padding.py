# -*- coding: utf-8 -*-
import io

# ---- chat.dart：对话页无底栏，底部留白改安全区 ----
p = r'C:\Users\xilisi\Doubao\chats\2026-09-27\new-chat\baona-app\lib\chat.dart'
s = io.open(p, encoding='utf-8').read()

old1 = "padding: EdgeInsets.fromLTRB(14, 8, 14, kbUp(context) ? 16 : navSpace(context) + 16),"
new1 = "padding: EdgeInsets.fromLTRB(14, 8, 14, kbUp(context) ? 16 : MediaQuery.of(context).padding.bottom + 16),"
assert old1 in s, 'padding1 match fail'
s = s.replace(old1, new1)

old2 = "padding: EdgeInsets.only(bottom: kbUp(context) ? 6 : navSpace(context)),"
new2 = "padding: EdgeInsets.only(bottom: kbUp(context) ? 6 : MediaQuery.of(context).padding.bottom + 10),"
assert old2 in s, 'padding2 match fail'
s = s.replace(old2, new2)

io.open(p, 'w', encoding='utf-8', newline='').write(s)
print('chat.dart padding OK')

# ---- chatlist.dart：还在主界面（有底栏），列表底部留 navSpace ----
p2 = r'C:\Users\xilisi\Doubao\chats\2026-09-27\new-chat\baona-app\lib\chatlist.dart'
s2 = io.open(p2, encoding='utf-8').read()

old3 = "          padding: const EdgeInsets.only(top: 4, bottom: 4),"
new3 = "          padding: EdgeInsets.only(top: 4, bottom: navSpace(context) + 8),"
assert old3 in s2, 'list padding match fail'
s2 = s2.replace(old3, new3)

io.open(p2, 'w', encoding='utf-8', newline='').write(s2)
print('chatlist.dart padding OK')
