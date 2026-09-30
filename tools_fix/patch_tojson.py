# -*- coding: utf-8 -*-
import io

# ============ 1. api.dart：Msg 加 toJson（缓存序列化用） ============
p = r'C:\Users\xilisi\Doubao\chats\2026-09-27\new-chat\baona-app\lib\api.dart'
s = io.open(p, encoding='utf-8').read()

old = """  /// 给别的文件用（下划线是文件私有，外面看不到）
  static int? toInt(dynamic v) => _i(v);
}"""
new = """  /// 给别的文件用（下划线是文件私有，外面看不到）
  static int? toInt(dynamic v) => _i(v);

  /// ★2026-09-30 本地缓存：序列化整条消息（断网也能看历史）
  Map<String, dynamic> toJson() => {
        'role': role,
        'content': content,
        if (sticker != null) 'sticker': sticker,
        if (voice != null) 'voice': voice,
        if (idx != null) 'idx': idx,
        if (time != null) 'time': time,
        'st': st,
        if (cid != null) 'cid': cid,
      };
}"""
assert old in s, 'toJson anchor fail'
s = s.replace(old, new)
io.open(p, 'w', encoding='utf-8', newline='').write(s)
print('api.dart Msg.toJson 已加')
