# -*- coding: utf-8 -*-
import io

p = r'C:\Users\xilisi\Doubao\chats\2026-09-27\new-chat\baona-app\lib\videolib.dart'
s = io.open(p, encoding='utf-8').read()

# 1) 类：去掉 SingleTickerProviderStateMixin（不再用手写动画控制器）
old = """class _VideoLibPageState extends State<VideoLibPage>
    with SingleTickerProviderStateMixin {"""
new = """class _VideoLibPageState extends State<VideoLibPage> {"""
assert old in s, 'class'
s = s.replace(old, new)

# 2) 字段：手势状态换成 PageController + 头像字节缓存
old = """  List<VlVideo> _vids = [];
  AnimationController? _anim; // 急停动画
  double _dragOff = 0; // 跟手偏移（拖动时整列跟随手指）
  double _cardW = 1; // 当前卡片宽（build 时更新，手势用）
  double _cardGap = 1; // 当前卡片中心距"""
new = """  final _pv = PageController();
  List<VlVideo> _vids = [];
  Uint8List? _avatarBytes; // 头像解码缓存（防滑动重建闪烁）"""
assert old in s, 'fields'
s = s.replace(old, new)

# 3) dispose
old = """  @override
  void dispose() {
    _anim?.dispose();
    super.dispose();
  }"""
new = """  @override
  void dispose() {
    _pv.dispose();
    super.dispose();
  }"""
assert old in s, 'dispose'
s = s.replace(old, new)

# 4) _load：解码头像字节缓存
old = """    _avatar = sp.getString(_avKey) ?? '';
    if (mounted) setState(() => _loaded = true);"""
new = """    _avatar = sp.getString(_avKey) ?? '';
    _avatarBytes = _decodeAvatar(_avatar);
    if (mounted) setState(() => _loaded = true);"""
assert old in s, 'load avatar'
s = s.replace(old, new)

# 5) _pickAvatar：解码缓存
old = """    final sp = await SharedPreferences.getInstance();
    await sp.setString(_avKey, dataUrl);
    if (mounted) setState(() => _avatar = dataUrl);"""
new = """    final sp = await SharedPreferences.getInstance();
    await sp.setString(_avKey, dataUrl);
    if (mounted) {
      setState(() {
        _avatar = dataUrl;
        _avatarBytes = _decodeAvatar(dataUrl);
      });
    }"""
assert old in s, 'pick avatar'
s = s.replace(old, new)

# 6) _avatarCircle：用缓存字节（不再每次 build 都 base64 解码）
old = """  Widget _avatarCircle(double size) {
    final av = _avatar;
    if (av.startsWith('data:image/')) {
      try {
        final b64 = av.substring(av.indexOf(',') + 1);
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white24),
            image: DecorationImage(
              image: MemoryImage(base64Decode(b64)),
              fit: BoxFit.cover,
            ),
          ),
        );
      } catch (_) {}
    }"""
new = """  Uint8List? _decodeAvatar(String av) {
    if (av.startsWith('data:image/')) {
      try {
        return base64Decode(av.substring(av.indexOf(',') + 1));
      } catch (_) {}
    }
    return null;
  }

  Widget _avatarCircle(double size) {
    final bytes = _avatarBytes;
    if (bytes != null && bytes.isNotEmpty) {
      return RepaintBoundary(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white24),
            image: DecorationImage(
              image: MemoryImage(bytes),
              fit: BoxFit.cover,
            ),
          ),
        ),
      );
    }"""
assert old in s, 'avatar circle'
s = s.replace(old, new)

# 7) _buildCoverflow：标准 CoverFlow（PageView + 旋转透视，系统惯性急停）
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
new = """  Widget _buildCoverflow() {
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
assert old in s, 'coverflow build'
s = s.replace(old, new)

io.open(p, 'w', encoding='utf-8', newline='').write(s)
print('standard coverflow + avatar cache done, len=', len(s))

# 8) 版本：26.2.1（取消 b 系列）
p1 = r'C:\Users\xilisi\Doubao\chats\2026-09-27\new-chat\baona-app\lib\theme.dart'
s1 = io.open(p1, encoding='utf-8').read()
s1 = s1.replace("const String kAppVer = '26.2.50';", "const String kAppVer = '26.2.1';")
io.open(p1, 'w', encoding='utf-8', newline='').write(s1)

p2 = r'C:\Users\xilisi\Doubao\chats\2026-09-27\new-chat\baona-app\pubspec.yaml'
s2 = io.open(p2, encoding='utf-8').read()
s2 = s2.replace("version: 26.2.0+50", "version: 26.2.1+51")
io.open(p2, 'w', encoding='utf-8', newline='').write(s2)
print('version -> 26.2.1 (build 51)')
