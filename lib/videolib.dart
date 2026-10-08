// 包娜 · 视频库（独立入口，v26.2）
// 方案A：3D CoverFlow 旋转轮播 —— 当前封面立起居中，两侧倾斜缩小后退
// - 视频存在手机本地（App 文档目录），不传电脑
// - 点击封面 → 全屏播放该视频
// - 分类：自定义（默认 日常/老婆的/收藏/其他，可增删改）
// - 封面：真实视频第一帧缩略图（video_thumbnail），无缩略图时回退渐变卡片
// - 右上角头像设置入口：相册选图存本地，对话列表头像同步
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'theme.dart';
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

class _VideoLibPageState extends State<VideoLibPage>
    with SingleTickerProviderStateMixin {
  AnimationController? _anim; // 松手惯性动画
  double _dragOff = 0; // 跟手偏移（拖动时整列跟随手指）
  double _cardW = 1; // 卡片宽（build 时更新，手势判定用）
  double _cardGap = 1; // 卡片中心距
  List<VlVideo> _vids = [];
  Uint8List? _avatarBytes; // 头像解码缓存（防滑动重建闪烁）
  List<String> _cats = ['日常', '老婆的', '收藏', '其他'];
  String _cat = '全部';
  int _cur = 0;
  bool _loaded = false;
  bool _edit = false; // ★v27.0.15 编辑模式：顶栏删除按钮进入，卡片删除按钮放大变红
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
    _anim?.dispose();
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
    _avatarBytes = _decodeAvatar(_avatar);
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

  List<VlVideo> get _shown {
    // 严格按分类筛选：切到什么分类就只显示该分类的视频
    if (_cat == '全部') return List.of(_vids);
    return _vids.where((v) => v.cat == _cat).toList();
  }

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
    // ★26.2.20 双写系统相册：App 重装后视频还在系统相册里，重新导入就能找回
    try {
      final ps = await PhotoManager.requestPermissionExtend();
      if (ps.hasAccess) {
        await PhotoManager.editor.saveVideo(File(target), title: 'baona_$ts');
      }
    } catch (_) {}
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
    if (mounted) {
      setState(() {
        _avatar = dataUrl;
        _avatarBytes = _decodeAvatar(dataUrl);
      });
    }
  }

  void _openPlayer(int index) {
    final list = _shown;
    if (index < 0 || index >= list.length) return;
    Navigator.of(context)
        .push(MaterialPageRoute(
            builder: (_) => _FullPlayer(
                  video: list[index],
                  catGrad: _catGrad[list[index].cat] ?? _catGrad['其他']!,
                )))
        .then((deleted) {
      // 播放页里删了视频 → 回来同步移除列表
      if (deleted == true && mounted) {
        final v = list[index];
        setState(() {
          _vids.removeWhere((x) => x.path == v.path);
          _cur = 0;
        });
        _save();
      }
    });
  }

  /// ★v27.0.15 视频长按删除（跟音频库一致）：删本地文件 + 移列表 + 保存
  Future<void> _delVideo(int index) async {
    final list = _shown;
    if (index < 0 || index >= list.length) return;
    final v = list[index];
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF17181C),
        title: const Text('删除视频',
            style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700)),
        content: Text('确定删除「${v.path.split('/').last}」吗？',
            style: const TextStyle(color: Colors.white70, fontSize: 14.5)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('不删', style: TextStyle(color: Colors.white54))),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('删除',
                  style: TextStyle(
                      color: Color(0xFFFF6B6B),
                      fontWeight: FontWeight.w600))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final f = File(v.path);
      if (f.existsSync()) f.deleteSync();
    } catch (_) {}
    setState(() {
      _vids.removeWhere((x) => x.path == v.path);
      _cur = 0;
    });
    await _save();
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
                const SizedBox(width: 8),
                Text('v' + kAppVer,
                    style: TextStyle(
                        color: Colors.white38,
                        fontSize: 11)),
                const Spacer(),
                // ★v27.0.15 删除（编辑模式开关）
                IconButton(
                  onPressed: () => setState(() => _edit = !_edit),
                  icon: Icon(
                      _edit
                          ? Icons.delete_rounded
                          : Icons.delete_outline_rounded,
                      color: _edit ? const Color(0xFFFF6B6B) : Colors.white70,
                      size: 21),
                ),
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

  Uint8List? _decodeAvatar(String av) {
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
      final ch = cons.maxHeight;
      final w = cw * 0.70; // 9:16 竖屏矩形卡片：宽度70%屏宽，用户确认
      final h = w * 16 / 9;
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
            onLongPress: () => _delVideo(i),
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
                  child: Stack(children: [
                    Positioned.fill(
                        child: _Cover(video: list[i], cur: i == cur)),
                    // ★v27.0.15 封面右上角删除按钮（编辑模式 = 大红色，普通模式 = 小黑点）
                    Positioned(
                      top: _edit ? 14 : 8,
                      right: _edit ? 14 : 8,
                      child: GestureDetector(
                        onTap: () => _delVideo(i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: EdgeInsets.all(_edit ? 14 : 7),
                          decoration: BoxDecoration(
                            color: _edit
                                ? const Color(0xFFFF4D4F)
                                : Colors.black.withOpacity(0.45),
                            shape: BoxShape.circle,
                            boxShadow: _edit
                                ? [
                                    BoxShadow(
                                        color: const Color(0xFFFF4D4F)
                                            .withOpacity(0.5),
                                        blurRadius: 10)
                                  ]
                                : null,
                          ),
                          child: Icon(Icons.delete_outline_rounded,
                              color: Colors.white,
                              size: _edit ? 22 : 16),
                        ),
                      ),
                    ),
                  ]),
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
    );
    final t = Tween<double>(begin: from, end: to).animate(
      CurvedAnimation(parent: _anim!, curve: Curves.easeOutCubic),
    );
    _anim!.addListener(() {
      if (!mounted) return;
      setState(() => _dragOff = t.value);
    });
    _anim!.forward().whenComplete(() {
      if (!mounted) return;
      setState(() {
        _cur = target;
        _dragOff = 0;
      });
    });
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
  // ★v27.0.15 横屏 + 长按快进
  bool _land = false; // 是否横屏
  Timer? _ffTimer;
  bool _ff = false; // 长按快进中

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

  /// 横屏 ↔ 竖屏切换
  void _toggleLand() {
    setState(() => _land = !_land);
    SystemChrome.setPreferredOrientations(_land
        ? [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]
        : [DeviceOrientation.portraitUp]);
  }

  /// 长按快进：按住期间每 250ms 前进 750ms（约 3x）
  void _ffStart() {
    if (!_ready || !_vc.value.isPlaying) return;
    _ff = true;
    setState(() {});
    _ffTimer?.cancel();
    _ffTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted || !_ff) return;
      final now = _vc.value.position.inMilliseconds;
      final dur = _vc.value.duration.inMilliseconds;
      final nxt = (now + 750).clamp(0, dur);
      _vc.seekTo(Duration(milliseconds: nxt));
      setState(() {});
    });
  }

  void _ffEnd() {
    _ff = false;
    _ffTimer?.cancel();
    if (mounted) setState(() {});
  }

  /// 播放页删除：删本地文件 → pop(true) 通知列表同步
  Future<void> _del() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF17181C),
        title: const Text('删除视频',
            style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700)),
        content: Text('确定删除「${widget.video.path.split('/').last}」吗？',
            style: const TextStyle(color: Colors.white70, fontSize: 14.5)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('不删', style: TextStyle(color: Colors.white54))),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('删除',
                  style: TextStyle(
                      color: Color(0xFFFF6B6B),
                      fontWeight: FontWeight.w600))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final f = File(widget.video.path);
      if (f.existsSync()) f.deleteSync();
    } catch (_) {}
    Navigator.pop(context, true);
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
    _ffTimer?.cancel();
    _vc.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]); // 退出播放恢复竖屏
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
        onLongPressStart: (_) => _ffStart(),
        onLongPressEnd: (_) => _ffEnd(),
        onLongPressCancel: _ffEnd,
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
          // 长按快进浮层
          if (_ff)
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.fast_forward_rounded,
                      color: Colors.white, size: 22),
                  SizedBox(width: 8),
                  Text('快进中 3x',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                ]),
              ),
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
                    // 横屏切换
                    IconButton(
                      onPressed: _toggleLand,
                      icon: Icon(_land
                          ? Icons.fullscreen_exit_rounded
                          : Icons.fullscreen_rounded,
                          color: Colors.white, size: 22),
                    ),
                    // 删除
                    IconButton(
                      onPressed: _del,
                      icon: const Icon(Icons.delete_outline_rounded,
                          color: Colors.white, size: 22),
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
