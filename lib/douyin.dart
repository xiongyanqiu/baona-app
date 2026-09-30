// 包娜 · 抖音真实源短视频流（b34）
// 列表页点"抖音"进来：全屏竖滑刷真实抖音推荐视频（电脑端中转服务拉流）
// - 每次进入/刷新/滑到底都是服务端动态推荐 → 视频永远不一样
// - 点赞=收藏：红心状态本地持久化（SharedPreferences）
// - 顶部"登录"入口（登录页 b35 接入）
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

import 'account_login.dart';
import 'api.dart';
import 'theme.dart';

class DouyinPage extends StatefulWidget {
  const DouyinPage({super.key});
  @override
  State<DouyinPage> createState() => _DouyinPageState();
}

class _DouyinPageState extends State<DouyinPage> {
  final PageController _c = PageController();
  int _cur = 0;
  int _favRev = 0; // 收藏版本号：从收藏页回来 +1，逐条重读收藏状态
  bool _loading = true;
  String _err = '';
  List<Map<String, dynamic>> _vids = [];

  // ★保底源（服务拉不到时用）：国内 CDN，直连快
  static const List<Map<String, dynamic>> _fallback = [
    {
      'url': 'https://sf1-cdn-tos.huoshanstatic.com/obj/media-fe/xgplayer_doc_video/mp4/xgplayer-demo-360p.mp4',
      'author': '@包娜', 'desc': '你看这朵云，像不像我催你睡觉的样子☁️',
      'likes': '12.8万', 'comments': '386', 'shares': '1.2万', 'music': '原声 - 包娜', 'bg': '0xFF1F2430',
    },
    {
      'url': 'https://bdcloud-player-new.cdn.bcebos.com/testvideo/mp4/360video/ThaiKongfu.mp4',
      'author': '@功夫熊猫', 'desc': '中国功夫，你学会了吗🥋',
      'likes': '3.2万', 'comments': '98', 'shares': '2300', 'music': '慢 - 武侠', 'bg': '0xFF2B2130',
    },
  ];

  /// 电脑端中转服务地址：与 App 服务器同 host，端口 8633
  String get _feedBase {
    final host = Uri.tryParse(Store.baseUrl);
    if (host != null && host.host.isNotEmpty) return 'http://${host.host}:8633';
    return 'http://192.168.31.120:8633';
  }

  @override
  void initState() {
    super.initState();
    _loadFeed();
  }

  Future<void> _loadFeed({bool append = false}) async {
    try {
      final r = await http
          .get(Uri.parse('$_feedBase/douyin/feed?count=20'))
          .timeout(const Duration(seconds: 20));
      if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode}');
      final j = jsonDecode(utf8.decode(r.bodyBytes));
      final list = (j['videos'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      if (list.isEmpty) throw Exception('empty');
      if (!mounted) return;
      setState(() {
        _vids = append ? [..._vids, ...list] : list;
        _loading = false;
        _err = '';
        _cur = append ? _vids.length - list.length : 0;
      });
      if (append) _c.jumpToPage(_cur);
    } catch (e) {
      if (!mounted) return;
      if (_vids.isEmpty) {
        setState(() {
          _vids = _fallback;
          _loading = false;
          _err = '连接电脑端失败，先用内置视频';
        });
      }
    }
  }

  void _reload() {
    setState(() => _loading = true);
    _loadFeed();
  }

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
        if (_loading && _vids.isEmpty)
          const Center(
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
        else if (_vids.isEmpty)
          Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('没拉到视频', style: TextStyle(color: Colors.white)),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: _reload, child: const Text('重试')),
            ]),
          )
        else
          PageView.builder(
            controller: _c,
            scrollDirection: Axis.vertical,
            onPageChanged: (i) {
              setState(() => _cur = i);
              // 滑到倒数第 2 条 → 自动追加下一批（视频永远不重样）
              if (i >= _vids.length - 2) _loadFeed(append: true);
            },
            itemCount: _vids.length,
            itemBuilder: (_, i) => _VideoItem(v: _vids[i], active: i == _cur, favRev: _favRev),
          ),
        // 顶部：返回 + 标题 + 登录入口
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
              const Spacer(),
              // ★b38 账号逻辑理顺：
              //   未登录 → 显示"登录"，点进去登录；
              //   已登录 → 显示账号名，点进去是【我的收藏】（你点爱心的视频都在这里）
              TextButton.icon(
                onPressed: () {
                  if (Store.accountName.isEmpty) {
                    Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AccountLoginPage()));
                  } else {
                    Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => const DouyinFavPage()))
                        .then((_) {
                      if (mounted) setState(() => _favRev++); // 回来刷新红心
                    });
                  }
                },
                icon: const Icon(Icons.account_circle_rounded, color: Colors.white, size: 18),
                label: Text(Store.accountName.isEmpty ? '登录' : Store.accountName,
                    style: const TextStyle(color: Colors.white, fontSize: 14)),
              ),
              const SizedBox(width: 8),
            ]),
          ),
        ),
        if (_err.isNotEmpty && _vids.isNotEmpty)
          Positioned(
            top: 120, left: 0, right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xAA000000),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(_err,
                    style: const TextStyle(color: Color(0xFFFFC27A), fontSize: 11.5)),
              ),
            ),
          ),
      ]),
    );
  }
}

