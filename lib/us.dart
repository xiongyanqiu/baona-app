// 包娜 App · 「我们」页：情侣空间 / 相册 / 她的记忆 / 她的本事
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'api.dart';
import 'main.dart';
import 'theme.dart';

class UsPage extends StatefulWidget {
  const UsPage({super.key});

  @override
  State<UsPage> createState() => _UsPageState();
}

class _UsPageState extends State<UsPage> {
  List<CplPost> _posts = [];
  int _memCount = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final a = app.api;
    if (a == null) return;
    final p = await a.couple();
    final mc = await a.get('/api/memory');
    final m = (mc['count'] as num?)?.toInt() ?? 0;
    if (!mounted) return;
    setState(() {
      _posts = ((p['posts'] as List?) ?? []).map((e) => CplPost.fromJson(Map.from(e))).toList();
      _memCount = m;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.fromLTRB(14, 6, 14, 24), children: [
        const Sec('我们的东西'),
        Row(children: [
          Expanded(child: _Tile(ico: Icons.photo_library_outlined, t: '相册', s: '里头的照片', on: () => openAlbum(context))),
          const SizedBox(width: 10),
          Expanded(child: _Tile(ico: Icons.psychology_outlined, t: '她的记忆', s: '$_memCount 条', on: () => openMemories(context))),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _Tile(ico: Icons.auto_awesome, t: '她的本事', s: '她能干的活', on: () => openSkills(context))),
          const SizedBox(width: 10),
          Expanded(child: _Tile(ico: Icons.insights_outlined, t: '她的心情', s: '${app.status}', on: () => openMood(context))),
        ]),

        const Sec('情侣空间（她发的说说）'),
        if (_posts.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Text('她还没发过说说', style: TextStyle(color: kSub, fontSize: 13))),
        for (final p in _posts)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: kGlass, borderRadius: BorderRadius.circular(14), border: Border.all(color: kLine)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(fmtClock(p.t), style: const TextStyle(fontSize: 11, color: kSub)),
              const SizedBox(height: 6),
              Text(p.text, style: const TextStyle(fontSize: 14, height: 1.5)),
              const SizedBox(height: 8),
              Row(children: [
                GestureDetector(
                  onTap: () async {
                    await app.api?.coupleLike(p.id);
                    _load();
                  },
                  child: Text('♥ ${p.likes}', style: const TextStyle(fontSize: 13, color: kAccent2)),
                ),
                const SizedBox(width: 14),
                Text('评论 ${p.comments.length}', style: const TextStyle(fontSize: 12.5, color: kSub)),
                const Spacer(),
                TextButton(
                  onPressed: () async {
                    final t = await _askText(context, '给她评论');
                    if (t.isEmpty) return;
                    await app.api?.coupleComment(p.id, t);
                    _load();
                  },
                  child: const Text('评论', style: TextStyle(fontSize: 12.5)),
                ),
              ]),
              for (final c in p.comments)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('${c['who'] == 'her' ? app.nick : '我'}：${c['text'] ?? ''}', style: const TextStyle(fontSize: 12.5, color: kSub)),
                ),
            ]),
          ),
      ]),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.ico, required this.t, required this.s, required this.on});
  final IconData ico;
  final String t, s;
  final VoidCallback on;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: on,
        child: Glass(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(ico, size: 20, color: kAccent2),
            const SizedBox(height: 8),
            Text(t, style: const TextStyle(fontSize: 14.5)),
            Text(s, style: const TextStyle(fontSize: 11.5, color: kSub)),
          ]),
        ),
      );
}

/* -------------------------------- 记忆 -------------------------------- */
Future<void> openMemories(BuildContext context) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF120F1B),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (c) => DraggableScrollableSheet(expand: false, initialChildSize: 0.85, builder: (c, s) => _Mem(scroll: s)),
  );
}

class _Mem extends StatefulWidget {
  const _Mem({required this.scroll});
  final ScrollController scroll;
  @override
  State<_Mem> createState() => _MemState();
}

