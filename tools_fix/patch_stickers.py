# -*- coding: utf-8 -*-
import io

# stickers.dart：import 用 theme.dart 那行加
p = r'C:\Users\xilisi\Doubao\chats\2026-09-27\new-chat\baona-app\lib\stickers.dart'
s = io.open(p, encoding='utf-8').read()
old_imp = "import 'main.dart';\nimport 'theme.dart';"
new_imp = "import 'main.dart';\nimport 'theme.dart';\nimport 'imgsrv.dart';"
assert old_imp in s, 'stickers import fail'
s = s.replace(old_imp, new_imp)

old_st = """                          child: Image.network(
                            app.api?.emojiUrl(n) ?? '',
                            headers: {'x-wc-token': app.api?.token ?? ''},
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const ColoredBox(color: kGlass),
                          ),"""
new_st = """                          child: CacheImg(
                            app.api?.emojiUrl(n) ?? '',
                            headers: {'x-wc-token': app.api?.token ?? ''},
                            fit: BoxFit.cover,
                          ),"""
assert old_st in s, 'stickers img fail'
s = s.replace(old_st, new_st)
io.open(p, 'w', encoding='utf-8', newline='').write(s)
print('stickers.dart → CacheImg OK')
