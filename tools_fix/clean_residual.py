# -*- coding: utf-8 -*-
import io

# ============ chat.dart：去掉 CacheImg 后的 errorBuilder 残留 ============
p = r'C:\Users\xilisi\Doubao\chats\2026-09-27\new-chat\baona-app\lib\chat.dart'
s = io.open(p, encoding='utf-8').read()

old1 = """            child: CacheImg(urlOf.emojiUrl(m.sticker!), width: 132, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox(width: 80, height: 60, child: Center(child: Text('表情没了', style: TextStyle(fontSize: 11, color: kSub))))),"""
new1 = """            child: CacheImg(urlOf.emojiUrl(m.sticker!), width: 132, fit: BoxFit.cover),"""
assert old1 in s, 'chat emoji residual fail'
s = s.replace(old1, new1)

old2 = """              child: CacheImg(urlOf.imgUrl(u), width: 210, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox(width: 160, height: 90, child: Center(child: Text('图没加载出来', style: TextStyle(fontSize: 11, color: kSub))))),"""
new2 = """              child: CacheImg(urlOf.imgUrl(u), width: 210, fit: BoxFit.cover),"""
assert old2 in s, 'chat img residual fail'
s = s.replace(old2, new2)
io.open(p, 'w', encoding='utf-8', newline='').write(s)
print('chat.dart 残留 errorBuilder 已清')

# ============ us.dart：CacheImg 后 loadingBuilder/errorBuilder 残留 ============
p = r'C:\Users\xilisi\Doubao\chats\2026-09-27\new-chat\baona-app\lib\us.dart'
s = io.open(p, encoding='utf-8').read()

old3 = """                  child: CacheImg(
                    // ★2026-09-29 缩略图：网格只下小图（服务端 ?w=500 返回，流量少一大截），点开才看原图
                    app.api!.albumPhotoUrl(ph.url, w: 500),
                    fit: BoxFit.cover,
                    // ★b21 缩略图解码 + 磁盘缓存：秒开不烫
                    cacheWidth: 420,
                    loadingBuilder: (c, child, prog) =>
                        prog == null ? child : Container(color: const Color(0xFF1B1B22)),
                    errorBuilder: (_, __, ___) => Container(color: const Color(0xFF1B1B22), child: const Center(child: Icon(Icons.broken_image_outlined, size: 18, color: kSub))),
                  ),"""
new3 = """                  child: CacheImg(
                    // ★2026-09-29 缩略图：网格只下小图（服务端 ?w=500 返回，流量少一大截），点开才看原图
                    app.api!.albumPhotoUrl(ph.url, w: 500),
                    fit: BoxFit.cover,
                    // ★b21 缩略图解码 + 磁盘缓存：秒开不烫
                    cacheWidth: 420,
                  ),"""
assert old3 in s, 'us residual fail'
s = s.replace(old3, new3)
io.open(p, 'w', encoding='utf-8', newline='').write(s)
print('us.dart 残留 loadingBuilder/errorBuilder 已清')

# 复核
for f in [r'C:\Users\xilisi\Doubao\chats\2026-09-27\new-chat\baona-app\lib\chat.dart',
          r'C:\Users\xilisi\Doubao\chats\2026-09-27\new-chat\baona-app\lib\us.dart',
          r'C:\Users\xilisi\Doubao\chats\2026-09-27\new-chat\baona-app\lib\shop.dart',
          r'C:\Users\xilisi\Doubao\chats\2026-09-27\new-chat\baona-app\lib\stickers.dart',
          r'C:\Users\xilisi\Doubao\chats\2026-09-27\new-chat\baona-app\lib\chatlist.dart']:
    t = io.open(f, encoding='utf-8').read()
    bad = []
    import re
    # CacheImg( 开头但参数里混入 Image 专用参数
    for m in re.finditer(r'CacheImg\([^)]*', t, re.S):
        seg = m.group(0)
        if 'errorBuilder' in seg or 'loadingBuilder' in seg:
            bad.append(seg[:60])
    if bad:
        print(f'{f} 仍有残留: {bad}')
    else:
        print(f'{f} 干净')
