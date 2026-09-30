# -*- coding: utf-8 -*-
import io

# chat.dart 两处头像调用：avatarOf(av)!.toString() → av（ImgCache 自己处理 data:/http）
p = r'C:\Users\xilisi\Doubao\chats\2026-09-27\new-chat\baona-app\lib\chat.dart'
s = io.open(p, encoding='utf-8').read()

old1 = "future: ImgCache.provider(avatarOf(av)!.toString()),"
new1 = "future: ImgCache.provider(av),"
n = s.count(old1)
assert n == 2, f'avatar calls count={n}'
s = s.replace(old1, new1)
io.open(p, 'w', encoding='utf-8', newline='').write(s)
print(f'chat.dart {n} 处头像调用改为 ImgCache.provider(av)')
