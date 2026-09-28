// 包娜 App · 情侣飞行棋（48 格蛇形盘 + 掷骰子 + 换模式 + 改格子）
import 'dart:async';

import 'package:flutter/material.dart';

import 'api.dart';
import 'main.dart';
import 'theme.dart';

class GamePage extends StatefulWidget {
  const GamePage({super.key});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  GameState? _g;
  bool _edit = false;
  bool _loading = true;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _load();
    _sub = app.api?.events.listen((e) {
      if ('${e['type']}' == 'game' && e['state'] is Map) {
        setState(() => _g = GameState.fromJson(Map.from(e['state'] as Map)));
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final a = app.api;
    if (a == null) return;
    final j = await a.game();
    if (!mounted) return;
    setState(() {
      if (j['state'] is Map) _g = GameState.fromJson(Map.from(j['state'] as Map));
      _loading = false;
    });
  }

  Future<void> _roll(String who) async {
    final a = app.api;
    if (a == null) return;
    final j = await a.gameRoll(who);
    if (!mounted) return;
    if (j['state'] is Map) {
      setState(() => _g = GameState.fromJson(Map.from(j['state'] as Map)));
    } else {
      toast(context, '掷不了：${j['error'] ?? '电脑端没接住'}');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final g = _g;
    if (g == null) return const Center(child: Text('棋盘没打开', style: TextStyle(color: kSub)));

    // 蛇形：48 格 → 6 列 × 8 行
    final cells = <int>[];
    for (var row = 0; row < 8; row++) {
      for (var pos = 0; pos < 6; pos++) {
        cells.add(row * 6 + (row.isEven ? pos + 1 : 6 - pos));
      }
    }
    final tileOf = <int, Tile>{for (final t in g.tiles) t.i: t};

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
        child: Row(children: [
          Glass(
            pad: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            radius: 10,
            child: Text('我 ${g.me} 格 · 她 ${g.her} 格 · 赢 ${g.winMe}:${g.winHer}', style: const TextStyle(fontSize: 11.5)),
          ),
          const SizedBox(width: 8),
          Chip2(_edit ? '编辑中（点格子改）' : '编辑格子', on2: _edit, on: () => setState(() => _edit = !_edit)),
          const Spacer(),
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh, size: 18)),
        ]),
      ),
      SizedBox(
        height: 40,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          children: [
            for (final m in g.modes)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Chip2('${m['name'] ?? m['id']}', on2: '${m['id']}' == g.mode, on: () async {
                  final a = app.api!;
                  final j = await a.gameMode('${m['id']}');
                  if (!mounted) return;
                  if (j['state'] is Map) {
                    setState(() => _g = GameState.fromJson(Map.from(j['state'] as Map)));
                    toast(context, '换成：${m['name'] ?? m['id']}');
                  } else {
                    toast(context, '换不了：${j['error'] ?? '电脑端没接住'}');
                  }
                }),
              ),
          ],
        ),
      ),
      if (g.winner != null)
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: kAccent.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(12), border: Border.all(color: kAccent)),
          child: Text('${g.winner == 'me' ? '我' : '她'}赢了！${g.prize == null ? '' : ' 奖品：${g.prize}'}', style: const TextStyle(fontSize: 13.5)),
        ),
      Expanded(
        child: GridView.count(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          crossAxisCount: 6,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          childAspectRatio: 0.82,
          children: [
            for (final i in cells)
              _Cell(
                i: i,
                t: tileOf[i]?.t ?? '$i',
                me: g.me == i,
                her: g.her == i,
                onTap: _edit
                    ? () async {
                        final c = TextEditingController(text: tileOf[i]?.t ?? '');
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (cc) => AlertDialog(
                            title: Text('第 $i 格内容'),
                            content: TextField(controller: c, decoration: const InputDecoration(hintText: '留空 = 恢复默认')),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(cc, false), child: const Text('算了')),
                              FilledButton(onPressed: () => Navigator.pop(cc, true), child: const Text('改')),
                            ],
                          ),
                        );
                        if (ok != true) return;
                        final j = await app.api!.gameTile(i, c.text.trim());
                        if (!mounted) return;
                        if (j['state'] is Map) {
                          setState(() => _g = GameState.fromJson(Map.from(j['state'] as Map)));
                          toast(context, '改好了');
                        } else {
                          toast(context, '改不了：${j['error'] ?? '电脑端没接住'}');
                        }
                      }
                    : null,
              ),
          ],
        ),
      ),
      Container(
        padding: EdgeInsets.fromLTRB(12, 8, 12, navSpace(context) + 10),
        decoration: const BoxDecoration(color: Color(0x1AFFFFFF), border: Border(top: BorderSide(color: kHair))),
        child: SafeArea(
          top: false,
          child: Column(children: [
            Row(children: [
              Expanded(
                child: FilledButton(
                  onPressed: () => _roll('me'),
                  child: Text(g.turn == 'me' ? '该我了 · 掷骰子' : '我也掷一下'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _roll('her'),
                  child: Text(g.turn == 'her' ? '该她了 · 让她掷' : '让她掷'),
                ),
              ),
            ]),
            if (g.log.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  g.log.reversed.take(3).map((x) => '${x['t'] ?? x['text'] ?? ''}').join('   '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, color: kSub),
                ),
              ),
          ]),
        ),
      ),
    ]);
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.i, required this.t, required this.me, required this.her, this.onTap});
  final int i;
  final String t;
  final bool me, her;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final hot = me || her;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: hot ? kAccent.withValues(alpha: 0.22) : kGlass,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: hot ? kAccent : kLine),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('$i', style: const TextStyle(fontSize: 8.5, color: kSub)),
            const Spacer(),
            if (me) const Text('我', style: TextStyle(fontSize: 9, color: kAccent2)),
            if (her) const Text('她', style: TextStyle(fontSize: 9, color: Color(0xFFFF9ECD))),
          ]),
          Expanded(
            child: Text(
              t,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 8.5, height: 1.15),
            ),
          ),
        ]),
      ),
    );
  }
}
