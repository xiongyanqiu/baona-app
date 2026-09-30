# -*- coding: utf-8 -*-
import io

# 1) theme.dart 版本号显示 26.2.50
p1 = r'C:\Users\xilisi\Doubao\chats\2026-09-27\new-chat\baona-app\lib\theme.dart'
s1 = io.open(p1, encoding='utf-8').read()
if "const String kAppVer = '26.2';" in s1:
    s1 = s1.replace("const String kAppVer = '26.2';", "const String kAppVer = '26.2.50';")
    io.open(p1, 'w', encoding='utf-8', newline='').write(s1)
    print('theme kAppVer -> 26.2.50')
else:
    print('theme already updated or pattern missing')

# 2) videolib.dart 标题旁显示版本
p2 = r'C:\Users\xilisi\Doubao\chats\2026-09-27\new-chat\baona-app\lib\videolib.dart'
s2 = io.open(p2, encoding='utf-8').read()
old = """                const Text('视频库',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),"""
new = """                const Text('视频库',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                Text('v' + kAppVer,
                    style: TextStyle(
                        color: Colors.white38,
                        fontSize: 11)),"""
if old in s2:
    s2 = s2.replace(old, new)
    if "import 'theme.dart';" not in s2:
        s2 = s2.replace(
            "import 'package:video_player/video_player.dart';",
            "import 'package:video_player/video_player.dart';\nimport 'theme.dart';")
    io.open(p2, 'w', encoding='utf-8', newline='').write(s2)
    print('videolib version label ok')
else:
    print('videolib pattern missing')
