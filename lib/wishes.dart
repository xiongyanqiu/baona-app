// 包娜 App · 「愿望」页：她答应老公的愿望 / 已完成 / 愿望清单
import 'package:flutter/material.dart';

import 'main.dart';
import 'theme.dart';

class WishesPage extends StatefulWidget {
  const WishesPage({super.key});

  @override
  State<WishesPage> createState() => _WishesPageState();
}

class _W {
  final String id, text, status;
  final int t, grantedAt, doneAt;
  _W({required this.id, required this.text, required this.status, required this.t, required this.grantedAt, required this.doneAt});
  factory _W.fromJson(Map e) => _W(
        id: String(e['id'] ?? ''),
        text: String(e['text'] ?? ''),
        status: String(e['status'] ?? 'pending'),
        t: (e['t'] as num?)?.toInt() ?? 0,
        grantedAt: (e['grantedAt'] as num?)?.toInt() ?? 0,
        doneAt: (e['doneAt'] as num?)?.toInt() ?? 0,
      );
  bool get isDone => status == 'done';
}

class _WishesPageState extends State<WishesPage> {
  int _granted = 0, _used = 0, _done = 0, _pending = 0;
  List<_W> _wishes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final a = app.api;
    if (a == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final r = await a.get('/api/wishes');
      if (!mounted) return;
      setState(() {
        _granted = (r['granted'] as num?)?.toInt() ?? 0;
        _used = (r['used'] as num?)?.toInt() ?? 0;
        _done = (r['done'] as num?)?.toInt() ?? 0;
        _pending = (r['pending'] as num?)?.toInt() ?? 0;
        _wishes = ((r['wishes'] as List?) ?? []).map((e) => _W.fromJson(Map.from(e))).toList();
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _action(String act, String val, String ok) async {
    final a = app.api;
    if (a == null) return;
    try {
      await a.post('/api/wishes/action', {'act': act, 'val': val});
      await _load();
      if (mounted) toast(context, ok);
    } catch (e) {
      if (mounted) toast(context, '没成功');
    }
  }

  void _confirmDelete(_W w) {
    showDialog(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: kBg2,
        title: const Text('删掉这个愿望？', style: TextStyle(fontSize: 16)),
        content: Text(w.text, style: const TextStyle(fontSize: 13, color: kSub)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('取消', style: TextStyle(color: kSub))),
          TextButton(
              onPressed: () { Navigator.pop(d); _action('remove', w.id, '删掉了'); },
              child: const Text('删除', style: TextStyle(color: kBad))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final remain = _granted - _used;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: EdgeInsets.fromLTRB(14, 6, 14, navSpace(context) + 24),
        children: [
          const Sec('愿望'),
          Glass(
            pad: const EdgeInsets.fromLTRB(16, 18, 16, 16),
            child: Column(children: [
              Row(children: [
                Expanded(child: _big(Icons.auto_awesome, _pending, '她答应我的', kAccent)),
                Container(width: 1, height: 58, color: kLine),
                Expanded(child: _big(Icons.check_circle_outline, _done, '已完成', kOk)),
              ]),
              const SizedBox(height: 14),
              const Hair(),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _mini('累计答应', _granted),
                _dot(),
                _mini('已用', _used),
                _dot(),
                _mini('还能许', remain < 0 ? 0 : remain),
              ]),
            ]),
          ),
          Sec('答应过我的愿望', trail: Text('${_wishes.length} 条', style: const TextStyle(fontSize: 11.5, color: kSub))),
          if (_wishes.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 42),
              child: Column(children: [
                const Icon(Icons.auto_awesome_outlined, size: 42, color: kSub),
                const SizedBox(height: 12),
                const Text('她还没答应过你的愿望', style: TextStyle(color: kSub, fontSize: 13)),
                const SizedBox(height: 4),
                const Text('去聊天里跟她说“我想要…”', style: TextStyle(color: kSub, fontSize: 12)),
              ]),
            ),
          for (final w in _wishes) _card(w),
        ],
      ),
    );
  }

  Widget _big(IconData ico, int n, String label, Color c) => Column(children: [
        Icon(ico, color: c, size: 26),
        const SizedBox(height: 8),
        Text('$n', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: c, height: 1)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: kSub)),
      ]);

  Widget _mini(String l, int n) => Row(mainAxisSize: MainAxisSize.min, children: [
        Text(l, style: const TextStyle(fontSize: 12, color: kSub)),
        const SizedBox(width: 5),
        Text('$n', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kText)),
      ]);

  Widget _dot() => const Padding(
      padding: EdgeInsets.symmetric(horizontal: 12), child: Text('·', style: TextStyle(color: kSub)));

  Widget _card(_W w) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPress: () => _confirmDelete(w),
        child: Glass(
          pad: const EdgeInsets.all(12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(w.isDone ? Icons.check_circle : Icons.radio_button_unchecked, size: 20, color: w.isDone ? kOk : kAccent),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(w.text, style: TextStyle(fontSize: 14.5, height: 1.4, color: w.isDone ? kSub : kText)),
                const SizedBox(height: 5),
                Text(w.isDone ? ('完成于 ' + fmtClock(w.doneAt)) : ('答应于 ' + fmtClock(w.grantedAt)),
                    style: const TextStyle(fontSize: 11, color: kSub)),
              ]),
            ),
            if (!w.isDone) ...[
              const SizedBox(width: 8),
              PressScale(
                radius: kRCapsule,
                onTap: () => _action('done', w.id, '标记完成啦'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                  decoration: BoxDecoration(color: kAccent, borderRadius: BorderRadius.circular(kRCapsule)),
                  child: const Text('完成', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}
