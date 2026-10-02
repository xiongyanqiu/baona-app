// 包娜 App · 「我们」页：情侣空间 / 相册 / 她的记忆 / 她的本事
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'api.dart';
import 'imgsrv.dart';
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
    final dynamic a = app.brainOrApi;
    if (a == null) return;
    // 本地模式没有"情侣空间"（那是连电脑的功能）；记忆数量从本地大脑拿
    final Map p = app.brain != null ? <String, dynamic>{} : await a.couple();
    final mc = await a.memories();
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
      child: ListView(padding: EdgeInsets.fromLTRB(14, 6, 14, navSpace(context) + 24), children: [
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
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x8A000000),
    builder: (c) => DraggableScrollableSheet(expand: false, initialChildSize: 0.85, builder: (c, s) => GlassSheet(child: _Mem(scroll: s))),
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
    final dynamic a = app.brainOrApi;
    if (a == null) return;
    final j = await a.memories();
    final t = j;
    if (!mounted) return;
    setState(() {
      _items = ((j['items'] as List?) ?? []).map((e) => MemItem.fromJson(Map.from(e))).toList();
      _total = (t['count'] as num?)?.toInt() ?? _items.length;
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
              final r = await app.brainOrApi?.memoryAdd(t);
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
                  final r = await app.brainOrApi?.memoryRemove(it.id);
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
            await app.brainOrApi?.memoryClear();
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
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x8A000000),
    builder: (c) => DraggableScrollableSheet(expand: false, initialChildSize: 0.9, builder: (c, s) => GlassSheet(child: _Skills(scroll: s))),
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
  // ★2026-10-01 相册本地缓存：有持久化列表就立即打开（秒开、离线可看），进页后再静默刷新；
  //   没缓存才走网络（可能要相册密码）。
  final cached = _albumFromCache();
  List<AlbGroup> groups;
  bool stale = false;
  if (cached != null && cached.isNotEmpty) {
    groups = cached;
    stale = true;
  } else {
    groups = await _loadAlbumNetwork(context);
  }
  if (!context.mounted) return;
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x8A000000),
    builder: (c) => DraggableScrollableSheet(expand: false, initialChildSize: 0.9, builder: (c, s) => GlassSheet(child: _Album(scroll: s, groups: groups, stale: stale))),
  );
}

/// 读持久化相册列表（无视缓存时间，用于立即渲染）
List<AlbGroup>? _albumFromCache() {
  try {
    final raw = Store.albumCache;
    if (raw.isEmpty) return null;
    final c = jsonDecode(raw);
    if (c is Map) {
      final groups = ((c['groups'] as List?) ?? []);
      final list = groups.map((e) => AlbGroup.fromJson(Map.from(e))).toList();
      if (list.isNotEmpty) return list;
    }
  } catch (_) {/* 缓存坏了就走网络 */}
  return null;
}

/// 首次（无缓存）走网络拉相册，含相册密码兜底；成功写持久化缓存
Future<List<AlbGroup>> _loadAlbumNetwork(BuildContext context) async {
  final a = app.api;
  if (a == null) return [];
  var j = await a.album();
  if (j['ok'] != true) {
    // ★先拿聊天口令试一下（电脑端相册密码默认就是它）——省得每次都让你输
    if (Store.albumPin.isEmpty && Store.pwd.isNotEmpty) {
      await Store.setAlbumPin(Store.pwd);
      j = await a.album();
    }
  }
  if (j['ok'] != true) {
    final pin = await _askText(context, '相册密码', obscure: true);
    if (pin.isEmpty) return [];
    await Store.setAlbumPin(pin);
    j = await a.album();
  }
  if (j['ok'] != true) return [];
  final groups = ((j['groups'] as List?) ?? []).map((e) => AlbGroup.fromJson(Map.from(e))).toList();
  // 成功拉到 → 写持久化缓存
  try {
    await Store.setAlbumCache(jsonEncode({'t': DateTime.now().millisecondsSinceEpoch, 'groups': j['groups']}));
  } catch (_) {/* ignore */}
  return groups;
}

/// 给设置页"选背景"用：从相册里挑一张，返回它的地址
Future<String> pickAlbumImage(BuildContext context) async {
  final groups = await _loadAlbumNetwork(context);
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
        child: CacheImg(app.api!.albumPhotoUrl(all[i].url, w: 500), fit: BoxFit.cover, radius: BorderRadius.circular(10)),
      ),
    ),
  );
  return picked == null ? '' : app.api!.albumPhotoUrl(picked);
}

class _Album extends StatefulWidget {
  const _Album({required this.scroll, required this.groups, this.stale = false});
  final ScrollController scroll;
  final List<AlbGroup> groups;
  final bool stale; // ★2026-10-01：true=读的是本地缓存，进页后静默刷新（不转圈、不挡手）
  @override
  State<_Album> createState() => _AlbumState();
}

class _AlbumState extends State<_Album> {
  late List<AlbGroup> _g = widget.groups;
  int _cur = 0;
  bool _up = false; // 正在传照片（按钮变成"传着呢…"）

  @override
  void initState() {
    super.initState();
    // ★2026-09-29：默认要选【有照片的那个分组】——以前默认是第一个，他那个第一组"日常"是空的，
    //   点开相册看着就像"没有内容"（实测 App 连一张照片都没去请求）
    _cur = _firstWithPhotos();
    // ★2026-10-01：读的是本地缓存 → 后台静默拉最新，拉到就替换并更新缓存
    if (widget.stale) {
      Future.microtask(() async {
        final fresh = await _loadAlbumNetwork(context);
        if (!mounted || fresh.isEmpty) return;
        setState(() {
          _g = fresh;
          if (_cur >= _g.length) _cur = 0;
          if (_g.isNotEmpty && _g[_cur].photos.isEmpty) _cur = _firstWithPhotos();
        });
      });
    }
  }

