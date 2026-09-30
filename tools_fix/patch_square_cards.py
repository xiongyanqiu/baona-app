# -*- coding: utf-8 -*-
import io

p = r'C:\Users\xilisi\Doubao\chats\2026-09-27\new-chat\baona-app\lib\videolib.dart'
s = io.open(p, encoding='utf-8').read()

old = """      final cw = cons.maxWidth;
      final w = cw * 0.52; // 卡片宽度：主视频适中，两侧完整可见的缩小视频
      final gap = w * 0.60; // 中心距：左右视频大部分可见，只被主视频压住一部分"""
new = """      final cw = cons.maxWidth;
      final ch = cons.maxHeight;
      final w = cw * 0.52; // 卡片宽度：主视频适中，两侧完整可见的缩小视频
      final h = w; // 正方形卡片（不再撑满高度）
      final topBase = (ch - h) / 2; // 垂直居中
      final gap = w * 0.60; // 中心距：左右视频大部分可见，只被主视频压住一部分"""
assert old in s, 'params'
s = s.replace(old, new)

old = """        final left = (cw - w) / 2 + (i - cur) * gap;
        final scale = dist == 0 ? 1.0 : 0.88 - dist * 0.12; // 左右视频缩小但完整可见
        final op = dist == 0 ? 1.0 : 0.90 - dist * 0.13; // 清晰可见，越远越淡
        final topPad = dist * 14.0; // 两侧轻微下沉，更有层次
        items.add(AnimatedPositioned(
          key: ValueKey('cv$i'),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          left: left,
          top: topPad,
          bottom: topPad,
          width: w,"""
new = """        final left = (cw - w) / 2 + (i - cur) * gap;
        final scale = dist == 0 ? 1.0 : 0.88 - dist * 0.12; // 左右视频缩小但完整可见
        final op = dist == 0 ? 1.0 : 0.90 - dist * 0.13; // 清晰可见，越远越淡
        final topPad = dist * 16.0; // 两侧轻微下沉，更有层次
        items.add(AnimatedPositioned(
          key: ValueKey('cv$i'),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          left: left,
          top: topBase + topPad,
          height: h,
          width: w,"""
assert old in s, 'positioned'
s = s.replace(old, new)

io.open(p, 'w', encoding='utf-8', newline='').write(s)
print('square cards done, len=', len(s))
