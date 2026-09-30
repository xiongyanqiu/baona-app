# -*- coding: utf-8 -*-
import io, re

# theme.dart: kAppVer 17 -> 18
p1 = r'C:\Users\xilisi\Doubao\chats\2026-09-27\new-chat\baona-app\lib\theme.dart'
s1 = io.open(p1, encoding='utf-8').read()
s1 = re.sub(r"const String kAppVer = '1\.2\.2 \(\d+\)';",
            "const String kAppVer = '1.2.2 (18)';", s1)
assert '(18)' in s1, 'kAppVer bump fail'
io.open(p1, 'w', encoding='utf-8', newline='').write(s1)

# pubspec.yaml: version 1.2.2+17 -> 1.2.2+18
p2 = r'C:\Users\xilisi\Doubao\chats\2026-09-27\new-chat\baona-app\pubspec.yaml'
s2 = io.open(p2, encoding='utf-8').read()
s2 = re.sub(r"^version: 1\.2\.2\+17\s*$", "version: 1.2.2+18", s2, flags=re.M)
assert '1.2.2+18' in s2, 'pubspec bump fail'
io.open(p2, 'w', encoding='utf-8', newline='').write(s2)
print('version bumped to 1.2.2 (18)')
