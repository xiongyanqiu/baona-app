// 包娜 · 抖音风格短视频流（模拟源，后续可换真实视频）
// 列表页点"抖音"进来：全屏竖滑刷视频，右侧点赞/评论/分享，底部作者/描述
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'theme.dart';

class DouyinPage extends StatefulWidget {
  const DouyinPage({super.key});
  @override
  State<DouyinPage> createState() => _DouyinPageState();
}

class _DouyinPageState extends State<DouyinPage> {
  final PageController _c = PageController();
  int _cur = 0;

  // ★模拟流视频源（全部 https 公开测试视频，iOS 可直接播；以后想换真实源改这里）
  static const List<Map<String, String>> _vids = [
    {
      'url': 'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
      'author': '@包娜',
      'desc': '你看这只蜜蜂，像不像我催你睡觉的样子🐝',
      'likes': '12.8万', 'comments': '386', 'shares': '1.2万',
      'music': '原声 - 包娜',
      'bg': '0xFF1F2430',
    },
    {
      'url': 'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4',
      'author': '@小蝴蝶',
      'desc': '慢一点，再慢一点，世界就安静了✨',
      'likes': '3.2万', 'comments': '98', 'shares': '2300',
      'music': '慢 - 轻音乐',
      'bg': '0xFF2B2130',
    },
    {
      'url': 'https://interactive-examples.mdn.mozilla.net/media/cc0-videos/flower.mp4',
      'author': '@花园日记',
      'desc': '春天开的第一朵花，送给你🌷',
      'likes': '8.7万', 'comments': '512', 'shares': '6400',
      'music': '原声 - 花园',
      'bg': '0xFF1F2A24',
    },
    {
      'url': 'https://media.w3.org/2010/05/sintel/trailer.mp4',
      'author': '@电影研究所',
      'desc': '这段预告片的每一帧都是壁纸🎬',
      'likes': '21.4万', 'comments': '1203', 'shares': '3.4万',
      'music': 'Sintel - Trailer',
      'bg': '0xFF1C1C28',
    },
    {
      'url': 'https://www.w3schools.com/html/mov_bbb.mp4',
      'author': '@大兔子',
      'desc': 'Big Buck Bunny 经典动画，治愈一下🥕',
      'likes': '5.5万', 'comments': '276', 'shares': '4100',
      'music': '原声 - 兔子',
      'bg': '0xFF24301F',
    },
  ];

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: Stack(children: [
        PageView.builder(
          controller: _c,
          scrollDirection: Axis.vertical,
          onPageChanged: (i) => setState(() => _cur = i),
          itemCount: _vids.length,
          itemBuilder: (_, i) => _VideoItem(v: _vids[i], active: i == _cur),
        ),
        // 顶部返回 + 标题
        Positioned(
          top: 0, left: 0, right: 0,
          child: SafeArea(
            bottom: false,
            child: Row(children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 20),
              ),
              const Text('抖音',
                  style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _VideoItem extends StatefulWidget {
  const _VideoItem({required this.v, required this.active});
  final Map<String, String> v;
  final bool active;
  @override
  State<_VideoItem> createState() => _VideoItemState();
}

class _VideoItemState extends State<_VideoItem> {
  VideoPlayerController? _vc;
  bool _liked = false;

  @override
  void initState() {
    super.initState();
    if (widget.active) _init();
  }

  Future<void> _init() async {
    if (_vc != null) return;
    final c = VideoPlayerController.networkUrl(Uri.parse(widget.v['url']!));
    _vc = c;
    try {
      await c.initialize();
      if (!mounted) return;
      setState(() {});
      c.setLooping(true);
      c.play();
    } catch (_) {/* 视频源失败就留纯色背景 */}
  }

  @override
  void didUpdateWidget(_VideoItem old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) {
      if (_vc == null) {
        _init();
      } else if (_vc!.value.isInitialized && !_vc!.value.isPlaying) {
        _vc!.play();
      }
    } else if (!widget.active && old.active) {
      _vc?.pause();
    }
  }

  @override
  void dispose() {
    _vc?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.v;
    return Container(
      color: Color(int.parse(v['bg']!)),
      child: Stack(fit: StackFit.expand, children: [
        // 视频画面（cover 裁切；点一下暂停/继续）
        if (_vc != null && _vc!.value.isInitialized)
          GestureDetector(
            onTap: () => _vc!.value.isPlaying ? _vc!.pause() : _vc!.play(),
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _vc!.value.size.width,
                height: _vc!.value.size.height,
                child: VideoPlayer(_vc!),
              ),
            ),
          ),
        // 底部渐变保证文字可读
        Positioned(
          left: 0, right: 0, bottom: 0,
          child: Container(
            height: 260,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x00000000), Color(0xC0000000)],
              ),
            ),
          ),
        ),
        // 底部信息：作者 / 描述 / 音乐
        Positioned(
          left: 14,
          right: 80,
          bottom: 26,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(v['author']!,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(v['desc']!,
                style: const TextStyle(color: Colors.white, fontSize: 13.5, height: 1.45)),
            const SizedBox(height: 10),
            Row(children: [
              const Icon(Icons.music_note, color: Colors.white, size: 14),
              Text(' ${v['music']}',
                  style: const TextStyle(color: Colors.white, fontSize: 12.5)),
            ]),
          ]),
        ),
        // 右侧操作栏：点赞 / 评论 / 分享
        Positioned(
          right: 8,
          bottom: 100,
          child: Column(children: [
            _action(
              icon: Icons.favorite_rounded,
              on: _liked,
              label: v['likes']!,
              onTap: () => setState(() => _liked = !_liked),
            ),
            _action(icon: Icons.mode_comment_rounded, on: false, label: v['comments']!),
            _action(icon: Icons.ios_share_rounded, on: false, label: v['shares']!),
          ]),
        ),
      ]),
    );
  }

  Widget _action({
    required IconData icon,
    required bool on,
    required String label,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(children: [
        GestureDetector(
          onTap: onTap,
          child: Icon(icon,
              size: 33,
              color: on ? const Color(0xFFFF3B5C) : Colors.white,
              shadows: const [Shadow(color: Color(0x66000000), blurRadius: 8)]),
        ),
        const SizedBox(height: 3),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 11.5)),
      ]),
    );
  }
}
