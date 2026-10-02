// 包娜 App · 群聊页（姐妹聊天群）：微信式群聊 —— 包娜和刘紫灵在一个群里，你说话她们依次接
// ★与单聊完全隔离：独立上下文/本地缓存/事件流过滤，第三个分支
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'main.dart';
import 'msglocal.dart';
import 'theme.dart';

class GroupChatPage extends StatefulWidget {
  const GroupChatPage({super.key, this.gid});
  final String? gid; // 群 id（空 = 默认姐妹聊天群）
  @override
  State<GroupChatPage> createState() => _GroupChatPageState();
}

class _GroupChatPageState extends State<GroupChatPage> {
  String get _gid => widget.gid ?? 'nvg';
  late String _cacheKey;
  String _gname = '姐妹聊天群';
  final List<Msg> _msgs = [];
  final Map<String, Map<String, String>> _mPrefs = {}; // roleId -> {name, avatar}
  bool _loading = true;
  bool _typing = false;
  bool _hasMore = false;
  bool _busy = false;
  int _limit = 50;
  final _inp = TextEditingController();
  final _sc = ScrollController();
  final _focus = FocusNode();
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _cacheKey = 'group.$_gid';
    // 成员显示名/头像：本地优先（改过备注/头像就显示改过的）
    SharedPreferences.getInstance().then((sp) {
      final n = sp.getString('group.$_gid.name') ?? '';
      if (n.isNotEmpty && mounted) setState(() => _gname = n);
      for (final rid in ['baona', 'liuziling']) {
        final nm = sp.getString('role.$rid.name') ?? '';
        final av = sp.getString('role.$rid.avatar') ?? '';
        if ((nm.isNotEmpty || av.isNotEmpty) && mounted) {
          setState(() => _mPrefs[rid] = {'name': nm, 'avatar': av});
        }
      }
    });
    _loadLocal();
    _loadHistory();
    _sub = app.api?.events.listen(_onEvent);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _inp.dispose();
    _sc.dispose();
    _focus.dispose();
    super.dispose();
  }

  String _memberName(String rid) {
    final p = _mPrefs[rid];
    if (p != null && (p['name'] ?? '').isNotEmpty) return p['name']!;
    if (rid == 'baona') return app.nick;
    if (rid == 'liuziling') return '刘紫灵';
    return rid;
  }

  String _memberAvatar(String rid) => _mPrefs[rid]?['avatar'] ?? '';

  String _memberLetter(String rid) {
    if (rid == 'baona') return '娜';
    if (rid == 'liuziling') return '灵';
    return rid.isEmpty ? '群' : rid[0];
  }

  Future<void> _loadLocal() async {
    final local = await MsgsLocal.load(_cacheKey);
    if (!mounted) return;
    setState(() {
      _msgs
        ..clear()
        ..addAll(local);
    });
  }

  Future<void> _loadHistory({bool more = false}) async {
    if (more && _busy) return;
    _busy = true;
    try {
      final j = await app.api?.groupHistory(_gid, limit: more ? _limit : 50);
      if (!mounted) return;
      final list = (((j ?? {})['history'] as List?) ?? [])
          .map((e) => Msg.fromJson(Map.from(e)))
          .toList();
      setState(() {
        if (more) {
          final oldCount = _msgs.length;
          _msgs.insertAll(0, list);
          final added = list.length;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || !_sc.hasClients) return;
            try { _sc.jumpTo((_sc.position.pixels + added * 48).clamp(0.0, _sc.position.maxScrollExtent)); } catch (_) {}
          });
          _hasMore = list.isNotEmpty && list.length >= _limit;
          _limit += 50;
        } else {
          _msgs
            ..clear()
            ..addAll(MsgsLocal.merge(list, _msgs));
          _hasMore = list.length >= 50;
          _loading = false;
        }
      });
      MsgsLocal.save(_cacheKey, _msgs);
      if (!more) _toBottom();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    } finally {
      _busy = false;
    }
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_sc.hasClients) return;
      _sc.jumpTo(_sc.position.maxScrollExtent);
    });
  }

  void _onEvent(Map<String, dynamic> e) {
    final t = '${e['type']}';
    if (t != 'msg') return;
    final raw = e['msg'];
    final body = raw is Map ? Map<String, dynamic>.from(raw) : e;
    // ★群聊分流：只收自己这个群的消息（单聊/角色消息不进群）
    final gid = '${body['groupId'] ?? ''}';
    if (gid != _gid) return;
    final m = Msg.fromJson(body);
    if (m.role == 'user' || m.role == 'me') m.role = 'me';
    final hasSomething = m.content.isNotEmpty || (m.sticker?.isNotEmpty ?? false);
    if (!hasSomething) return;
    // 防重：自己发的（已乐观显示）或内容+发言者重复的群消息不重复画
    final dup = _msgs.any((x) => x.roleId == m.roleId && x.content == m.content && x.role == m.role);
    if (dup) return;
    setState(() {
      _msgs.add(m);
      _typing = false;
    });
    _toBottom();
    MsgsLocal.save(_cacheKey, _msgs);
  }

  Future<void> _sendText() async {
    final t = _inp.text.trim();
    if (t.isEmpty || _busy) return;
    _inp.clear();
    _busy = true;
    // 乐观显示自己的话
    final me = Msg(role: 'me', content: t, time: DateTime.now().millisecondsSinceEpoch, st: 'ok');
    setState(() {
      _msgs.add(me);
      _typing = true;
    });
    _toBottom();
    try {
      final j = await app.api?.groupSend(_gid, t);
      final ok = j?['ok'] == true;
      final replies = ((j ?? {})['replies'] as List?) ?? [];
      if (!mounted) return;
      if (!ok) {
        setState(() {
          _msgs.lastWhere((x) => identical(x, me)).st = 'failed';
          _typing = false;
        });
      } else if (replies.isNotEmpty) {
        final now = DateTime.now().millisecondsSinceEpoch;
        final add = <Msg>[];
        for (final r in replies) {
          final rid = '${r['roleId'] ?? ''}';
          final nm = '${r['name'] ?? ''}';
          final c = '${r['content'] ?? ''}';
          final parts = c.split('\n').where((x) => x.trim().isNotEmpty).toList();
          for (var i = 0; i < parts.length; i++) {
            add.add(Msg(role: 'assistant', content: parts[i].trim(), time: now + i, roleId: rid, name: nm));
          }
        }
        setState(() {
          for (final m in add) {
            final dup = _msgs.any((x) => x.roleId == m.roleId && x.content == m.content && x.role == m.role);
            if (!dup) _msgs.add(m);
          }
          _typing = false;
        });
      } else {
        setState(() => _typing = false);
      }
      MsgsLocal.save(_cacheKey, _msgs);
      _toBottom();
    } catch (_) {
      if (mounted) setState(() => _typing = false);
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = app.api;
    if (a == null) return const Center(child: CircularProgressIndicator());
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Wall(
        url: app.bg,
        blur: app.bgBlur,
        opacity: app.bgOpacity,
        child: Column(children: [
          _GroupHeader(
            gname: _gname,
            onBack: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : GestureDetector(
                    onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
                    behavior: HitTestBehavior.opaque,
                    child: ListView.builder(
                      controller: _sc,
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: EdgeInsets.fromLTRB(14, 8, 14, kbUp(context) ? 16 : MediaQuery.of(context).padding.bottom + 16),
                      itemCount: _msgs.length + (_typing ? 1 : 0) + (_hasMore ? 1 : 0),
                      itemBuilder: (c, i) {
                        if (_hasMore && i == 0) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: InkWell(
                              onTap: () => _loadHistory(more: true),
                              child: const Center(child: Text('往上滑加载更早的', style: TextStyle(fontSize: 11.5, color: kSub))),
                            ),
                          );
                        }
                        final k = i - (_hasMore ? 1 : 0);
                        if (k >= _msgs.length) return const _GroupTyping();
                        final m = _msgs[k];
                        final prev = k > 0 ? _msgs[k - 1] : null;
                        final gap = prev == null || (m.time != null && prev.time != null && (m.time! - prev.time!) > 30 * 60 * 1000);
                        final b = _GroupBubble(m: m, name: _memberName('${m.roleId ?? ''}'), avatar: _memberAvatar('${m.roleId ?? ''}'), letter: _memberLetter('${m.roleId ?? ''}'));
                        if (!gap) return b;
                        return Column(children: [
                          if (m.time != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 10, bottom: 2),
                              child: Text(fmtDay(m.time!), style: const TextStyle(fontSize: 11, color: kSub)),
                            ),
                          b,
                        ]);
                      },
                    ),
                  ),
          ),
          Padding(
            padding: EdgeInsets.only(bottom: kbUp(context) ? 6 : MediaQuery.of(context).padding.bottom + 10),
            child: _GroupComposer(
              ctl: _inp,
              focus: _focus,
              onSend: _sendText,
              canSend: !_busy,
            ),
          ),
        ]),
      ),
    );
  }
}

