# -*- coding: utf-8 -*-
import io

# imgsrv.dart：Image 构造器没有 cacheWidth/cacheHeight，改用 ResizeImage 实现缩略图省内存
p = r'C:\Users\xilisi\Doubao\chats\2026-09-27\new-chat\baona-app\lib\imgsrv.dart'
s = io.open(p, encoding='utf-8').read()

old = """  const CacheImg(this.url,
      {super.key,
      this.width,
      this.height,
      this.fit = BoxFit.cover,
      this.radius,
      this.cacheWidth,
      this.cacheHeight,
      this.headers});

  final String url;
  final double? width, height;
  final BoxFit fit;
  final BorderRadius? radius;
  final int? cacheWidth, cacheHeight;
  final Map<String, String>? headers;"""
new = """  const CacheImg(this.url,
      {super.key,
      this.width,
      this.height,
      this.fit = BoxFit.cover,
      this.radius,
      this.cacheWidth,
      this.headers});

  final String url;
  final double? width, height;
  final BoxFit fit;
  final BorderRadius? radius;
  final int? cacheWidth;
  final Map<String, String>? headers;"""
assert old in s, 'cacheimg field fail'
s = s.replace(old, new)

old2 = """        } else {
          w = Image(
            image: s.data!,
            width: width,
            height: height,
            fit: fit,
            cacheWidth: cacheWidth,
            cacheHeight: cacheHeight,
            errorBuilder: (_, __, ___) => _ph,
          );
        }"""
new2 = """        } else {
          // ★Image 构造器没有 cacheWidth，缩略图用 ResizeImage 省内存
          final ip = cacheWidth != null ? ResizeImage(s.data!, width: cacheWidth) : s.data!;
          w = Image(
            image: ip,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (_, __, ___) => _ph,
          );
        }"""
assert old2 in s, 'cacheimg build fail'
s = s.replace(old2, new2)

io.open(p, 'w', encoding='utf-8', newline='').write(s)
print('imgsrv.dart ResizeImage 修复完成')
