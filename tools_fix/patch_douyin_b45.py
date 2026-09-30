# -*- coding: utf-8 -*-
import io

path = r'C:\Users\xilisi\Doubao\chats\2026-09-27\new-chat\baona-app\lib\douyin.dart'
s = io.open(path, encoding='utf-8').read()

old = '''        // 顶部返回条
        Positioned(
          top: 0, left: 0, right: 0,
          child: SafeArea(
            bottom: false,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [const Color(0xCC000000), const Color(0x00000000)],
                ),
              ),
              child: Row(children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 20),
                ),
                const Text('抖音',
                    style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
                const Spacer(),
                const Text('网页版',
                    style: TextStyle(color: Colors.white70, fontSize: 11.5)),
                const SizedBox(width: 12),
              ]),
            ),
          ),
        ),'''

new = '''        // 左上角小返回按钮（不遮挡网页顶部导航）
        Positioned(
          top: MediaQuery.of(context).padding.top + 4,
          left: 8,
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0x66000000),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 18),
            ),
          ),
        ),'''

assert old in s, 'top bar block not found'
s = s.replace(old, new)

io.open(path, 'w', encoding='utf-8', newline='').write(s)
print('top bar minimized ok, len=', len(s))
