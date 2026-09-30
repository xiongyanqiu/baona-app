# -*- coding: utf-8 -*-
import io

p = r'C:\Users\xilisi\Doubao\chats\2026-09-27\new-chat\baona-app\lib\videolib.dart'
s = io.open(p, encoding='utf-8').read()

old = """  List<VlVideo> get _shown =>
      _cat == '全部' ? _vids : _vids.where((v) => v.cat == _cat).toList();"""
new = """  List<VlVideo> get _shown {
    final base = _cat == '全部'
        ? List.of(_vids)
        : _vids.where((v) => v.cat == _cat).toList();
    // 分类里视频太少（<3）时，用其它分类的视频补到轮播里，
    // 保证左右始终有缩小的其它视频可看（主视频仍是当前分类的）
    if (base.length >= 3 || _vids.length <= base.length) return base;
    final extra = _vids.where((v) => v.cat != _cat).toList();
    return [...base, ...extra];
  }"""
assert old in s, '_shown block'
s = s.replace(old, new)

io.open(p, 'w', encoding='utf-8', newline='').write(s)
print('_shown backfill ok, len=', len(s))
