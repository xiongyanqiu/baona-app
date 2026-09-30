# -*- coding: utf-8 -*-
import io

# ---- 1) chatlist.dart：补字段声明 + 头像分支读本地 ----
path_cl = r'C:\Users\xilisi\Doubao\chats\2026-09-27\new-chat\baona-app\lib\chatlist.dart'
s = io.open(path_cl, encoding='utf-8').read()

# 字段声明
old_f = """  bool _loaded = false;
  String _last = '';
  int _lastT = 0;"""
new_f = """  bool _loaded = false;
  String _last = '';
  int _lastT = 0;
  late Future<String> _vlAvatarFuture = Future.value('');"""
assert old_f in s, 'fields not found'
s = s.replace(old_f, new_f)

# 头像分支（当前是默认紫底，替换成读本地头像）
old_av = """            else if (id == 'videolib')
              // 视频库头像：深紫底 + 播放三角
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [Color(0xFF7B2FFF), Color(0xFF2F6BFF)])),
                child: const Center(child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 26)),
              )"""
new_av = """            else if (id == 'videolib')
              // 视频库头像：本地设置的头像（dataURL）或默认紫底播放三角
              FutureBuilder<String>(
                future: _vlAvatarFuture,
                builder: (c, s) {
                  final av = s.data ?? '';
                  if (av.startsWith('data:image/')) {
                    try {
                      final b64 = av.substring(av.indexOf(',') + 1);
                      return Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          image: DecorationImage(
                              image: MemoryImage(base64Decode(b64)),
                              fit: BoxFit.cover),
                        ),
                      );
                    } catch (_) {}
                  }
                  return Container(
                    width: 52,
                    height: 52,
                    decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [Color(0xFF7B2FFF), Color(0xFF2F6BFF)])),
                    child: const Center(child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 26)),
                  );
                },
              )"""
assert old_av in s, 'avatar block not found'
s = s.replace(old_av, new_av)

# 确认 base64Decode 需要 dart:convert（chatlist 已有 jsonDecode → 已有 import）
if "import 'dart:convert';" not in s:
    old_i = "import 'package:flutter/material.dart';"
    new_i = "import 'dart:convert';\n\nimport 'package:flutter/material.dart';"
    assert old_i in s, 'material import not found'
    s = s.replace(old_i, new_i)

io.open(path_cl, 'w', encoding='utf-8', newline='').write(s)
print('chatlist fixed, len=', len(s))

# ---- 2) videolib.dart：修 deleteSync 参数 ----
path_vl = r'C:\Users\xilisi\Doubao\chats\2026-09-27\new-chat\baona-app\lib\videolib.dart'
v = io.open(path_vl, encoding='utf-8').read()
old_d = """      // 取消分类 = 不入库，删掉复制的文件
      File(target).deleteSync(ignoreMissing: true);"""
new_d = """      // 取消分类 = 不入库，删掉复制的文件
      try {
        File(target).deleteSync();
      } catch (_) {}"""
assert old_d in v, 'deleteSync block not found'
v = v.replace(old_d, new_d)
io.open(path_vl, 'w', encoding='utf-8', newline='').write(v)
print('videolib fixed, len=', len(v))
