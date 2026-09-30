# -*- coding: utf-8 -*-
import io

p = r'C:\Users\xilisi\Doubao\chats\2026-09-27\new-chat\baona-app\lib\chatlist.dart'
s = io.open(p, encoding='utf-8').read()

# import imgsrv
old_imp = "import 'msglocal.dart';"
new_imp = "import 'msglocal.dart';\nimport 'imgsrv.dart';"
assert old_imp in s, 'chatlist import fail'
s = s.replace(old_imp, new_imp)

old = """            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(colors: [kAccent, kAccent2]),
                image: avatarOf(av) == null ? null : DecorationImage(image: avatarOf(av)!, fit: BoxFit.cover),
              ),
              child: av.isEmpty ? const Center(child: Text('娜', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600))) : null,
            ),"""
new = """            av.isEmpty
                ? Container(
                    width: 52,
                    height: 52,
                    decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [kAccent, kAccent2])),
                    child: const Center(child: Text('娜', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600))),
                  )
                : FutureBuilder<ImageProvider>(
                    // ★b21 头像磁盘缓存：列表频繁重建不再反复下载
                    future: ImgCache.provider(av),
                    builder: (c, s) => Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(colors: [kAccent, kAccent2]),
                        image: s.data == null ? null : DecorationImage(image: s.data!, fit: BoxFit.cover),
                      ),
                    ),
                  ),"""
assert old in s, 'chatlist avatar fail'
s = s.replace(old, new)
io.open(p, 'w', encoding='utf-8', newline='').write(s)
print('chatlist.dart 头像缓存完成')
