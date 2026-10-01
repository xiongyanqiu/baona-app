# -*- coding: utf-8 -*-
import io

p = r'C:\Users\xilisi\Doubao\chats\2026-09-27\new-chat\baona-app\lib\videolib.dart'
s = io.open(p, encoding='utf-8').read()

# 1) 类加 mixin（AnimationController 需要 vsync）
old = """class _VideoLibPageState extends State<VideoLibPage> {"""
new = """class _VideoLibPageState extends State<VideoLibPage>
    with SingleTickerProviderStateMixin {"""
assert old in s, 'class'
s = s.replace(old, new)

# 2) 字段：PageController 换成跟手/惯性动画状态
old = """  final _pv = PageController();
  List<VlVideo> _vids = [];"""
new = """  AnimationController? _anim; // 松手惯性动画
  double _dragOff = 0; // 跟手偏移（拖动时整列跟随手指）
  double _cardW = 1; // 卡片宽（build 时更新，手势判定用）
  double _cardGap = 1; // 卡片中心距
  List<VlVideo> _vids = [];"""
assert old in s, 'fields'
s = s.replace(old, new)

# 3) dispose
old = """  @override
  void dispose() {
    _pv.dispose();
    super.dispose();
  }"""
new = """  @override
  void dispose() {
    _anim?.dispose();
    super.dispose();
  }"""
assert old in s, 'dispose'
s = s.replace(old, new)

# 4) _buildCoverflow：堆叠 + 旋转透视 + 跟手 + 惯性急停（静止即主大+左右完整缩小被压）
old = """  Widget _buildCoverflow() {
    final list = _shown;
    if (list.isEmpty) return const SizedBox.shrink();
    final cur = _cur.clamp(0, list.length - 1);
    // 标准 CoverFlow：PageView(系统惯性急停) + 透视旋转 + 缩放
    return LayoutBuilder(builder: (c, cons) {
      final cw = cons.maxWidth;
      final ch = cons.maxHeight;
      final w = cw * 0.56; // 卡片宽（正方形）
      final itemW = cw * 0.62; // 每页可视宽度（两侧露出）
      return PageView.builder(
        controller: _pv,
        itemCount: list.length,
        onPageChanged: (i) => setState(() => _cur = i),
        itemBuilder: (c, i) {
          final delta = (i - cur).clamp(-1.5, 1.5).toDouble();
          final scale = 1 - delta.abs() * 0.14;
          final angle = delta * 0.52;
          final sink = delta.abs() * 20.0; // 两侧轻微下沉
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0016) // 透视
              ..rotateY(angle)
              ..scale(scale)
              ..translate(0.0, sink, 0.0),
            child: Center(
              child: GestureDetector(
                onTap: () => _openPlayer(i),
                child: SizedBox(
                  width: w,
                  height: w,
                  child: _Cover(video: list[i], cur: i == cur),
                ),
              ),
            ),
          );
        },
      );
    });
  }"""
new = """  Widget _buildCoverflow() {
    final list = _shown;
    if (list.isEmpty) return const SizedBox.shrink();
    final cur = _cur.clamp(0, list.length - 1);
    return LayoutBuilder(builder: (c, cons) {
      final cw = cons.maxWidth;
      final ch = cons.maxHeight;
      final w = cw * 0.56; // 正方形卡片：主视频居中偏大
      final h = w;
      final topBase = (ch - h) / 2; // 垂直居中
      final gap = w * 0.60; // 中心距：左右视频完整可见，内侧被主视频压住一部分
      _cardW = w;
      _cardGap = gap;
      final lo = (cur - 2).clamp(0, list.length - 1);
      final hi = (cur + 2).clamp(0, list.length - 1);
      final items = <Widget>[];
      for (var i = lo; i <= hi; i++) {
        final dist = (i - cur).abs();
        final sign = i < cur ? 1.0 : -1.0; // 左侧朝右旋、右侧朝左旋
        final left = (cw - w) / 2 + (i - cur) * gap;
        final scale = dist == 0 ? 1.0 : 0.86 - dist * 0.14; // 两侧缩小但完整可见
        final op = dist == 0 ? 1.0 : 0.92 - dist * 0.10;
        final sink = dist * 16.0; // 两侧轻微下沉
        items.add(Positioned(
          key: ValueKey('cv$i'),
          left: left,
          top: topBase + sink,
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
            // 整列跟手平移 + 旋转透视（越远越侧）
            child: Transform.translate(
              offset: Offset(_dragOff, 0),
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0016)
                  ..rotateY(sign * dist * 0.42)
                  ..scale(scale),
                child: Opacity(
                  opacity: op,
                  child: _Cover(video: list[i], cur: i == cur),
                ),
              ),
            ),
          ),
        ));
      }
      // 倒序 = 越靠 cur 的越在上层（主视频压住两侧内侧）
      return Stack(
          clipBehavior: Clip.none, children: items.reversed.toList());
    });
  }

  /// 松手惯性急停：跟手位置 + 甩动速度判定 → 动画滑到相邻位
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
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
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
print('coverflow stack + rotate + drag settle done, len=', len(s))
