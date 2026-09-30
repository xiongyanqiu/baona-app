// 包娜 · 视频库（独立入口，v26.2）
// 方案A：3D CoverFlow 旋转轮播 —— 当前封面立起居中，两侧倾斜缩小后退
// - 视频存在手机本地（App 文档目录），不传电脑
// - 点击封面 → 全屏播放该视频
// - 分类：自定义（默认 日常/老婆的/收藏/其他，可增删改）
// - 封面：真实视频第一帧缩略图（video_thumbnail），无缩略图时回退渐变卡片
// - 右上角头像设置入口：相册选图存本地，对话列表头像同步
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

/// 一个视频条目
class VlVideo {
  final String path;
  String cat;
  final int added;
  String thumb; // 缩略图本地路径（可为空）
  VlVideo(
      {required this.path,
      required this.cat,
      required this.added,
      this.thumb = ''});

  Map<String, dynamic> toJson() =>
      {'path': path, 'cat': cat, 'added': added, 'thumb': thumb};

  factory VlVideo.fromJson(Map<String, dynamic> j) => VlVideo(
        path: j['path'] ?? '',
        cat: j['cat'] ?? '其他',
        added: (j['added'] as num?)?.toInt() ?? 0,
        thumb: j['thumb'] ?? '',
      );
}

/// 封面回退渐变色（按分类）
const Map<String, List<Color>> _catGrad = {
  '日常': [Color(0xFF2F6BFF), Color(0xFF5B3DFF)],
  '老婆的': [Color(0xFFFF3B5C), Color(0xFFFF7A3B)],
  '收藏': [Color(0xFF00C2A8), Color(0xFF2F8BFF)],
  '其他': [Color(0xFF7B2FFF), Color(0xFF2F6BFF)],
};

class VideoLibPage extends StatefulWidget {
  const VideoLibPage({super.key});
  @override
  State<VideoLibPage> createState() => _VideoLibPageState();
}

class _VideoLibPageState extends State<VideoLibPage> {
  List<VlVideo> _vids = [];
  double _dx = 0; // 横向手势累积
  List<String> _cats = ['日常', '老婆的', '收藏', '其他'];
  String _cat = '全部';
  int _cur = 0;
  bool _loaded = false;
  String _avatar = '';

  static const _dbKey = 'vl.db';
  static const _avKey = 'vl.avatar';
  static const _catsKey = 'vl.cats';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _load() async {
    final sp = await SharedPreferences.getInstance();
    // 自定义分类
    final cj = sp.getString(_catsKey);
    if (cj != null) {
      try {
        final l = jsonDecode(cj) as List;
        final c = l.cast<String>().toList();
        if (c.isNotEmpty) _cats = c;
      } catch (_) {}
    }
    // 视频
    final db = sp.getString(_dbKey) ?? '[]';
    try {
      final list = (jsonDecode(db) as List).cast<Map<String, dynamic>>();
      _vids = list
          .map(VlVideo.fromJson)
          .where((v) => File(v.path).existsSync())
          .toList();
    } catch (_) {
      _vids = [];
    }
    _avatar = sp.getString(_avKey) ?? '';
    if (mounted) setState(() => _loaded = true);
    // 旧视频回填缩略图（后台）
    _backfillThumbs();
  }