  int _firstWithPhotos() {
    for (var i = 0; i < _g.length; i++) {
      if (_g[i].photos.isNotEmpty) return i;
    }
    return 0;
  }

  Future<void> _reload() async {
    final j = await app.api?.album();
    if (!mounted || j?['ok'] != true) return;
    setState(() {
      _g = ((j!['groups'] as List?) ?? []).map((e) => AlbGroup.fromJson(Map.from(e))).toList();
      if (_cur >= _g.length) _cur = 0;
      if (_g.isNotEmpty && _g[_cur].photos.isEmpty) _cur = _firstWithPhotos(); // 当前这组空了就换有图的
    });
    // ★2026-10-01：刷新成功同步更新本地缓存
    try {
      await Store.setAlbumCache(jsonEncode({'t': DateTime.now().millisecondsSinceEpoch, 'groups': j!['groups']}));
    } catch (_) {/* ignore */}
  }

  @override
  Widget build(BuildContext context) {
    final cur = _g.isEmpty ? null : _g[_cur];
    final total = cur == null ? 0 : cur.photos.length;
    final head = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: kLine, borderRadius: BorderRadius.circular(4)))),
      Row(children: [
        Text('相册${total > 0 ? '（共 $total 张）' : ''}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const Spacer(),
        Chip2(_up ? '传着呢…' : '传照片', ico: _up ? Icons.hourglass_bottom : Icons.upload_outlined, on: _up ? () {} : _upload),
        const SizedBox(width: 6),
        Chip2('新建分组', ico: Icons.add, on: () async {
          final n = await _askText(context, '新分组叫什么？（她的裸照 / 日常 / 出门）');
          if (n.isEmpty) return;
          final r = await app.api?.albumGroup('add', name: n);
          if (mounted) toast(context, r?['ok'] == true ? '分组建好了：$n' : '没建成：${r?['error'] ?? '手机没连上'}');
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
                child: Chip2('${_g[i].name}${_g[i].photos.isEmpty ? ' · 空' : ' · ${_g[i].photos.length}'}', on2: i == _cur, on: () => setState(() => _cur = i)),
              ),
          ],
        ),
      ),
      if (cur != null && cur.photos.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 26),
          child: Center(child: Text('这个分组还没照片（点右上「传照片」加几张）', style: TextStyle(color: kSub, fontSize: 12.5))),
        ),
      const SizedBox(height: 8),
    ]);
    // ★2026-09-29：以前是 ListView 里塞一个 shrinkWrap 的 GridView → 170 张照片一次性全下载（≈22MB，
    //   所以他觉得"照片加载太慢、非常吃网络"）。改成 sliver 懒加载：只下载屏幕上看得见的那几张。
    return CustomScrollView(
      controller: widget.scroll,
      slivers: [
        SliverPadding(padding: const EdgeInsets.fromLTRB(14, 10, 14, 0), sliver: SliverToBoxAdapter(child: head)),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 26),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 6, crossAxisSpacing: 6),
            itemCount: total,
            itemBuilder: (c, i) {
              final ph = cur!.photos[i];
              return GestureDetector(
                onTap: () => _viewPhoto(ph),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: CacheImg(
                    // ★2026-09-29 缩略图：网格只下小图（服务端 ?w=500 返回，流量少一大截），点开才看原图
                    app.api!.albumPhotoUrl(ph.url, w: 500),
                    fit: BoxFit.cover,
                    // ★b21 缩略图解码 + 磁盘缓存：秒开不烫
                    cacheWidth: 420,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// 传照片：多选拿不到就退回单选；每一步都说话；传的时候按钮变成"传着呢…"
  Future<void> _upload() async {
    final cur = _g.isEmpty ? null : _g[_cur];
    if (cur == null) {
      toast(context, '先建个分组');
      return;
    }
    List<XFile> files = [];
    try {
      files = await ImagePicker().pickMultiImage(maxWidth: 1024, imageQuality: 72);
    } catch (_) {
      files = [];
    }
    if (!mounted) return;
    if (files.isEmpty) {
      try {
        final one = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1024, imageQuality: 72);
        if (one != null) files = [one];
      } catch (e) {
        if (mounted) toast(context, '打不开相册：$e');
        return;
      }
    }
    if (files.isEmpty) {
      if (mounted) toast(context, '没选照片');
      return;
    }
    setState(() => _up = true);
    var ok = 0;
    var lastErr = '';
    for (final f in files) {
      try {
        final b = await f.readAsBytes();
        var r = await app.api?.albumUpload(cur.id, 'data:image/jpeg;base64,${base64Encode(b)}');
        if (r?['ok'] != true && '${r?['error'] ?? ''}'.contains('密码')) {
          final pin = await _askText(context, '相册密码', obscure: true);
          if (pin.isNotEmpty) {
            await Store.setAlbumPin(pin);
            r = await app.api?.albumUpload(cur.id, 'data:image/jpeg;base64,${base64Encode(b)}');
          }
        }
        if (r?['ok'] == true) {
          ok++;
        } else {
          lastErr = '${r?['error'] ?? '电脑端没接住'}';
        }
      } catch (e) {
        lastErr = '$e';
      }
    }
    if (!mounted) return;
    setState(() => _up = false);
    toast(context, ok > 0 ? '传上去 $ok 张 ✓' : '没传上去：$lastErr');
    if (ok > 0) _reload();
  }

  void _viewPhoto(AlbPhoto ph) {
    showDialog(
      context: context,
      builder: (c) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          CacheImg(app.api!.albumPhotoUrl(ph.url), fit: BoxFit.contain, radius: BorderRadius.circular(14)),
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
