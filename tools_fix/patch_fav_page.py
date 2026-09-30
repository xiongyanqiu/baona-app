# -*- coding: utf-8 -*-
import io

p = r'C:\Users\xilisi\Doubao\chats\2026-09-27\new-chat\baona-app\lib\douyin.dart'
s = io.open(p, encoding='utf-8').read()

fav_page = '''
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
'''

# 追加到文件末尾（去掉文件最后多余空行）
s = s.rstrip() + '\n' + fav_page
io.open(p, 'w', encoding='utf-8', newline='').write(s)
print('DouyinFavPage 已追加')