/* ------------------------------- 头部 ------------------------------- */
class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.gname, required this.onBack});
  final String gname;
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context) {
    final a = app;
    return Container(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 4, bottom: 6),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0x14FFFFFF), Color(0x00FFFFFF)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
      ),
      child: Row(children: [
        IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Colors.white),
        ),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(gname, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
            Text('${a.nick} · 刘紫灵 在群里', style: const TextStyle(color: Colors.white70, fontSize: 11.5)),
          ]),
        ),
      ]),
    );
  }
}

/* ------------------------------- 消息气泡（微信式群聊） ------------------------------- */
class _GroupBubble extends StatelessWidget {
  const _GroupBubble({required this.m, required this.name, required this.avatar, required this.letter});
  final Msg m;
  final String name;
  final String avatar;
  final String letter;
  @override
  Widget build(BuildContext context) {
    final me = m.role == 'me';
    final showName = !me && (m.name?.isNotEmpty ?? false);
    final nm = showName ? name : '';
    if (me) {
      // 我：右侧气泡，无头像无名字（微信式）
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(top: 5, bottom: 1),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.66),
          decoration: BoxDecoration(
            color: const Color(0xFF2E7CF6),
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(6), bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
            boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 6, offset: Offset(0, 1))],
          ),
          child: Text(m.content, style: const TextStyle(color: Colors.white, fontSize: 15.5, height: 1.35)),
        ),
      );
    }
    // 群成员：左侧头像 + 名字 + 气泡
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 1),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _GroupAvatar(avatar: avatar, letter: letter),
        const SizedBox(width: 8),
        Flexible(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (nm.isNotEmpty) Padding(
              padding: const EdgeInsets.only(bottom: 2, left: 2),
              child: Text(nm, style: const TextStyle(fontSize: 11.5, color: Colors.white60)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFF3A3A44),
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(6), topRight: Radius.circular(16), bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
              ),
              child: Text(m.content, style: const TextStyle(color: Colors.white, fontSize: 15.5, height: 1.35)),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _GroupAvatar extends StatelessWidget {
  const _GroupAvatar({required this.avatar, required this.letter});
  final String avatar;
  final String letter;
  @override
  Widget build(BuildContext context) {
    if (avatar.isNotEmpty) {
      return ClipOval(
        child: Image.network(avatar, width: 36, height: 36, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _default()),
      );
    }
    return _default();
  }
  Widget _default() {
    return Container(
      width: 36, height: 36,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: [Color(0xFF8E7CF6), Color(0xFF4AA8FF)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      alignment: Alignment.center,
      child: Text(letter, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
    );
  }
}

/* ------------------------------- 输入栏 ------------------------------- */
class _GroupComposer extends StatelessWidget {
  const _GroupComposer({required this.ctl, required this.focus, required this.onSend, required this.canSend});
  final TextEditingController ctl;
  final FocusNode focus;
  final VoidCallback onSend;
  final bool canSend;
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
      decoration: BoxDecoration(
        color: const Color(0x332A2A33),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x22FFFFFF)),
      ),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: ctl,
            focusNode: focus,
            minLines: 1,
            maxLines: 4,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => onSend(),
            style: const TextStyle(color: Colors.white, fontSize: 15.5),
            cursorColor: Colors.white,
            decoration: const InputDecoration(
              hintText: '发消息给姐妹们…',
              hintStyle: TextStyle(color: Colors.white38, fontSize: 15),
              border: InputBorder.none,
              isDense: true,
            ),
          ),
        ),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: canSend ? onSend : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 7),
            decoration: BoxDecoration(
              color: canSend ? const Color(0xFF2E7CF6) : const Color(0xFF3A3A44),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Text('发送', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
          ),
        ),
      ]),
    );
  }
}

class _GroupTyping extends StatelessWidget {
  const _GroupTyping();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 8, left: 44),
      child: Text('她们正在打字…', style: TextStyle(fontSize: 12.5, color: Colors.white54)),
    );
  }
}
