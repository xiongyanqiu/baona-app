# -*- coding: utf-8 -*-
import io

path = r'C:\Users\xilisi\Doubao\chats\2026-09-27\new-chat\baona-app\lib\videolib.dart'
s = io.open(path, encoding='utf-8').read()

# 1) 删 PageController，换成手势累积量
old = """  final _pv = PageController();
  List<VlVideo> _vids = [];"""
new = """  List<VlVideo> _vids = [];
  double _dx = 0; // 横向手势累积"""
assert old in s, 'pc field'
s = s.replace(old, new)

# 2) dispose 删 _pv
old = """  @override
  void dispose() {
    _pv.dispose();
    super.dispose();
  }"""
new = """  @override
  void dispose() {
    super.dispose();
  }"""
assert old in s, 'dispose'
s = s.replace(old, new)

# 3) _addVideo 里删 jumpToPage
old = """    _pv.jumpToPage(_shown.length - 1);
    await _save();"""
new = """    await _save();"""
assert old in s, 'add jump'
s = s.replace(old, new)

# 4) _catChip 里删 jumpToPage
old = """          });
          _pv.jumpToPage(0);
        },"""
new = """          });
        },"""
assert old in s, 'chip jump'
s = s.replace(old, new)

# 5) _buildCoverflow 替换为错位堆叠（主视频居中压上层，两侧缩小露边）
old = """  Widget _buildCoverflow() {
    final list = _shown;
    if (list.isEmpty) return const SizedBox.shrink();
    final cur = _cur.clamp(0, list.length - 1);
    return PageView.builder(
      controller: _pv,
      itemCount: list.length,
      onPageChanged: (i) => setState(() => _cur = i),
      itemBuilder: (c, i) {
        final delta = (i - cur).clamp(-3, 3).toDouble();
        final scale = 1 - delta.abs() * 0.11;
        final angle = delta * 0.32;
        final offset = delta * 46.0;
        return GestureDetector(
          onTap: () => _openPlayer(i),
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0016)
              ..rotateY(angle)
              ..translate(offset)
              ..scale(scale),
            child: _Cover(video: list[i], cur: i == cur),
          ),
        );
      },
    );
  }"""
new = """  Widget _buildCoverflow() {
    final list = _shown;
    if (list.isEmpty) return const SizedBox.shrink();
    final cur = _cur.clamp(0, list.length - 1);
    return LayoutBuilder(builder: (c, cons) {
      final cw = cons.maxWidth;
      final w = cw * 0.60; // 卡片宽度：主视频适中，两侧露出一部分
      final gap = w * 0.40; // 相邻卡片错位间距（露出的边缘宽度）
      final lo = (cur - 2).clamp(0, list.length - 1);
      final hi = (cur + 2).clamp(0, list.length - 1);
      final items = <Widget>[];
      for (var i = lo; i <= hi; i++) {
        final dist = (i - cur).abs();
        final left = (cw - w) / 2 + (i - cur) * gap;
        final scale = dist == 0 ? 1.0 : 0.84 - dist * 0.06;
        final op = dist == 0 ? 1.0 : 0.60 - dist * 0.10;
        final topPad = dist * 20.0; // 两侧轻微下沉，更有层次
        items.add(AnimatedPositioned(
          key: ValueKey('cv$i'),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          left: left,
          top: topPad,
          bottom: topPad,
          width: w,
          child: GestureDetector(
            onTap: () => _openPlayer(i),
            onHorizontalDragUpdate: (d) => _drag(i, d.delta.dx, w),
            child: Transform.scale(
              scale: scale,
              child: Opacity(
                opacity: op,
                child: _Cover(video: list[i], cur: i == cur),
              ),
            ),
          ),
        ));
      }
      // 倒序 = 越靠 cur 的越在上层（主视频压住两侧）
      return Stack(
          clipBehavior: Clip.none, children: items.reversed.toList());
    });
  }

  /// 横向手势：累积位移超过阈值就切到上一张/下一张
  void _drag(int i, double dx, double w) {
    _dx += dx;
    final th = w * 0.26;
    if (_dx > th) {
      _dx = 0;
      if (_cur > 0) setState(() => _cur--);
    } else if (_dx < -th) {
      _dx = 0;
      if (_cur < _shown.length - 1) setState(() => _cur++);
    }
  }"""
assert old in s, 'coverflow'
s = s.replace(old, new)

# 6) _Cover 顶部文件名挪到左下角下方避免与分类chip重叠？保持即可。margin 调小
old = """      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),"""
new = """      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),"""
assert old in s, 'cover margin'
s = s.replace(old, new)

io.open(path, 'w', encoding='utf-8', newline='').write(s)
print('stack coverflow done, len=', len(s))