/// 一条视频（真实源 Map 或保底 Map 均可）
class _VideoItem extends StatefulWidget {
  const _VideoItem({required this.v, required this.active, this.favRev = 0, this.onUnfav});
  final Map<String, dynamic> v;
  final bool active;
  /// 收藏版本号：从收藏页回来+1，让每一条重新读一次收藏状态（不然取消收藏回来红心还是红的）
  final int favRev;
  /// 取消收藏时回调（收藏页用它把这条从列表里拿走）
  final VoidCallback? onUnfav;
  @override
  State<_VideoItem> createState() => _VideoItemState();
}

class _VideoItemState extends State<_VideoItem> {
  VideoPlayerController? _vc;
  bool _liked = false;

  static const String _kFavs = 'dy.favs';

  String get _vid => '${widget.v['aweme_id'] ?? widget.v['url']}';

  @override
  void initState() {
    super.initState();
    _loadFav();
    if (widget.active) _init();
  }

  Future<void> _loadFav() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString(_kFavs) ?? '';
    if (s.isNotEmpty) {
      try {
        final raw = jsonDecode(s);
        if (raw is List) {
          final key = _vid;
          final liked = raw.any(
              (x) => x is Map && '${x['aweme_id'] ?? x['url']}' == key);
          if (mounted) setState(() => _liked = liked);
        }
      } catch (_) {}
    }
  }

  Future<void> _toggleFav() async {
    setState(() => _liked = !_liked);
    final p = await SharedPreferences.getInstance();
    final s = p.getString(_kFavs) ?? '';
    List<Map<String, dynamic>> list = [];
    if (s.isNotEmpty) {
      try {
        final raw = jsonDecode(s);
        if (raw is List) {
          for (final x in raw) {
            if (x is Map) list.add(Map<String, dynamic>.from(x));
            // 旧格式（只有 id 的字符串）直接丢弃——没有视频信息没法播
          }
        }
      } catch (_) {}
    }
    final v = widget.v;
    final key = '${v['aweme_id'] ?? v['url']}';
    if (_liked) {
      if (!list.any((x) => '${x['aweme_id'] ?? x['url']}' == key)) {
        list.add(Map<String, dynamic>.from(v)); // ★存完整视频信息，收藏页才能播
      }
    } else {
      list.removeWhere((x) => '${x['aweme_id'] ?? x['url']}' == key);
    }
    await p.setString(_kFavs, jsonEncode(list));
    if (!_liked) widget.onUnfav?.call();
  }

  Future<void> _init() async {
    if (_vc != null) return;
    final c = VideoPlayerController.networkUrl(Uri.parse('${widget.v['url']}'));
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
    if (old.favRev != widget.favRev) _loadFav();
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

  /// 数字美化：21154 → "2.1万"
  static String _fmt(dynamic n) {
    final v = n is int ? n : int.tryParse('$n') ?? 0;
    if (v >= 100000000) return '${(v / 100000000).toStringAsFixed(1)}亿';
    if (v >= 10000) return '${(v / 10000).toStringAsFixed(1)}万';
    return '$v';
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.v;
    final bg = '${v['bg'] ?? ''}';
    return Container(
      color: bg.isNotEmpty ? Color(int.parse(bg)) : const Color(0xFF14151A),
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
            Text('${v['author'] ?? '@未知'}',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text('${v['desc'] ?? ''}',
                style: const TextStyle(color: Colors.white, fontSize: 13.5, height: 1.45)),
            const SizedBox(height: 10),
            Row(children: [
              const Icon(Icons.music_note, color: Colors.white, size: 14),
              Text(' ${v['music'] ?? '原声'}',
                  style: const TextStyle(color: Colors.white, fontSize: 12.5)),
            ]),
          ]),
        ),
        // 右侧操作栏：点赞(收藏) / 评论 / 分享
        Positioned(
          right: 8,
          bottom: 100,
          child: Column(children: [
            _action(
              icon: Icons.favorite_rounded,
              on: _liked,
              label: _fmt(v['likes']),
              onTap: _toggleFav,
            ),
            _action(
                icon: Icons.mode_comment_rounded,
                on: false,
                label: _fmt(v['comments'])),
            _action(icon: Icons.ios_share_rounded, on: false, label: _fmt(v['shares'])),
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

/* ============================ 我的收藏 ============================ */
/// ★b38 已登录点右上角账号进来：你点过爱心的视频全在这里，竖滑播放
class DouyinFavPage extends StatefulWidget {
  const DouyinFavPage({super.key});
  @override
  State<DouyinFavPage> createState() => _DouyinFavPageState();
}

class _DouyinFavPageState extends State<DouyinFavPage> {
  static const String _kFavs = 'dy.favs';
  List<Map<String, dynamic>> _favs = [];
  bool _loaded = false;
  int _cur = 0;
  late final PageController _c = PageController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString(_kFavs) ?? '';
    final list = <Map<String, dynamic>>[];
    if (s.isNotEmpty) {
      try {
        final raw = jsonDecode(s);
        if (raw is List) {
          for (final x in raw) {
            if (x is Map) list.add(Map<String, dynamic>.from(x));
          }
        }
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _favs = list;
      _loaded = true;
    });
  }

  void _remove(Map<String, dynamic> v) {
    final key = '${v['aweme_id'] ?? v['url']}';
    setState(() {
      _favs.removeWhere((x) => '${x['aweme_id'] ?? x['url']}' == key);
      if (_cur >= _favs.length && _cur > 0) _cur = _favs.length - 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: Stack(children: [
        if (!_loaded)
          const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
        else if (_favs.isEmpty)
          Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.favorite_border_rounded, color: Colors.white, size: 46),
              const SizedBox(height: 14),
              const Text('还没有收藏', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              const Text('刷视频的时候点右边红心，就存到这里了', style: TextStyle(color: Color(0xFF9AA0B4), fontSize: 12.5)),
              const SizedBox(height: 18),
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('回去刷视频'),
              ),
            ]),
          )
        else
          PageView.builder(
            controller: _c,
            scrollDirection: Axis.vertical,
            onPageChanged: (i) => setState(() => _cur = i),
            itemCount: _favs.length,
            itemBuilder: (_, i) {
              final v = _favs[i];
              return _VideoItem(
                v: v,
                active: i == _cur,
                onUnfav: () => _remove(v),
              );
            },
          ),
        // 顶部：返回 + 标题 + 数量
        Positioned(
          top: 0, left: 0, right: 0,
          child: SafeArea(
            bottom: false,
            child: Row(children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
              ),
              const Text('我的收藏', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              if (_loaded && _favs.isNotEmpty)
                Text('${_favs.length} 条', style: const TextStyle(color: Color(0xFF9AA0B4), fontSize: 12.5)),
              const Spacer(),
            ]),
          ),
        ),
      ]),
    );
  }
}