class _MemState extends State<_Mem> {
  List<MemItem> _items = [];
  int _total = 0;
  bool _loading = true;
  bool _armed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final a = app.api;
    if (a == null) return;
    final j = await a.memories();
    final t = await a.get('/api/memory');
    if (!mounted) return;
    setState(() {
      _items = ((j['items'] as List?) ?? []).map((e) => MemItem.fromJson(Map.from(e))).toList();
      _total = (t['total'] as num?)?.toInt() ?? _items.length;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final inp = TextEditingController();
    return ListView(
      controller: widget.scroll,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
      children: [
        Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: kLine, borderRadius: BorderRadius.circular(4)))),
        Row(children: [
          const Text('她的记忆', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(width: 10),
          Text('记着 $_total 条', style: const TextStyle(fontSize: 12.5, color: kSub)),
          const Spacer(),
          IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, size: 20)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: TextField(controller: inp, decoration: const InputDecoration(hintText: '让她记住一件事…'))),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () async {
              final t = inp.text.trim();
              if (t.isEmpty) return;
              final r = await app.api?.memoryAdd(t);
              if (!mounted) return;
              if (r?['ok'] == true) {
                inp.clear();
                toast(context, '记住了');
                _load();
              } else {
                toast(context, '没记住');
              }
            },
            child: const Text('记'),
          ),
        ]),
        const Sec('她脑子里记着的'),
        if (_loading) const Center(child: CircularProgressIndicator()),
        for (final it in _items)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(color: kGlass, borderRadius: BorderRadius.circular(12), border: Border.all(color: kLine)),
            child: Row(children: [
              Expanded(child: Text(it.text, style: const TextStyle(fontSize: 13.5, height: 1.45))),
              IconButton(
                onPressed: () async {
                  final r = await app.api?.memoryRemove(it.id);
                  if (mounted) toast(context, r?['ok'] == true ? '删掉了' : '没删掉：${r?['error'] ?? '手机没连上'}');
                  _load();
                },
                icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFFF9A9A)),
              ),
            ]),
          ),
        const SizedBox(height: 14),
        Chip2(
          _armed ? '再点一次＝真清空' : '清掉她的长期记忆',
          ico: Icons.warning_amber_outlined,
          on: () async {
            if (!_armed) {
              setState(() => _armed = true);
              Timer(const Duration(seconds: 4), () {
                if (mounted) setState(() => _armed = false);
              });
              return;
            }
            await app.api?.memoryClear();
            setState(() => _armed = false);
            _load();
            if (mounted) toast(context, '记忆清掉了');
          },
        ),
      ],
    );
  }
}

/* ------------------------------- 她的本事 ------------------------------- */
Future<void> openSkills(BuildContext context) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF120F1B),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (c) => DraggableScrollableSheet(expand: false, initialChildSize: 0.9, builder: (c, s) => _Skills(scroll: s)),
  );
}

class _Skills extends StatefulWidget {
  const _Skills({required this.scroll});
  final ScrollController scroll;
  @override
  State<_Skills> createState() => _SkillsState();
}

class _SkillsState extends State<_Skills> {
  List<Map> _list = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final j = await app.api?.skills();
    if (!mounted) return;
    setState(() {
      _list = ((j?['skills'] as List?) ?? []).map((e) => Map.from(e)).toList();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) => ListView(
        controller: widget.scroll,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
        children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: kLine, borderRadius: BorderRadius.circular(4)))),
          Row(children: [
            const Text('她的本事', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(width: 10),
            Text('${_list.length} 项', style: const TextStyle(fontSize: 12.5, color: kSub)),
            const Spacer(),
            IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, size: 20)),
          ]),
          if (_loading) const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())),
          for (final k in _list)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(color: kGlass, borderRadius: BorderRadius.circular(12), border: Border.all(color: kLine)),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${k['text'] ?? ''}', style: const TextStyle(fontSize: 13.5)),
                    if ('${k['desc'] ?? ''}'.isNotEmpty)
                      Text('${k['desc']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: kSub)),
                  ]),
                ),
                TextButton(
                  onPressed: () async {
                    await app.api?.post('/api/skills/del', {'id': '${k['id']}'});
                    _load();
                  },
                  child: const Text('删', style: TextStyle(fontSize: 12.5, color: Color(0xFFFF9A9A))),
                ),
              ]),
            ),
        ],
      );
}

/* -------------------------------- 心情 -------------------------------- */
Future<void> openMood(BuildContext context) async {
  final j = await app.api?.mood();
  if (!context.mounted) return;
  await showDialog(
    context: context,
    builder: (c) => AlertDialog(
      title: Text('她现在：${j?['name'] ?? '平静'}'),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('心情值 ${j?['val'] ?? 0} · 兴奋 ${j?['arousal'] ?? 0}', style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 8),
        Text('${j?['reason'] ?? ''}', style: const TextStyle(fontSize: 13, color: kSub)),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('知道啦'))],
    ),
  );
}

/* -------------------------------- 相册 -------------------------------- */
Future<void> openAlbum(BuildContext context) async {
  final groups = await _loadAlbumWithPin(context);
  if (!context.mounted) return;
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF120F1B),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (c) => DraggableScrollableSheet(expand: false, initialChildSize: 0.9, builder: (c, s) => _Album(scroll: s, groups: groups)),
  );
}

Future<List<AlbGroup>> _loadAlbumWithPin(BuildContext context) async {
  final a = app.api;
  if (a == null) return [];
  var j = await a.album();
  if (j['ok'] != true) {
    final pin = await _askText(context, '相册密码', obscure: true);
    if (pin.isEmpty) return [];
    await Store.setAlbumPin(pin);
    j = await a.album();
  }
  if (j['ok'] != true) return [];
  return ((j['groups'] as List?) ?? []).map((e) => AlbGroup.fromJson(Map.from(e))).toList();
}

