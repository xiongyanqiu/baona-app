// msg.dart — 包娜 App v27 消息区：仅包娜一人的聊天对话页
// 设计：iOS 27 Liquid Glass + 系统色（无紫色底板）
// 布局：左上角=名字+头像（她的，点击可换）；右上角=设置（对话/记忆/头像）；
//       每条消息带头像：我的在右侧（我的头像，可换）、她在左侧（她的头像）
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'api.dart';
import 'main.dart';
import 'msglocal.dart';
import 'theme.dart';

class MsgPage extends StatefulWidget {
  const MsgPage({super.key});

  @override
  State<MsgPage> createState() => _MsgPageState();
}

class _MsgPageState extends State<MsgPage> {
  List<Msg> _msgs = [];
  bool _loading = true;
  bool _typing = false;
  int _memCount = 0;
  int _cidSeq = 0;
  final TextEditingController _inp = TextEditingController();
  final ScrollController _sc = ScrollController();
  StreamSubscription<Map<String, dynamic>>? _sub;

  dynamic get _a => app.brain ?? app.api;

  @override
  void initState() {
    super.initState();
    _load();
    _sub = _a?.events.listen(_onEv);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _inp.dispose();
    _sc.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final a = _a;
    if (a == null) return;
    final r = await a.history(limit: 300);
    final list = (r['messages'] as List?) ?? [];
    if (mounted) {
      setState(() {
        _msgs = list.map((m) => Msg.fromJson(Map<String, dynamic>.from(m))).toList();
        _loading = false;
      });
      _jumpBottom(instant: true);
    }
    try {
      final mr = await a.memories();
      if (mounted) setState(() => _memCount = (mr['count'] as num?)?.toInt() ?? 0);
    } catch (_) {}
  }

  void _onEv(Map<String, dynamic> e) {
    final t = '${e['type'] ?? ''}';
    if (t == 'msg') {
      final m = e['msg'];
      if (m is Map) {
        final msg = Msg.fromJson(Map<String, dynamic>.from(m));
        // 防重复：本地 pending 是自己画的那条（cid 不同），assistant 广播直接加
        setState(() => _msgs.add(msg));
        _jumpBottom();
      }
    } else if (t == 'typing') {
      setState(() => _typing = e['on'] == true);
    } else if (t == 'cleared') {
      setState(() => _msgs.clear());
    }
  }