  Future<void> _save() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(
        _dbKey, jsonEncode(_vids.map((v) => v.toJson()).toList()));
  }

  Future<void> _saveCats() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_catsKey, jsonEncode(_cats));
  }

  List<VlVideo> get _shown =>
      _cat == '全部' ? _vids : _vids.where((v) => v.cat == _cat).toList();

  /// 生成视频第一帧缩略图（存 App 文档目录 vl/thumbs/）
  Future<void> _genThumb(VlVideo v) async {
    try {
      final bytes = await VideoThumbnail.thumbnailData(
        video: v.path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 640,
        quality: 82,
        timeMs: 100,
      );
      if (bytes == null || bytes.isEmpty) return;
      final dir = await getApplicationDocumentsDirectory();
      final td = Directory('${dir.path}/vl/thumbs');
      if (!td.existsSync()) td.createSync(recursive: true);
      final f = File('${td.path}/${v.added}.jpg');
      await f.writeAsBytes(bytes);
      if (!mounted) return;
      setState(() {
        final idx = _vids.indexWhere((x) => x.path == v.path);
        if (idx >= 0) {
          _vids[idx] = VlVideo(
              path: v.path, cat: v.cat, added: v.added, thumb: f.path);
        }
      });
      await _save();
    } catch (_) {}
  }

  Future<void> _backfillThumbs() async {
    for (final v in _vids) {
      if (v.thumb.isEmpty || !File(v.thumb).existsSync()) {
        await _genThumb(v);
      }
    }
  }

  /// 从相册选视频 → 复制进 App 文档目录 → 选分类入库 → 生成缩略图
  Future<void> _addVideo() async {
    final f = await ImagePicker().pickVideo(
        source: ImageSource.gallery, maxDuration: const Duration(minutes: 30));
    if (f == null) return;
    final dir = await getApplicationDocumentsDirectory();
    final vlDir = Directory('${dir.path}/vl');
    if (!vlDir.existsSync()) vlDir.createSync(recursive: true);
    final ts = DateTime.now().millisecondsSinceEpoch;
    final ext =
        f.path.contains('.') ? f.path.split('.').last.toLowerCase() : 'mp4';
    final target = '${vlDir.path}/${ts}_vl.$ext';
    await File(f.path).copy(target);
    if (!mounted) return;
    final cat = await _pickCat();
    if (cat == null) {
      try {
        File(target).deleteSync();
      } catch (_) {}
      return;
    }
    setState(() {
      _vids.add(VlVideo(path: target, cat: cat, added: ts));
      if (_cat != '全部' && _cat != cat) _cat = cat;
      _cur = _vids.length - 1;
    });
    await _save();
    await _genThumb(_vids.last);
  }

  Future<String?> _pickCat() {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF17181C),
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Padding(
            padding: EdgeInsets.all(14),
            child: Text('放到哪个分类？',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
          ),
          for (final cat in _cats)
            ListTile(
              title: Text(cat, style: const TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(c, cat),
            ),
        ]),
      ),
    );
  }

  /// 换头像：相册选图 → dataURL 存本地
  Future<void> _pickAvatar() async {
    final f = await ImagePicker().pickImage(
        source: ImageSource.gallery, maxWidth: 512, imageQuality: 80);
    if (f == null) return;
    final bytes = await f.readAsBytes();
    final dataUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}';
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_avKey, dataUrl);
    if (mounted) setState(() => _avatar = dataUrl);
  }

  void _openPlayer(int index) {
    final list = _shown;
    if (index < 0 || index >= list.length) return;
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => _FullPlayer(
              video: list[index],
              catGrad: _catGrad[list[index].cat] ?? _catGrad['其他']!,
            )));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: Stack(children: [
        // 背景氛围光（跟随当前分类渐变色）
        AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -0.4),
              radius: 1.1,
              colors: [
                (_catGrad[_cat == '全部' ? '收藏' : _cat] ?? _catGrad['其他']!)
                    .last
                    .withOpacity(0.28),
                const Color(0xFF050505),
              ],
            ),
          ),
        ),
        Column(children: [
          // 顶栏：返回 + 标题 + 管理分类 + 头像设置入口
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 6, 10, 0),
              child: Row(children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 20),
                ),
                const Text('视频库',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
                const Spacer(),
                // 管理分类
                IconButton(
                  onPressed: _manageCats,
                  icon: const Icon(Icons.layers_rounded,
                      color: Colors.white70, size: 21),
                ),
                // 头像设置入口
                GestureDetector(
                  onTap: _pickAvatar,
                  child: Stack(clipBehavior: Clip.none, children: [
                    _avatarCircle(30),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF2F6BFF),
                        ),
                        child: const Icon(Icons.photo_camera_rounded,
                            color: Colors.white, size: 11),
                      ),
                    ),
                  ]),
                ),
              ]),
            ),
          ),
          // 分类横排
          SizedBox(
            height: 46,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final cat in ['全部', ..._cats]) _catChip(cat),
              ],
            ),
          ),
          // 3D CoverFlow 主体
          Expanded(child: _buildCoverflow()),
        ]),
        // 空态引导
        if (_loaded && _vids.isEmpty)
          Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.video_library_rounded,
                  color: Colors.white24, size: 60),
              const SizedBox(height: 14),
              const Text('还没有视频',
                  style: TextStyle(color: Colors.white70, fontSize: 15)),
              const SizedBox(height: 6),
              const Text('点右下角 + 从相册添加',
                  style: TextStyle(color: Colors.white38, fontSize: 12.5)),
            ]),
          ),
        // 添加视频
        Positioned(
          right: 20,
          bottom: 28,
          child: FloatingActionButton(
            onPressed: _addVideo,
            backgroundColor: const Color(0xFF2F6BFF),
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
          ),
        ),
      ]),
    );
  }

  /// 分类管理：增 / 删 / 重命名（StatefulBuilder 弹窗）
  Future<void> _manageCats() async {
    final tc = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF17181C),
      builder: (c) => StatefulBuilder(
        builder: (c, setSt) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(c).viewInsets.bottom),
          child: SafeArea(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 14, 16, 6),
                child: Text('管理分类',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
              ),
              for (final cat in _cats)
                ListTile(
                  dense: true,
                  title: Text(cat,
                      style: const TextStyle(color: Colors.white)),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                      icon: const Icon(Icons.edit_rounded,
                          color: Colors.white54, size: 18),
                      onPressed: () => _renameCat(c, setSt, cat),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded,
                          color: Colors.white54, size: 18),
                      onPressed: () => _delCat(c, setSt, cat),
                    ),
                  ]),
                ),
              const Divider(color: Colors.white12, height: 4),
              // 添加分类
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
                child: Row(children: [
                  Expanded(
                    child: TextField(
                      controller: tc,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: '新分类名',
                        hintStyle:
                            TextStyle(color: Colors.white38, fontSize: 14),
                        isDense: true,
                        enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white24)),
                        focusedBorder: UnderlineInputBorder(
                            borderSide:
                                BorderSide(color: Color(0xFF2F6BFF))),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    onPressed: () {
                      final name = tc.text.trim();
                      if (name.isEmpty) return;
                      if (_cats.contains(name)) return;
                      setSt(() => _cats.add(name));
                      _saveCats();
                      tc.clear();
                    },
                    icon: const Icon(Icons.add_circle_rounded,
                        color: Color(0xFF2F6BFF), size: 26),
                  ),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  void _renameCat(BuildContext c, StateSetter setSt, String old) {
    final tc2 = TextEditingController(text: old);
    showDialog(
      context: c,
      builder: (d) => AlertDialog(
        backgroundColor: const Color(0xFF20212A),
        title: const Text('重命名分类',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        content: TextField(
          controller: tc2,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(hintText: '新分类名',
              hintStyle: TextStyle(color: Colors.white38)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d),
            child: const Text('取消',
                style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              final name = tc2.text.trim();
              if (name.isNotEmpty && !_cats.contains(name)) {
                final i = _cats.indexOf(old);
                if (i >= 0) {
                  setSt(() => _cats[i] = name);
                  for (final v in _vids) {
                    if (v.cat == old) v.cat = name;
                  }
                  _saveCats();
                  _save();
                  if (_cat == old) _cat = name;
                }
              }
              Navigator.pop(d);
            },
            child: const Text('保存',
                style: TextStyle(color: Color(0xFF2F6BFF))),
          ),
        ],
      ),
    );
  }

  void _delCat(BuildContext c, StateSetter setSt, String cat) {
    if (_cats.length <= 1) {
      ScaffoldMessenger.of(c).showSnackBar(const SnackBar(
          content: Text('至少保留一个分类'), duration: Duration(seconds: 1)));
      return;
    }
    showDialog(
      context: c,
      builder: (d) => AlertDialog(
        backgroundColor: const Color(0xFF20212A),
        title: Text('删除分类「$cat」？',
            style: const TextStyle(color: Colors.white, fontSize: 16)),
        content: const Text('该分类下的视频会移到「其他」',
            style: TextStyle(color: Colors.white70, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d),
            child: const Text('取消',
                style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              setSt(() {
                _cats.remove(cat);
                if (!_cats.contains('其他')) _cats.add('其他');
                for (final v in _vids) {
                  if (v.cat == cat) v.cat = '其他';
                }
              });
              _saveCats();
              _save();
              if (_cat == cat) _cat = '全部';
              Navigator.pop(d);
            },
            child: const Text('删除',
                style: TextStyle(color: Color(0xFFFF3B5C))),
          ),
        ],
      ),
    );
  }

  Widget _catChip(String cat) {
    final sel = cat == _cat;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _cat = cat;
            _cur = 0;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 7),
          decoration: BoxDecoration(
            color: sel ? const Color(0xFF2F6BFF) : Colors.white10,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(cat,
              style: TextStyle(
                  color: sel ? Colors.white : Colors.white60,
                  fontSize: 13.5,
                  fontWeight: sel ? FontWeight.w600 : FontWeight.w400)),
        ),
      ),
    );
  }

  Widget _avatarCircle(double size) {
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
    }
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
            colors: [Color(0xFF7B2FFF), Color(0xFF2F6BFF)]),
      ),
      child: const Center(
          child:
              Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20)),
    );
  }

  Widget _buildCoverflow() {
    final list = _shown;
    if (list.isEmpty) return const SizedBox.shrink();
    final cur = _cur.clamp(0, list.length - 1);
    return LayoutBuilder(builder: (c, cons) {
      final cw = cons.maxWidth;
      final w = cw * 0.52; // 卡片宽度：主视频适中，两侧完整可见的缩小视频
      final gap = w * 0.60; // 中心距：左右视频大部分可见，只被主视频压住一部分
      final lo = (cur - 2).clamp(0, list.length - 1);
      final hi = (cur + 2).clamp(0, list.length - 1);
      final items = <Widget>[];
      for (var i = lo; i <= hi; i++) {
        final dist = (i - cur).abs();
        final left = (cw - w) / 2 + (i - cur) * gap;
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
  }
}

/// 封面卡片：video_player 渲染视频首帧（不依赖缩略图插件，HEVC 等格式也能显示）+ 底部渐变遮罩
class _Cover extends StatefulWidget {
  final VlVideo video;
  final bool cur;
  const _Cover({super.key, required this.video, required this.cur});

  @override
  State<_Cover> createState() => _CoverState();
}

class _CoverState extends State<_Cover> {
  VideoPlayerController? _vc;
  bool _vcOk = false;
  bool _inited = false;

  @override
  void initState() {
    super.initState();
    // 非当前卡片延迟初始化，避免多个解码器同时启动卡顿
    if (widget.cur) {
      _init();
    } else {
      Future.delayed(const Duration(milliseconds: 250), _init);
    }
  }

  Future<void> _init() async {
    if (_inited) return;
    _inited = true;
    final vc = VideoPlayerController.file(File(widget.video.path));
    _vc = vc;
    try {
      await vc.initialize();
      await vc.seekTo(Duration.zero);
      if (mounted) setState(() => _vcOk = true);
    } catch (_) {}
  }

  @override
  void dispose() {
    _vc?.dispose();
    super.dispose();
  }

  String _fmt(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.month}/${d.day}';
  }

  @override
  Widget build(BuildContext context) {
    final video = widget.video;
    final cur = widget.cur;
    final grad = _catGrad[video.cat] ?? _catGrad['其他']!;
    final name = video.path.split('/').last;
    final hasThumb =
        video.thumb.isNotEmpty && File(video.thumb).existsSync();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: grad.last.withOpacity(cur ? 0.45 : 0.18),
            blurRadius: cur ? 28 : 12,
            spreadRadius: cur ? 2 : 0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(fit: StackFit.expand, children: [
          // 背景：已生成缩略图 → 缩略图；否则 video_player 首帧；再失败渐变
          hasThumb
              ? Image.file(File(video.thumb),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity)
              : _vcOk
                  ? Container(
                      color: Colors.black,
                      child: Center(child: VideoPlayer(_vc!)),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: grad,
                        ),
                      ),
                    ),
          // 底部渐变遮罩（保证文字可读）
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withOpacity(0.65),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.55],
              ),
            ),
          ),
          // 大播放图标（中央，半透明）
          Center(
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withOpacity(0.28),
                border: Border.all(
                    color: Colors.white.withOpacity(0.4), width: 1.5),
              ),
              child: const Icon(Icons.play_arrow_rounded,
                  color: Colors.white, size: 38),
            ),
          ),
          // 底部信息
          Positioned(
            left: 14,
            right: 14,
            bottom: 12,
            child: Row(children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.45),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(video.cat,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600)),
              ),
              const Spacer(),
              Text(_fmt(video.added),
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.9), fontSize: 12)),
            ]),
          ),
          // 顶部分类名（装饰）
          Positioned(
            top: 12,
            left: 14,
            child: Text(
                name.length > 18 ? '${name.substring(0, 18)}…' : name,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.7), fontSize: 11)),
          ),
        ]),
      ),
    );
  }
}

