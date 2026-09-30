// 包娜 · 视频库（独立入口，b49）
// 方案A：3D CoverFlow 旋转轮播 —— 当前封面立起居中，两侧倾斜缩小后退
// - 视频存在手机本地（App 文档目录），不传电脑
// - 点击封面 → 全屏播放该视频
// - 分类：日常 / 老婆的 / 收藏 / 其他（全部 = 混排）
// - 右上角设置头像入口：相册选图存本地，对话列表头像同步
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

/// 一个视频条目
class VlVideo {
  final String path;
  final String cat;
  final int added;
  VlVideo({required this.path, required this.cat, required this.added});

  Map<String, dynamic> toJson() =>
      {'path': path, 'cat': cat, 'added': added};

  factory VlVideo.fromJson(Map<String, dynamic> j) => VlVideo(
        path: j['path'] ?? '',
        cat: j['cat'] ?? '其他',
        added: (j['added'] as num?)?.toInt() ?? 0,
      );
}

const List<String> kCats = ['日常', '老婆的', '收藏', '其他'];

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
  final _pv = PageController();
  List<VlVideo> _vids = [];
  String _cat = '全部';
  int _cur = 0;
  bool _loaded = false;
  String _avatar = '';

  static const _dbKey = 'vl.db';
  static const _avKey = 'vl.avatar';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pv.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final sp = await SharedPreferences.getInstance();
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
  }

  Future<void> _save() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(
        _dbKey, jsonEncode(_vids.map((v) => v.toJson()).toList()));
  }

  List<VlVideo> get _shown =>
      _cat == '全部' ? _vids : _vids.where((v) => v.cat == _cat).toList();

  /// 从相册选视频 → 复制进 App 文档目录 → 选分类入库
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
      // 取消分类 = 不入库，删掉复制的文件
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
    _pv.jumpToPage(_shown.length - 1);
    await _save();
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
          for (final cat in kCats)
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
          // 顶栏：返回 + 标题 + 头像设置入口
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
                for (final cat in ['全部', ...kCats]) _catChip(cat),
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
          _pv.jumpToPage(0);
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
          child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20)),
    );
  }

  Widget _buildCoverflow() {
    final list = _shown;
    if (list.isEmpty) return const SizedBox.shrink();
    // 修正越界（分类切换后）
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
  }
}

/// 封面卡片
class _Cover extends StatelessWidget {
  final VlVideo video;
  final bool cur;
  const _Cover({required this.video, required this.cur});

  String _fmt(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.month}/${d.day}';
  }

  @override
  Widget build(BuildContext context) {
    final grad = _catGrad[video.cat] ?? _catGrad['其他']!;
    final name = video.path.split('/').last;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: grad,
        ),
        boxShadow: [
          BoxShadow(
            color: grad.last.withOpacity(cur ? 0.45 : 0.18),
            blurRadius: cur ? 28 : 12,
            spreadRadius: cur ? 2 : 0,
          ),
        ],
      ),
      child: Stack(children: [
        // 大播放图标
        Center(
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.16),
              border: Border.all(color: Colors.white.withOpacity(0.35), width: 1.5),
            ),
            child: const Icon(Icons.play_arrow_rounded,
                color: Colors.white, size: 40),
          ),
        ),
        // 底部信息
        Positioned(
          left: 14,
          right: 14,
          bottom: 12,
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.35),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(video.cat,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600)),
            ),
            const Spacer(),
            Text(_fmt(video.added),
                style: TextStyle(
                    color: Colors.white.withOpacity(0.85), fontSize: 12)),
          ]),
        ),
        // 顶部分类名（装饰）
        Positioned(
          top: 12,
          left: 14,
          child: Text(name.length > 18 ? '${name.substring(0, 18)}…' : name,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.55), fontSize: 11)),
        ),
      ]),
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