  void _jumpBottom({bool instant = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_sc.hasClients) return;
      try {
        _sc.animateTo(_sc.position.maxScrollExtent,
            duration: instant ? Duration.zero : const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic);
      } catch (_) {}
    });
  }

  Future<void> _send() async {
    final a = _a;
    final t = _inp.text.trim();
    if (a == null || t.isEmpty) return;
    _inp.clear();
    try {
      HapticFeedback.lightImpact();
    } catch (_) {}
    final cid = 'c${DateTime.now().millisecondsSinceEpoch}-${++_cidSeq}';
    final m = Msg(role: 'me', content: t, st: 'pending', time: DateTime.now().millisecondsSinceEpoch, cid: cid);
    setState(() => _msgs.add(m));
    await MsgsLocal.save('baona', _msgs);
    _jumpBottom();
    final r = await a.send({'text': t, 'cid': cid});
    if (mounted) {
      setState(() => m.st = r['ok'] == true ? 'ok' : 'failed');
      await MsgsLocal.save('baona', _msgs);
      if (r['ok'] != true) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('发送失败：${r['error'] ?? '未知错误'}'),
            behavior: SnackBarBehavior.floating));
      }
    }
  }

  // ---------- 头像 ----------
  Future<void> _pickAvatar(String who) async {
    final a = _a;
    if (a == null) return;
    try {
      final p = await ImagePicker()
          .pickImage(source: ImageSource.gallery, maxWidth: 512, imageQuality: 80);
      if (p == null) return;
      final bytes = await p.readAsBytes();
      final dataUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      final key = who == 'her' ? 'herAvatar' : 'myAvatar';
      await a.patchSettings({'patch': {key: dataUrl}});
      if (mounted) {
        setState(() => app.herSet[key] = dataUrl);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('选图失败：$e'), behavior: SnackBarBehavior.floating));
      }
    }
  }

  // ---------- 设置弹窗（对话 / 记忆 / 头像） ----------
  Future<void> _openSettings() async {
    final a = _a;
    if (a == null) return;
    await showModalBottomSheet(
      context: context,
      backgroundColor: kBg2, // secondarySystemBackground
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (c) => SafeArea(
        child: StatefulBuilder(
          builder: (c, setSt) => Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Text('设置',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(c),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0x33FFFFFF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, size: 16, color: kSub),
                  ),
                ),
              ]),
              const SizedBox(height: 14),
              _sec('对话'),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.delete_outline, color: kBad),
                title: const Text('清空聊天记录', style: TextStyle(fontSize: 15)),
                trailing: const Icon(Icons.chevron_right, size: 18, color: kSub),
                onTap: () async {
                  final ok = await _confirm(c, '清空聊天记录', '和包娜的聊天记录会全部删掉，确定吗？');
                  if (ok == true) {
                    await a.clearChat();
                    setSt(() => _msgs.clear());
                  }
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  const Text('字号', style: TextStyle(fontSize: 15)),
                  Expanded(
                    child: Slider(
                      value: app.fontSize.clamp(13, 20),
                      min: 13,
                      max: 20,
                      divisions: 7,
                      activeColor: kAccent,
                      inactiveColor: const Color(0x33FFFFFF),
                      onChanged: (v) => app.put('fontSize', v.round()),
                    ),
                  ),
                  Text('${app.fontSize.round()}', style: const TextStyle(fontSize: 13, color: kSub)),
                ]),
              ),
              const Divider(height: 18, color: kHair),
              _sec('她的记忆'),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.memory, color: kAccent),
                title: Text('她脑子里记着 $_memCount 条', style: const TextStyle(fontSize: 15)),
                subtitle: const Text('她会自己总结对话存进长期记忆，也能手动清'),
                trailing: const Icon(Icons.chevron_right, size: 18, color: kSub),
                onTap: () => _showMemories(c),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.delete_sweep, color: kBad),
                title: const Text('清掉她的长期记忆', style: TextStyle(fontSize: 15, color: kBad)),
                onTap: () async {
                  final ok = await _confirm(c, '清掉她的长期记忆', '她记着的所有事都会忘掉，确定吗？');
                  if (ok == true) {
                    await a.memoryClear();
                    setSt(() => _memCount = 0);
                  }
                },
              ),
              const Divider(height: 18, color: kHair),
              _sec('头像'),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.face_retouching_natural, color: kAccent),
                title: const Text('换她的头像', style: TextStyle(fontSize: 15)),
                subtitle: const Text('左上角和她的消息旁边都会换'),
                trailing: const Icon(Icons.chevron_right, size: 18, color: kSub),
                onTap: () async {
                  Navigator.pop(c);
                  await _pickAvatar('her');
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.person_outline, color: kAccent),
                title: const Text('换我的头像', style: TextStyle(fontSize: 15)),
                subtitle: const Text('我的消息旁边显示的头像'),
                trailing: const Icon(Icons.chevron_right, size: 18, color: kSub),
                onTap: () async {
                  Navigator.pop(c);
                  await _pickAvatar('my');
                },
              ),
              const SizedBox(height: 6),
            ]),
          ),
        ),
      ),
    );
  }

  /// 记忆列表弹窗
  Future<void> _showMemories(BuildContext c) async {
    final a = _a;
    if (a == null) return;
    final r = await a.memories();
    final items = (r['items'] as List?) ?? [];
    if (!mounted) return;
    showModalBottomSheet(
      context: c,
      backgroundColor: kBg2,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (cc) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Text('她的长期记忆',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.pop(cc),
                child: Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(color: const Color(0x33FFFFFF), shape: BoxShape.circle),
                  child: const Icon(Icons.close, size: 16, color: kSub),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: Center(child: Text('还没记住什么，聊着聊着她就会自己记了', style: TextStyle(color: kSub, fontSize: 13.5))),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 14, color: kHair),
                  itemBuilder: (_, i) {
                    final it = items[i];
                    return Row(children: [
                      const Icon(Icons.fiber_manual_record, size: 8, color: kAccent),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text('${it['text'] ?? ''}',
                            style: const TextStyle(fontSize: 14, height: 1.4)),
                      ),
                    ]);
                  },
                ),
              ),
          ]),
        ),
      ),
    );
  }

  Widget _sec(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(t.toUpperCase(),
            style: const TextStyle(
                fontSize: 11.5, color: kSub, letterSpacing: 0.9, fontWeight: FontWeight.w600)),
      );

  Future<bool?> _confirm(BuildContext c, String title, String msg) => showDialog<bool>(
        context: c,
        builder: (cc) => AlertDialog(
          backgroundColor: kBg2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          content: Text(msg, style: const TextStyle(fontSize: 14.5, height: 1.4)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(cc, false), child: const Text('取消', style: TextStyle(color: kSub))),
            TextButton(onPressed: () => Navigator.pop(cc, true), child: const Text('确定', style: TextStyle(color: kBad, fontWeight: FontWeight.w600))),
          ],
        ),
      );

  // ---------- 界面 ----------
  @override
  Widget build(BuildContext context) {
    final herAv = '${app.herSet['herAvatar'] ?? ''}';
    final myAv = '${app.herSet['myAvatar'] ?? ''}';
    return Wall(
      url: app.bg,
      blur: app.bgBlur,
      opacity: app.bgOpacity,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(children: [
          // 顶栏：左上角 名字+头像；右上角 设置
          GlassBar(
            top: true,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 6, 10, 6),
                child: Row(children: [
                  GestureDetector(
                    onTap: () => _pickAvatar('her'),
                    child: _Av(av: herAv, size: 38, fallback: '娜'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(app.nick, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, letterSpacing: -0.2)),
                        const SizedBox(height: 2),
                        Row(children: [
                          Container(
                              width: 6, height: 6,
                              decoration: BoxDecoration(
                                  color: const Color(0xFF30D158), shape: BoxShape.circle)),
                          const SizedBox(width: 5),
                          const Text('包娜在线',
                              style: TextStyle(fontSize: 11.5, color: kSub)),
                        ]),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _openSettings,
                    icon: const Icon(Icons.settings_outlined, size: 21),
                    tooltip: '设置',
                  ),
                ]),
              ),
            ),
          ),
          // 消息列表
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: kAccent))
                : ListView.builder(
                    controller: _sc,
                    padding: EdgeInsets.only(top: 10, bottom: navSpace(context) + 6),
                    itemCount: _msgs.length + (_typing ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (i >= _msgs.length) return _TypingRow();
                      return _row(_msgs[i], herAv, myAv);
                    },
                  ),
          ),
          // 输入栏（玻璃胶囊）
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
              child: GlassSurface(
                radius: kRCapsule,
                blur: kBlur,
                pad: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                child: Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _inp,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      style: const TextStyle(fontSize: 16, color: kText),
                      decoration: const InputDecoration(
                        hintText: '跟包娜说点什么…',
                        hintStyle: TextStyle(color: kSub, fontSize: 15.5),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: _send,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: kAccent,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: kAccent.withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 3)),
                        ],
                      ),
                      child: const Icon(Icons.arrow_upward_rounded, size: 20, color: Colors.white),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _row(Msg m, String herAv, String myAv) {
    final me = m.role == 'me';
    final bubble = Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.68),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: me ? kAccent : kBg2,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(me ? 18 : 6),
          topRight: Radius.circular(me ? 6 : 18),
          bottomLeft: const Radius.circular(18),
          bottomRight: const Radius.circular(18),
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(m.content,
            style: TextStyle(
                fontSize: app.fontSize, height: 1.35, color: me ? Colors.white : kText)),
        const SizedBox(height: 3),
        Text(_hm(m.time ?? 0),
            style: TextStyle(fontSize: 10, color: me ? Colors.white.withValues(alpha: 0.7) : kSub)),
        if (m.st == 'failed')
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Text('发送失败', style: TextStyle(fontSize: 10.5, color: Color(0xFFFF453A))),
          ),
      ]),
    );
    final avatar = _Av(av: me ? myAv : herAv, size: 34, fallback: me ? '我' : '娜');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: me
            ? [const Spacer(), Flexible(child: bubble), const SizedBox(width: 8), avatar]
            : [avatar, const SizedBox(width: 8), Flexible(child: bubble), const Spacer()],
      ),
    );
  }

  String _hm(int t) {
    if (t <= 0) return '';
    final d = DateTime.fromMillisecondsSinceEpoch(t);
    final h = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '$h:$mm';
  }

  Widget _TypingRow() => const Padding(
        padding: EdgeInsets.fromLTRB(14, 8, 14, 8),
        child: Row(children: [
          SizedBox(width: 34),
          SizedBox(width: 8),
          Text('她正在输入…', style: TextStyle(fontSize: 13, color: kSub)),
        ]),
      );
}

/// 圆形头像：同 URL 走 avatarOf 缓存（不闪回占位字）
class _Av extends StatelessWidget {
  const _Av({required this.av, required this.size, required this.fallback});
  final String av;
  final double size;
  final String fallback;

  @override
  Widget build(BuildContext context) {
    final p = av.isEmpty ? null : avatarOf(av);
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: kBg2,
        border: Border.all(color: const Color(0x33FFFFFF), width: 0.8),
      ),
      child: p == null
          ? Center(
              child: Text(fallback,
                  style: TextStyle(fontSize: size * 0.42, fontWeight: FontWeight.w600, color: kText)))
          : Image(
              image: p,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) => Center(
                  child: Text(fallback,
                      style: TextStyle(fontSize: size * 0.42, fontWeight: FontWeight.w600, color: kText))),
            ),
    );
  }
}
