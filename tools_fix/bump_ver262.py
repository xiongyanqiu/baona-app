# -*- coding: utf-8 -*-
import io, re

# 版本号 26.2（归零重计）
p1 = r'C:\Users\xilisi\Doubao\chats\2026-09-27\new-chat\baona-app\lib\theme.dart'
s1 = io.open(p1, encoding='utf-8').read()
s1 = re.sub(r"const String kAppVer = '[^']*';",
            "const String kAppVer = '26.2';", s1)
assert "26.2" in s1, 'kAppVer fail'
io.open(p1, 'w', encoding='utf-8', newline='').write(s1)

p2 = r'C:\Users\xilisi\Doubao\chats\2026-09-27\new-chat\baona-app\pubspec.yaml'
s2 = io.open(p2, encoding='utf-8').read()
s2 = re.sub(r"^version: [\d.]+\+\d+\s*$", "version: 26.2.0+0", s2, flags=re.M)
assert '26.2.0+0' in s2, 'pubspec fail'
io.open(p2, 'w', encoding='utf-8', newline='').write(s2)
print('version -> 26.2')
