# -*- coding: utf-8 -*-
import io

p = r'C:\Users\xilisi\Doubao\chats\2026-09-27\new-chat\baona-app\lib\douyin.dart'
s = io.open(p, encoding='utf-8').read()

# ============ 1. _VideoItem：加 favRev / onUnfav，收藏存完整对象 ============
old = """class _VideoItem extends StatefulWidget {
  const _VideoItem({required this.v, required this.active});
  final Map<String, dynamic> v;
  final bool active;
  @override
  State<_VideoItem> createState() => _VideoItemState();
}"""
new = """class _VideoItem extends StatefulWidget {
  const _VideoItem({required this.v, required this.active, this.favRev = 0, this.onUnfav});
  final Map<String, dynamic> v;
  final bool active;
  /// 收藏版本号：从收藏页回来+1，让每一条重新读一次收藏状态（不然取消收藏回来红心还是红的）
  final int favRev;
  /// 取消收藏时回调（收藏页用它把这条从列表里拿走）
  final VoidCallback? onUnfav;
  @override
  State<_VideoItem> createState() => _VideoItemState();
}"""
assert old in s, 'ctor fail'
s = s.replace(old, new, 1)

old2 = """  Future<void> _loadFav() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString(_kFavs) ?? '';
    if (s.isNotEmpty) {
      try {
        final list = (jsonDecode(s) as List).cast<String>();
        if (mounted) setState(() => _liked = list.contains(_vid));
      } catch (_) {}
    }
  }"""
new2 = """  Future<void> _loadFav() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString(_kFavs) ?? '';
    if (s.isNotEmpty) {
      try {
        final raw = jsonDecode(s);
        if (raw is List) {
          final key = _vid;
          final liked = raw.any(
              (x) => x is Map && '\${x['aweme_id'] ?? x['url']}' == key);
          if (mounted) setState(() => _liked = liked);
        }
      } catch (_) {}
    }
  }"""
assert old2 in s, 'loadfav fail'
s = s.replace(old2, new2, 1)

old3 = """  Future<void> _toggleFav() async {
    setState(() => _liked = !_liked);
    final p = await SharedPreferences.getInstance();
    final s = p.getString(_kFavs) ?? '';
    List<String> list = [];
    if (s.isNotEmpty) {
      try {
        list = (jsonDecode(s) as List).cast<String>();
      } catch (_) {}
    }
    if (_liked) {
      if (!list.contains(_vid)) list.add(_vid);
    } else {
      list.remove(_vid);
    }
    await p.setString(_kFavs, jsonEncode(list));
  }"""
new3 = """  Future<void> _toggleFav() async {
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
    final key = '\${v['aweme_id'] ?? v['url']}';
    if (_liked) {
      if (!list.any((x) => '\${x['aweme_id'] ?? x['url']}' == key)) {
        list.add(Map<String, dynamic>.from(v)); // ★存完整视频信息，收藏页才能播
      }
    } else {
      list.removeWhere((x) => '\${x['aweme_id'] ?? x['url']}' == key);
    }
    await p.setString(_kFavs, jsonEncode(list));
    if (!_liked) widget.onUnfav?.call();
  }"""
assert old3 in s, 'togglefav fail'
s = s.replace(old3, new3, 1)

# favRev 变化 → 重新读收藏状态
old4 = """  @override
  void didUpdateWidget(_VideoItem old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) {"""
new4 = """  @override
  void didUpdateWidget(_VideoItem old) {
    super.didUpdateWidget(old);
    if (old.favRev != widget.favRev) _loadFav();
    if (widget.active && !old.active) {"""
assert old4 in s, 'didupdate fail'
s = s.replace(old4, new4, 1)

# ============ 2. DouyinPage：右上角逻辑 + favRev 传递 ============
old5 = """            itemBuilder: (_, i) => _VideoItem(v: _vids[i], active: i == _cur),"""
new5 = """            itemBuilder: (_, i) => _VideoItem(v: _vids[i], active: i == _cur, favRev: _favRev),"""
assert old5 in s, 'itembuilder fail'
s = s.replace(old5, new5, 1)

old6 = """              // ★b35 统一账号：已登录显示账号名，未登录点击去登录（登录后全局共用）
              TextButton.icon(
                onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AccountLoginPage())),
                icon: const Icon(Icons.account_circle_rounded, color: Colors.white, size: 18),
                label: Text(Store.accountName.isEmpty ? '登录' : Store.accountName,
                    style: const TextStyle(color: Colors.white, fontSize: 14)),
              ),"""
new6 = """              // ★b38 账号逻辑理顺：
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
              ),"""
assert old6 in s, 'right top fail'
s = s.replace(old6, new6, 1)

# _favRev 状态 + _loadFeed 时重置
old7 = """  int _cur = 0;"""
new7 = """  int _cur = 0;
  int _favRev = 0; // 收藏版本号：从收藏页回来 +1，逐条重读收藏状态"""
assert old7 in s, 'favrev state fail'
s = s.replace(old7, new7, 1)

io.open(p, 'w', encoding='utf-8', newline='').write(s)
print('douyin.dart 收藏升级 + 右上角逻辑 OK')
