# -*- coding: utf-8 -*-
import io

# ============ 1. pubspec 加 path_provider ============
p = r'C:\Users\xilisi\Doubao\chats\2026-09-27\new-chat\baona-app\pubspec.yaml'
s = io.open(p, encoding='utf-8').read()
old = "  shared_preferences: ^2.3.0   # 记住地址 / 登录 / 本地设置"
new = "  shared_preferences: ^2.3.0   # 记住地址 / 登录 / 本地设置\n  path_provider: ^2.1.4       # 图片磁盘缓存目录（卡顿根治）"
assert old in s, 'pubspec anchor fail'
s = s.replace(old, new)
io.open(p, 'w', encoding='utf-8', newline='').write(s)
print('pubspec 加 path_provider')

# ============ 2. chat.dart：2 处消息图 + 表情 → CacheImg ============
p = r'C:\Users\xilisi\Doubao\chats\2026-09-27\new-chat\baona-app\lib\chat.dart'
s = io.open(p, encoding='utf-8').read()
old_imp = "import 'msglocal.dart';"
new_imp = "import 'msglocal.dart';\nimport 'imgsrv.dart';"
assert old_imp in s, 'chat import fail'
s = s.replace(old_imp, new_imp)

# 表情（L491 区，注意看实际文本）
old_emoji = "child: Image.network(urlOf.emojiUrl(m.sticker!), width: 132, fit: BoxFit.cover,"
new_emoji = "child: CacheImg(urlOf.emojiUrl(m.sticker!), width: 132, fit: BoxFit.cover,"
assert old_emoji in s, 'chat emoji fail'
s = s.replace(old_emoji, new_emoji)

old_img = "child: Image.network(urlOf.imgUrl(u), width: 210, fit: BoxFit.cover,"
new_img = "child: CacheImg(urlOf.imgUrl(u), width: 210, fit: BoxFit.cover,"
assert old_img in s, 'chat img fail'
s = s.replace(old_img, new_img)
io.open(p, 'w', encoding='utf-8', newline='').write(s)
print('chat.dart 表情/聊天图 → CacheImg')

# ============ 3. shop.dart 3 处 → CacheImg ============
p = r'C:\Users\xilisi\Doubao\chats\2026-09-27\new-chat\baona-app\lib\shop.dart'
s = io.open(p, encoding='utf-8').read()
old_imp = "import 'api.dart';"
new_imp = "import 'api.dart';\nimport 'imgsrv.dart';"
assert old_imp in s, 'shop import fail'
s = s.replace(old_imp, new_imp)

old1 = "child: Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const ColoredBox(color: kGlass2)),"
new1 = "child: CacheImg(url, fit: BoxFit.cover),"
assert old1 in s, 'shop1 fail'
s = s.replace(old1, new1)

old2 = "child: Image.network(url, height: 240, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const ColoredBox(color: kGlass2, child: SizedBox(height: 240))),"
new2 = "child: CacheImg(url, height: 240, width: double.infinity, fit: BoxFit.cover),"
assert old2 in s, 'shop2 fail'
s = s.replace(old2, new2)

old3 = "ClipRRect(borderRadius: BorderRadius.circular(9), child: Image.network(url, width: 56, height: 56, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox(width: 56, height: 56))),"
new3 = "CacheImg(url, width: 56, height: 56, fit: BoxFit.cover, radius: BorderRadius.circular(9)),"
assert old3 in s, 'shop3 fail'
s = s.replace(old3, new3)
io.open(p, 'w', encoding='utf-8', newline='').write(s)
print('shop.dart 3 处 → CacheImg')

# ============ 4. stickers.dart 表情 → CacheImg（带 token 头） ============
p = r'C:\Users\xilisi\Doubao\chats\2026-09-27\new-chat\baona-app\lib\stickers.dart'
s = io.open(p, encoding='utf-8').read()
old_imp = "import 'api.dart';"
new_imp = "import 'api.dart';\nimport 'imgsrv.dart';"
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
print('stickers.dart → CacheImg')
