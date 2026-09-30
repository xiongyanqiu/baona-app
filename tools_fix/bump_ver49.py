# -*- coding: utf-8 -*-
import io, re

p1 = r'C:\Users\xilisi\Doubao\chats\2026-09-27\new-chat\baona-app\lib\theme.dart'
s1 = io.open(p1, encoding='utf-8').read()
s1 = re.sub(r"const String kAppVer = '1\.3\.0 \(\d+\)';",
            "const String kAppVer = '1.3.0 (49)';", s1)
assert '(49)' in s1, 'kAppVer fail'
io.open(p1, 'w', encoding='utf-8', newline='').write(s1)

p2 = r'C:\Users\xilisi\Doubao\chats\2026-09-27\new-chat\baona-app\pubspec.yaml'
s2 = io.open(p2, encoding='utf-8').read()
s2 = re.sub(r"^version: [\d.]+\+\d+\s*$", "version: 1.3.0+49", s2, flags=re.M)
assert '1.3.0+49' in s2, 'pubspec fail'
io.open(p2, 'w', encoding='utf-8', newline='').write(s2)
print('bumped to 1.3.0 (49)')
