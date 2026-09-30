# -*- coding: utf-8 -*-
import io

p = r'C:\Users\xilisi\Doubao\chats\2026-09-27\new-chat\baona-app\lib\main.dart'
s = io.open(p, encoding='utf-8').read()

old_import = "import 'api.dart';\nimport 'eye.dart';\nimport 'chat.dart';"
new_import = "import 'api.dart';\nimport 'chat.dart';\nimport 'chatlist.dart';\nimport 'eye.dart';"
assert old_import in s, 'import match fail'
s = s.replace(old_import, new_import)

old_tab = "                    child: IndexedStack(index: _tab, children: const [\n                      ChatPage(),"
new_tab = "                    child: IndexedStack(index: _tab, children: const [\n                      ChatListPage(),"
assert old_tab in s, 'tab match fail'
s = s.replace(old_tab, new_tab)

io.open(p, 'w', encoding='utf-8', newline='').write(s)
print('main.dart OK')
