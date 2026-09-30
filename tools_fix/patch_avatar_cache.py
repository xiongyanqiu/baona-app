# -*- coding: utf-8 -*-
import io

p = r'C:\Users\xilisi\Doubao\chats\2026-09-27\new-chat\baona-app\lib\theme.dart'
s = io.open(p, encoding='utf-8').read()

old = """/// 头像/背景可能是两种东西：https 地址，或者手机上传后的 data:image/...（电脑端存的就是 dataURL）
/// ★iOS 上 NetworkImage 读 data URL 会直接报错 → 必须走 MemoryImage，头像才显示得出来
ImageProvider? avatarOf(String s) {
  if (s.isEmpty) return null;
  if (s.startsWith('data:')) {
    final i = s.indexOf(',');
    try {
      return MemoryImage(base64Decode(i >= 0 ? s.substring(i + 1) : s));
    } catch (_) {
      return null;
    }
  }
  return NetworkImage(s);
}"""
new = """/// 头像/背景可能是两种东西：https 地址，或者手机上传后的 data:image/...（电脑端存的就是 dataURL）
/// ★iOS 上 NetworkImage 读 data URL 会直接报错 → 必须走 MemoryImage，头像才显示得出来
/// ★★2026-09-30：加 provider 缓存 —— 同一个 URL 永远返回同一个 ImageProvider，
///   否则每次 rebuild 都会新建 provider → 图片重新解码 → 头像闪回"娜"字占位
final Map<String, ImageProvider> _avCache = {};
ImageProvider? avatarOf(String s) {
  if (s.isEmpty) return null;
  final hit = _avCache[s];
  if (hit != null) return hit;
  ImageProvider? p;
  if (s.startsWith('data:')) {
    final i = s.indexOf(',');
    try {
      p = MemoryImage(base64Decode(i >= 0 ? s.substring(i + 1) : s));
    } catch (_) {
      return null;
    }
  } else {
    p = NetworkImage(s);
  }
  _avCache[s] = p;
  return p;
}"""
assert old in s, 'avatarOf fail'
s = s.replace(old, new)
io.open(p, 'w', encoding='utf-8', newline='').write(s)
print('avatarOf provider 缓存完成')
