# -*- coding: utf-8 -*-
import io

p = r'C:\Users\xilisi\Doubao\chats\2026-09-27\new-chat\baona-app\lib\chat.dart'
s = io.open(p, encoding='utf-8').read()

# 1. import
old_imp = "import 'api.dart';\nimport 'main.dart';"
new_imp = "import 'api.dart';\nimport 'main.dart';\nimport 'msglocal.dart';"
assert old_imp in s, 'import fail'
s = s.replace(old_imp, new_imp)

# 2. _load 整体替换
old_load = """  Future<void> _load({bool more = false}) async {
    final a = app.api;
    if (a == null) return;
    // ★2026-09-30 加载更多：记下"当前第一条"和"当前滚动位置"，
    //   回来后在头部插新消息，并把位置补偿回原位（以前 clear+addAll → 列表整个重建 → 乱跳）
    final oldFirstKey = _msgs.isNotEmpty ? (_msgs.first.cid ?? 'i${_msgs.first.idx}') : null;
    final oldOffset = _sc.hasClients ? _sc.position.pixels : 0.0;
    final oldCount = _msgs.length;
    if (more) _limit += 30;
    final j = await a.history(limit: _limit);
    if (!mounted) return;
    final list = ((j['messages'] as List?) ?? []).map((e) => Msg.fromJson(Map.from(e))).toList();
    setState(() {
      _msgs
        ..clear()
        ..addAll(list);
      _hasMore = j['hasMore'] == true;
      _loading = false;
    });
    if (more && _sc.hasClients) {
      // 新消息插在头部 → 旧列表第一条下移了 → 按"新增条数 × 平均行高"把位置补回去
      final added = _msgs.length - oldCount;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_sc.hasClients) return;
        final target = (oldOffset + added * 46).clamp(0.0, _sc.position.maxScrollExtent);
        try { _sc.jumpTo(target); } catch (e) { /* ignore */ }
      });
    } else if (!more) {
      _toBottom();
    }
  }"""

new_load = """  Future<void> _load({bool more = false}) async {
    final a = app.api;
    // ★2026-09-30 本地缓存：打开先读本地秒开 —— 断网也能看历史
    if (!more && _msgs.isEmpty) {
      final cached = await MsgsLocal.load('baona');
      if (cached.isNotEmpty && mounted) {
        setState(() {
          _msgs
            ..clear()
            ..addAll(cached);
          _loading = false;
          _hasMore = false; // 离线时先不显示"加载更多"
        });
        _toBottom();
      }
    }
    if (a == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    // ★2026-09-30 加载更多：记下"当前第一条"和"当前滚动位置"，
    //   回来后在头部插新消息，并把位置补偿回原位（以前 clear+addAll → 列表整个重建 → 乱跳）
    final oldFirstKey = _msgs.isNotEmpty ? (_msgs.first.cid ?? 'i${_msgs.first.idx}') : null;
    final oldOffset = _sc.hasClients ? _sc.position.pixels : 0.0;
    final oldCount = _msgs.length;
    if (more) _limit += 30;
    Map<String, dynamic>? j;
    try {
      j = await a.history(limit: _limit);
    } catch (_) {
      // 断网：本地缓存已经显示了，安静地停在这里（不弹错、不打断）
      if (mounted) setState(() => _loading = false);
      return;
    }
    if (!mounted) return;
    final list = ((j['messages'] as List?) ?? []).map((e) => Msg.fromJson(Map.from(e))).toList();
    setState(() {
      _msgs = MsgsLocal.merge(list, _msgs);
      _hasMore = j['hasMore'] == true;
      _loading = false;
    });
    // ★同步成功 → 落盘，下次打开/断网直接看本地
    MsgsLocal.save('baona', _msgs);
    if (more && _sc.hasClients) {
      // 新消息插在头部 → 旧列表第一条下移了 → 按"新增条数 × 平均行高"把位置补回去
      final added = _msgs.length - oldCount;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_sc.hasClients) return;
        final target = (oldOffset + added * 46).clamp(0.0, _sc.position.maxScrollExtent);
        try { _sc.jumpTo(target); } catch (e) { /* ignore */ }
      });
    } else if (!more) {
      _toBottom();
    }
  }"""
assert old_load in s, 'load match fail'
s = s.replace(old_load, new_load)

# 3. _onEvent msg 分支：新消息后落盘
old_msg = """      _toBottom();
    } else if (t == 'msg-patch') {"""
new_msg = """      _toBottom();
      // ★本地缓存跟上（不然缓存停在旧位置，下次打开少几条）
      MsgsLocal.save('baona', _msgs);
    } else if (t == 'msg-patch') {"""
assert old_msg in s, 'msg cache fail'
s = s.replace(old_msg, new_msg)

# 4. _onEvent cleared 分支：清缓存
old_clr = """    } else if (t == 'cleared') {
      setState(() => _msgs.clear());
    }"""
new_clr = """    } else if (t == 'cleared') {
      setState(() => _msgs.clear());
      MsgsLocal.clear('baona');
    }"""
assert old_clr in s, 'cleared fail'
s = s.replace(old_clr, new_clr)

# 5. _send：乐观消息落盘
old_send = """    setState(() {
      _msgs.add(m);
      _emojiPanel = false;
      _funPanel = false;
    });
    _toBottom(force: true);"""
new_send = """    setState(() {
      _msgs.add(m);
      _emojiPanel = false;
      _funPanel = false;
    });
    MsgsLocal.save('baona', _msgs); // ★本地先存，万一没发出去/断网也留着
    _toBottom(force: true);"""
assert old_send in s, 'send fail'
s = s.replace(old_send, new_send)

io.open(p, 'w', encoding='utf-8', newline='').write(s)
print('chat.dart 本地缓存改造完成')