/// 全屏播放页
class _FullPlayer extends StatefulWidget {
  final VlVideo video;
  final List<Color> catGrad;
  const _FullPlayer({required this.video, required this.catGrad});

  @override
  State<_FullPlayer> createState() => _FullPlayerState();
}

class _FullPlayerState extends State<_FullPlayer> {
  late VideoPlayerController _vc;
  bool _ready = false;
  bool _showCtrl = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _vc = VideoPlayerController.file(File(widget.video.path));
    _vc.initialize().then((_) {
      if (!mounted) return;
      setState(() => _ready = true);
      _vc.play();
      _armHide();
    }).catchError((e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('视频打不开：$e')));
      }
    });
  }

  void _armHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showCtrl = false);
    });
  }

  void _toggle() {
    setState(() => _showCtrl = !_showCtrl);
    _armHide();
    if (_ready) {
      _vc.value.isPlaying ? _vc.pause() : _vc.play();
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _vc.dispose();
    super.dispose();
  }

  String _time(int ms) {
    final s = ms ~/ 1000;
    final m = s ~/ 60;
    return '${m.toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggle,
        child: Stack(children: [
          // 视频
          Center(
            child: _ready
                ? AspectRatio(
                    aspectRatio: _vc.value.aspectRatio,
                    child: VideoPlayer(_vc),
                  )
                : const CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
          ),
          // 顶部控制（渐变遮罩）
          AnimatedOpacity(
            opacity: _showCtrl ? 1 : 0,
            duration: const Duration(milliseconds: 250),
            child: Column(children: [
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Row(children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white, size: 22),
                    ),
                    Expanded(
                      child: Text(widget.video.path.split('/').last,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 15)),
                    ),
                  ]),
                ),
              ),
              const Spacer(),
              // 底部控制：进度 + 时间
              Container(
                padding: const EdgeInsets.fromLTRB(14, 30, 14, 18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.75),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: _ready
                    ? Row(children: [
                        Text(_time(_vc.value.position.inMilliseconds),
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12)),
                        Expanded(
                          child: Slider(
                            value: _vc.value.position.inMilliseconds
                                .toDouble()
                                .clamp(0,
                                    _vc.value.duration.inMilliseconds.toDouble()),
                            max: _vc.value.duration.inMilliseconds
                                .toDouble()
                                .clamp(1, double.infinity),
                            activeColor: widget.catGrad.first,
                            inactiveColor: Colors.white24,
                            onChanged: (v) => _vc.seekTo(
                                Duration(milliseconds: v.round())),
                          ),
                        ),
                        Text(_time(_vc.value.duration.inMilliseconds),
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12)),
                      ])
                    : const SizedBox(height: 50),
              ),
            ]),
          ),
          // 中央播放/暂停大按钮
          if (_ready && !_vc.value.isPlaying && !_showCtrl)
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withOpacity(0.5),
                ),
                child: const Icon(Icons.play_arrow_rounded,
                    color: Colors.white, size: 46),
              ),
            ),
        ]),
      ),
    );
  }
}