/// 给设置页"选背景"用：从相册里挑一张，返回它的地址
Future<String> pickAlbumImage(BuildContext context) async {
  final groups = await _loadAlbumWithPin(context);
  if (!context.mounted || groups.isEmpty) return '';
  final all = groups.expand((g) => g.photos).toList();
  if (all.isEmpty) return '';
  final picked = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: const Color(0xFF120F1B),
    builder: (c) => GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 6, crossAxisSpacing: 6),
      itemCount: all.length,
      itemBuilder: (c, i) => GestureDetector(
        onTap: () => Navigator.pop(c, all[i].url),
        child: ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(app.api!.imgUrl(all[i].url), fit: BoxFit.cover)),
      ),
    ),
  );
  return picked == null ? '' : app.api!.imgUrl(picked);
}

class _Album extends StatefulWidget {
  const _Album({required this.scroll, required this.groups});
  final ScrollController scroll;
  final List<AlbGroup> groups;
  @override
  State<_Album> createState() => _AlbumState();
}

class _AlbumState extends State<_Album> {
  late List<AlbGroup> _g = widget.groups;
  int _cur = 0;

  Future<void> _reload() async {
    final j = await app.api?.album();
    if (!mounted || j?['ok'] != true) return;
    setState(() {
      _g = ((j!['groups'] as List?) ?? []).map((e) => AlbGroup.fromJson(Map.from(e))).toList();
      if (_cur >= _g.length) _cur = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cur = _g.isEmpty ? null : _g[_cur];
    return ListView(
      controller: widget.scroll,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 26),
      children: [
        Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: kLine, borderRadius: BorderRadius.circular(4)))),
        Row(children: [
          const Text('相册', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const Spacer(),
          Chip2('新建分组', ico: Icons.add, on: () async {
            final n = await _askText(context, '新分组叫什么？（她的裸照 / 日常 / 出门）');
            if (n.isEmpty) return;
            final r = await app.api?.albumGroup('add', name: n);
            if (mounted) toast(context, r?['ok'] == true ? '分组建好了：$n' : '没建成：${r?['error'] ?? '手机没连上'}');
            _reload();
          }),
          const SizedBox(width: 6),
          Chip2('传照片', ico: Icons.upload_outlined, on: () async {
            if (cur == null) {
              toast(context, '先建个分组');
              return;
            }
            final files = await ImagePicker().pickMultiImage(maxWidth: 1600, imageQuality: 82);
            if (files.isEmpty) return;
            var ok = 0;
            for (final f in files) {
              final b = await f.readAsBytes();
              final r = await app.api?.albumUpload(cur.id, 'data:image/jpeg;base64,${base64Encode(b)}');
              if (r?['ok'] == true) ok++;
            }
            if (mounted) toast(context, ok > 0 ? '传上去 $ok 张' : '没传上去');
            _reload();
          }),
          IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, size: 20)),
        ]),
        if (_g.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 30), child: Center(child: Text('相册还是空的', style: TextStyle(color: kSub)))),
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (var i = 0; i < _g.length; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 8, top: 4),
                  child: Chip2('${_g[i].name}', on2: i == _cur, on: () => setState(() => _cur = i)),
                ),
            ],
          ),
        ),
        if (cur != null) ...[
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 6, crossAxisSpacing: 6),
            itemCount: cur.photos.length,
            itemBuilder: (c, i) {
              final ph = cur.photos[i];
              return GestureDetector(
                onTap: () => _viewPhoto(ph),
                child: ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(app.api!.imgUrl(ph.url), fit: BoxFit.cover)),
              );
            },
          ),
        ],
      ],
    );
  }

  void _viewPhoto(AlbPhoto ph) {
    showDialog(
      context: context,
      builder: (c) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.network(app.api!.imgUrl(ph.url), fit: BoxFit.contain)),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Chip2('♥ ${ph.likes}', on: () async {
              final r = await app.api?.albumLike(ph.id);
              if (r?['ok'] != true) {
                if (c.mounted) toast(c, '点不了赞：${r?['error'] ?? '手机没连上'}');
                return;
              }
              if (c.mounted) Navigator.pop(c);
              _reload();
            }),
            const SizedBox(width: 10),
            Chip2('评论', on: () async {
              final t = await _askText(context, '说点什么');
              if (t.isEmpty) return;
              final r2 = await app.api?.albumComment(ph.id, t);
              if (r2?['ok'] != true) {
                if (c.mounted) toast(c, '评论没上去：${r2?['error'] ?? '手机没连上'}');
                return;
              }
              if (c.mounted) Navigator.pop(c);
              _reload();
            }),
            const SizedBox(width: 10),
            Chip2('关了', on: () => Navigator.pop(c)),
          ]),
        ]),
      ),
    );
  }
}

Future<String> _askText(BuildContext context, String title, {bool obscure = false}) async {
  final t = TextEditingController();
  final r = await showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: TextField(controller: t, autofocus: true, obscureText: obscure),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, ''), child: const Text('算了')),
        FilledButton(onPressed: () => Navigator.pop(c, t.text.trim()), child: const Text('好')),
      ],
    ),
  );
  return r ?? '';
}
