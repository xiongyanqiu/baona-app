# -*- coding: utf-8 -*-
import io

p = r'C:\Users\xilisi\Doubao\chats\2026-09-27\new-chat\baona-app\lib\videolib.dart'
s = io.open(p, encoding='utf-8').read()

# 1) 类加 SingleTickerProviderStateMixin
old = """class _VideoLibPageState extends State<VideoLibPage> {"""
new = """class _VideoLibPageState extends State<VideoLibPage>
    with SingleTickerProviderStateMixin {"""
assert old in s, 'class'
s = s.replace(old, new)

# 2) 字段
old = """  List<VlVideo> _vids = [];
  double _dx = 0; // 横向手势累积"""
new = """  List<VlVideo> _vids = [];
  AnimationController? _anim; // 急停动画
  double _dragOff = 0; // 跟手偏移（拖动时整列跟随手指）
  double _cardW = 1; // 当前卡片宽（build 时更新，手势用）
  double _cardGap = 1; // 当前卡片中心距"""
assert old in s, 'fields'
s = s.replace(old, new)

# 3) dispose
old = """  @override
  void dispose() {
    super.dispose();
  }"""
new = """  @override
  void dispose() {
    _anim?.dispose();
    super.dispose();
  }"""
assert old in s, 'dispose'
s = s.replace(old, new)

# 4) w 放大
old = """      final w = cw * 0.52; // 卡片宽度：主视频适中，两侧完整可见的缩小视频"""
new = """      final w = cw * 0.56; // 卡片宽度：主视频适中偏大，两侧完整可见的缩小视频"""
assert old in s, 'w'
s = s.replace(old, new)

# 5) _buildCoverflow 重写：Positioned + 跟手 translate + 手势
old = """  Widget _buildCoverflow() {
    final list = _shown;
    if (list.isEmpty) return const SizedBox.shrink();
    final cur = _cur.clamp(0, list.length - 1);
    return LayoutBuilder(builder: (c, cons) {
      final cw = cons.maxWidth;
      final ch = cons.maxHeight;
      final w = cw * 0.56; // 卡片宽度：主视频适中偏大，两侧完整可见的缩小视频
      final h = w; // 正方形卡片（不再撑满高度）
      final topBase = (ch - h) / 2; // 垂直居中
      final gap = w * 0.60; // 中心距：左右视频大部分可见，只被主视频压住一部分
      final lo = (cur - 2).clamp(0, list.length - 1);
      final hi = (cur + 2).clamp(0, list.length - 1);
      final items = <Widget>[];
      for (var i = lo; i <= hi; i++) {
        final dist = (i - cur).abs();
        final left = (cw - w) / 2 + (i - cur) * gap;
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
new = """  Widget _buildCoverflow() {
    final list = _shown;
    if (list.isEmpty) return const SizedBox.shrink();
    final cur = _cur.clamp(0, list.length - 1);
    return LayoutBuilder(builder: (c, cons) {
      final cw = cons.maxWidth;
      final ch = cons.maxHeight;
      final w = cw * 0.56; // 卡片宽度：主视频适中偏大，两侧完整可见的缩小视频
      final h = w; // 正方形卡片（不再撑满高度）
      final topBase = (ch - h) / 2; // 垂直居中
      final gap = w * 0.60; // 中心距：左右视频大部分可见，只被主视频压住一部分
      _cardW = w;
      _cardGap = gap;
      final lo = (cur - 2).clamp(0, list.length - 1);
      final hi = (cur + 2).clamp(0, list.length - 1);
      final items = <Widget>[];
      for (var i = lo; i <= hi; i++) {
        final dist = (i - cur).abs();
        final left = (cw - w) / 2 + (i - cur) * gap;
        final scale = dist == 0 ? 1.0 : 0.88 - dist * 0.12; // 左右视频缩小但完整可见
        final op = dist == 0 ? 1.0 : 0.90 - dist * 0.13; // 清晰可见，越远越淡
        final topPad = dist * 16.0; // 两侧轻微下沉，更有层次
        items.add(Positioned(
          key: ValueKey('cv$i'),
          left: left,
          top: topBase + topPad,
          height: h,
          width: w,
          child: GestureDetector(
            onTap: () => _openPlayer(i),
            onHorizontalDragStart: (_) {
              _anim?.dispose();
              _anim = null;
            },
            onHorizontalDragUpdate: (d) {
              setState(() => _dragOff += d.delta.dx);
            },
            onHorizontalDragEnd: (d) =>
                _settle(d.velocity.pixelsPerSecond.dx),
            onHorizontalDragCancel: () => _settle(0),
            child: Transform.translate(
              offset: Offset(_dragOff, 0),
              child: Transform.scale(
                scale: scale,
                child: Opacity(
                  opacity: op,
                  child: _Cover(video: list[i], cur: i == cur),
                ),
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

  /// 松手急停：跟手位置 + 速度判定 → 惯性动画滑到目标位
  void _settle(double vel) {
    final list = _shown;
    final th = _cardW * 0.22;
    var target = _cur;
    if (_dragOff > th || vel > 900) {
      if (_cur > 0) target = _cur - 1; // 向右滑 → 上一张
    } else if (_dragOff < -th || vel < -900) {
      if (_cur < list.length - 1) target = _cur + 1; // 向左滑 → 下一张
    }
    final from = _dragOff;
    final to = target == _cur
        ? 0.0
        : (target < _cur ? _cardGap : -_cardGap); // 滑到相邻位
    _anim?.dispose();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    final t = Tween<double>(begin: from, end: to);
    _anim!.addListener(() {
      if (!mounted) return;
      setState(() => _dragOff = t.transform(_anim!.value));
    });
    _anim!.forward().whenComplete(() {
      if (!mounted) return;
      setState(() {
        _cur = target;
        _dragOff = 0;
      });
    });
  }"""
assert old in s, 'coverflow build'
s = s.replace(old, new)

io.open(p, 'w', encoding='utf-8', newline='').write(s)
print('inertial snap + bigger cards done, len=', len(s))
