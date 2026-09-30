# -*- coding: utf-8 -*-
import io

p = r'C:\Users\xilisi\Doubao\chats\2026-09-27\new-chat\baona-app\lib\chat.dart'
s = io.open(p, encoding='utf-8').read()

old = """    final list = ((j['messages'] as List?) ?? []).map((e) => Msg.fromJson(Map.from(e))).toList();
    setState(() {
      _msgs = MsgsLocal.merge(list, _msgs);
      _hasMore = j['hasMore'] == true;
      _loading = false;
    });"""
new = """    final list = ((j?['messages'] as List?) ?? []).map((e) => Msg.fromJson(Map.from(e))).toList();
    setState(() {
      _msgs
        ..clear()
        ..addAll(MsgsLocal.merge(list, _msgs));
      _hasMore = j?['hasMore'] == true;
      _loading = false;
    });"""
assert old in s, 'anchor fail'
s = s.replace(old, new)
io.open(p, 'w', encoding='utf-8', newline='').write(s)
print('chat.dart 编译错误已修复: j?[] 可空 + _msgs 用 clear/addAll(merge)')
