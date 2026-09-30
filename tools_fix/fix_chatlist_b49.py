# -*- coding: utf-8 -*-
import io

path = r'C:\Users\xilisi\Doubao\chats\2026-09-27\new-chat\baona-app\lib\chatlist.dart'
s = io.open(path, encoding='utf-8').read()

# 1) initState 加 _vlAvatarFuture 初始化
old = """  @override
  void initState() {
    super.initState();
    _refresh();
  }"""
new = """  @override
  void initState() {
    super.initState();
    _vlAvatarFuture = SharedPreferences.getInstance()
        .then((sp) => sp.getString('vl.avatar') ?? '');
    _refresh();
  }"""
assert old in s, 'initState not found'
s = s.replace(old, new)

# 2) 确认 shared_preferences import
if "package:shared_preferences/shared_preferences.dart" not in s:
    old_imp = "import 'theme.dart';"
    new_imp = "import 'package:shared_preferences/shared_preferences.dart';\n\nimport 'theme.dart';"
    assert old_imp in s, 'import not found'
    s = s.replace(old_imp, new_imp)

io.open(path, 'w', encoding='utf-8', newline='').write(s)
print('chatlist initState fixed, len=', len(s))
