// vlib.dart — 包娜 App v27.0.14.11 视频区：本地视频库
// 设计：iOS 27 Liquid Glass（半透明玻璃卡片，壁纸透出）
// 内容：系统相册视频网格（首帧封面）→ 点击全屏播放；右上「添加」从相册选视频入库
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:video_player/video_player.dart';

import 'main.dart';
import 'theme.dart';

/// 视频区：本地视频库
class VideoLibPage extends StatefulWidget {
  const VideoLibPage({super.key});
  @override
  State<VideoLibPage> createState() => _VideoLibPageState();
}

class _VideoLibPageState extends State<VideoLibPage> {
  List<AssetEntity> _videos = [];
  final Map<String, Uint8List> _thumbs = {};
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final paths = await PhotoManager.getAssetPathList(
          type: RequestType.video, onlyAll: true);
      if (paths.isEmpty) {
        if (mounted) setState(() => _loaded = true);
        return;
      }
      final list = await paths.first.getAssetListPaged(page: 0, size: 10000);
      if (!mounted) return;
      setState(() {
        _videos = list;
        _loaded = true;
      });
      for (final e in list) {
        try {
          final b = await e.thumbnailDataWithSize(
              ThumbnailSize.square(560), quality: 80);
          if (b != null && mounted) setState(() => _thumbs[e.id] = b);
        } catch (_) {}
      }
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  /// 添加：从相册选视频 → 写进系统相册（重装不丢）→ 刷新
  Future<void> _add() async {
    final XFile? f;
    try {
      f = await ImagePicker().pickVideo(source: ImageSource.gallery);
    } catch (_) {
      return;
    }
    if (f == null) return;
    try {
      final file = File(f.path);
      if (!await file.exists()) return;
      await PhotoManager.editor.saveVideo(file, title: 'baona');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('已添加到视频库'), behavior: SnackBarBehavior.floating));
      _load();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: EdgeInsets.fromLTRB(20, navSpace(context) - 30, 20, 10),
        child: Row(children: [
          const Expanded(
            child: Text('视频',
                style: TextStyle(
                    fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -0.6)),
          ),
          // 添加
          GestureDetector(
            onTap: _add,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: kAccent.withValues(alpha: 0.22),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0x26FFFFFF), width: 0.8),
              ),
              child: const Icon(Icons.add, size: 20, color: kText),
            ),
          ),
        ]),
      ),
      Expanded(
        child: !_loaded
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2.5))
            : _videos.isEmpty
                ? _empty()
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, navSpace(context) + 16),
                    physics: const BouncingScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 6,
                      crossAxisSpacing: 6,
                      childAspectRatio: 0.72,
                    ),
                    itemCount: _videos.length,
                    itemBuilder: (c, i) => _cell(_videos[i]),
                  ),
      ),
    ]);
  }

  Widget _cell(AssetEntity e) {
    final b = _thumbs[e.id];
    return GestureDetector(
      onTap: () async {
        try {
          final f = await e.file;
          if (f == null) return;
          if (!mounted) return;
          await Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => _PlayerPage(path: f.path, title: e.title ?? '视频')));
        } catch (_) {}
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Container(
          color: const Color(0x40000000),
          child: Stack(fit: StackFit.expand, children: [
            if (b != null)
              Image.memory(b, fit: BoxFit.cover, gaplessPlayback: true)
            else
              const Center(
                  child: Icon(Icons.movie_outlined, size: 22, color: kSub)),
            // 播放标记
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                margin: const EdgeInsets.only(bottom: 5),
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: const Color(0x99000000),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0x33FFFFFF), width: 0.8),
                ),
                child: const Icon(Icons.play_arrow_rounded, size: 16, color: Colors.white),
              ),
            ),
            // 时长（右上角）
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                decoration: BoxDecoration(
                  color: const Color(0x99000000),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(_dur(e.durationSeconds),
                    style: const TextStyle(fontSize: 9.5, color: Colors.white)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  String _dur(int s) {
    if (s <= 0) return '';
    final m = s ~/ 60;
    final r = (s % 60).toString().padLeft(2, '0');
    return '$m:$r';
  }

  Widget _empty() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: kAccent.withValues(alpha: 0.18),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.videocam_outlined, size: 30, color: kAccent),
        ),
        const SizedBox(height: 14),
        const Text('视频库还空着', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 5),
        const Text('点右上角「+」从相册添加视频', style: TextStyle(fontSize: 12.5, color: kSub)),
      ]),
    );
  }
}

/// 全屏视频播放器（黑底沉浸）
class _PlayerPage extends StatefulWidget {
  const _PlayerPage({required this.path, required this.title});
  final String path;
  final String title;
  @override
  State<_PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<_PlayerPage> {
  late VideoPlayerController _vc;
  bool _ok = false;

  @override
  void initState() {
    super.initState();
    _vc = VideoPlayerController.file(File(widget.path));
    _vc.initialize().then((_) {
      if (!mounted) return;
      setState(() => _ok = true);
      _vc.setLooping(false);
      _vc.play();
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _vc.dispose();
    super.dispose();
  }

  String _fmt(int ms) {
    final s = ms ~/ 1000;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(children: [
          // 顶栏
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
            child: Row(children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.white),
              ),
              Expanded(
                child: Text(widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
          Expanded(
            child: Center(
              child: _ok
                  ? GestureDetector(
                      onTap: () => setState(() {
                        _vc.value.isPlaying ? _vc.pause() : _vc.play();
                      }),
                      child: Stack(alignment: Alignment.center, children: [
                        AspectRatio(
                          aspectRatio: _vc.value.aspectRatio,
                          child: VideoPlayer(_vc),
                        ),
                        if (!_vc.value.isPlaying)
                          Container(
                            width: 62,
                            height: 62,
                            decoration: BoxDecoration(
                              color: const Color(0x8A000000),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.play_arrow_rounded,
                                size: 34, color: Colors.white),
                          ),
                      ]),
                    )
                  : const CircularProgressIndicator(strokeWidth: 2.5),
            ),
          ),
          // 进度条
          if (_ok)
            AnimatedBuilder(
              animation: _vc,
              builder: (c, _) => Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: Row(children: [
                  Text(_fmt(_vc.value.position.inMilliseconds),
                      style: const TextStyle(fontSize: 11, color: Colors.white70)),
                  Expanded(
                    child: Slider(
                      value: _vc.value.duration.inMilliseconds <= 0
                          ? 0
                          : _vc.value.position.inMilliseconds
                              .clamp(0, _vc.value.duration.inMilliseconds)
                              .toDouble(),
                      max: _vc.value.duration.inMilliseconds <= 0
                          ? 1
                          : _vc.value.duration.inMilliseconds.toDouble(),
                      activeColor: kAccent,
                      inactiveColor: const Color(0x33FFFFFF),
                      onChanged: (v) => _vc.seekTo(Duration(milliseconds: v.round())),
                    ),
                  ),
                  Text(_fmt(_vc.value.duration.inMilliseconds),
                      style: const TextStyle(fontSize: 11, color: Colors.white70)),
                ]),
              ),
            ),
        ]),
      ),
    );
  }
}
