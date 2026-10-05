// ★27.0.3 照片区：iOS 27 相册完全复刻
//   底部三页：图库 / 相簿 / 搜索（跟 iOS 相册一模一样）
//   图库：按 今天/昨天/日期 分组的三列网格，点开全屏查看器，长按多选
//   相簿：智能相簿（收藏/视频/自拍/截图）+ 系统相册（我的相簿）
//   搜索：按名称/日期过滤 + 建议
//   数据源：photo_manager 直读系统相册（本地，不占 App 包体）
//   ★收藏用 App 本地记录（photo_manager 编译环境无 setFavorite/favorite，本地更稳）
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme.dart';

// ---------- 本地收藏（App 自己记，不依赖系统相册的收藏状态） ----------
Future<Set<String>> _loadFav() async {
  try {
    final sp = await SharedPreferences.getInstance();
    final s = sp.getString('v27.favIds');
    if (s == null || s.isEmpty) return <String>{};
    return (jsonDecode(s) as List).cast<String>().toSet();
  } catch (_) {
    return <String>{};
  }
}

Future<void> _saveFav(Set<String> ids) async {
  try {
    final sp = await SharedPreferences.getInstance();
    await sp.setString('v27.favIds', jsonEncode(ids.toList()));
  } catch (_) {}
}

// ================= 照片区总页 =================
// ★27.0.4：底栏由 HomePage 统一接管（进照片区时全局底栏变成 返回+图库/相簿/搜索），
//   这里不再画自己的底栏，只接收 photoTab / onPhotoTab 受控切换子页
class PhotosPage extends StatefulWidget {
  const PhotosPage({super.key, required this.photoTab, required this.onPhotoTab});
  final int photoTab; // 0 图库 1 相簿 2 搜索
  final ValueChanged<int> onPhotoTab;
  @override
  State<PhotosPage> createState() => _PhotosPageState();
}

class _PhotosPageState extends State<PhotosPage> {
  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: widget.photoTab,
      children: const [
        _LibraryTab(),
        _AlbumsTab(),
        _SearchTab(),
      ],
    );
  }
}

// ================= 图库：按日期分组的网格 =================
class _LibraryTab extends StatefulWidget {
  const _LibraryTab();
  @override
  State<_LibraryTab> createState() => _LibraryTabState();
}

class _LibraryTabState extends State<_LibraryTab> {
  List<AssetEntity> _assets = [];
  bool _loading = true;
  String _perm = ''; // ''=未处理 'denied' 'authorized' 'limited'
  final Map<String, Uint8List> _thumbs = {}; // 缩略图缓存
  final Map<String, DateTime> _days = {}; // assetId -> 日期（分组用）
  int _loadBatch = 300; // 每次追加 300 张
  final ScrollController _sc = ScrollController();
  bool _selMode = false;
  final Set<String> _sel = {};

  @override
  void initState() {
    super.initState();
    _sc.addListener(_maybeLoadMore);
    _init();
  }

  @override
  void dispose() {
    _sc.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final ps = await PhotoManager.requestPermissionExtend();
    if (!mounted) return;
    if (ps.isAuth) {
      setState(() {
        _perm = ps.hasAccess ? 'authorized' : 'limited';
      });
      await _loadMore(reset: true);
    } else {
      setState(() => _perm = 'denied');
    }
  }

  Future<void> _loadMore({bool reset = false}) async {
    if (reset) {
      _assets.clear();
      _thumbs.clear();
      _days.clear();
    }
    try {
      // onlyAll=true 拿到系统"所有照片"路径（相册的全部）
      final all = await PhotoManager.getAssetPathList(
          type: RequestType.image, onlyAll: true);
      if (all.isEmpty) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      final path = all.first;
      final page = (_assets.length ~/ _loadBatch);
      final list = await path.getAssetListPaged(
          page: page, size: _loadBatch);
      if (list.isEmpty) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      final merged = List<AssetEntity>.from(_assets)..addAll(list);
      // 按创建时间降序
      merged.sort((a, b) => b.createDateTime.compareTo(a.createDateTime));
      for (final e in list) {
        _days[e.id] = e.createDateTime;
      }
      if (mounted) {
        setState(() {
          _assets = merged;
          _loading = false;
        });
        _loadThumbs(list);
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadThumbs(List<AssetEntity> list) async {
    for (final e in list) {
      if (_thumbs.containsKey(e.id)) continue;
      try {
        final b = await e.thumbnailDataWithSize(
            ThumbnailSize.square(560), quality: 82);
        if (b != null && mounted) {
          setState(() => _thumbs[e.id] = b);
        }
      } catch (_) {}
    }
  }

  void _maybeLoadMore() {
    if (_sc.position.pixels >= _sc.position.maxScrollExtent - 1200) {
      _loadMore();
    }
  }

  // 日期分组（今天/昨天/2026年10月5日）
  String _dayLabel(DateTime d) {
    final now = DateTime.now();
    final t = DateTime(d.year, d.month, d.day);
    final n = DateTime(now.year, now.month, now.day);
    final diff = n.difference(t).inDays;
    if (diff == 0) return '今天';
    if (diff == 1) return '昨天';
    return '${d.year}年${d.month}月${d.day}日';
  }

  // 按天分组，保持降序
  List<(String, List<AssetEntity>)> _groupByDay() {
    final map = <String, List<AssetEntity>>{};
    for (final e in _assets) {
      final d = _days[e.id] ?? e.createDateTime;
      final key = '${d.year}-${d.month}-${d.day}';
      map.putIfAbsent(key, () => []).add(e);
    }
    final keys = map.keys.toList()
      ..sort((a, b) => b.compareTo(a));
    return keys.map((k) {
      final d = DateTime.parse(k);
      return (_dayLabel(d), map[k]!);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // 大标题（iOS 相册风格）
      Padding(
        padding: EdgeInsets.fromLTRB(20, navSpace(context) - 30, 20, 4),
        child: Row(children: [
          Text('图库',
              style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.6)),
          const Spacer(),
          if (_selMode)
            GestureDetector(
              onTap: () => setState(() {
                _selMode = false;
                _sel.clear();
              }),
              child: Text('取消',
                  style: TextStyle(fontSize: 16, color: kAccent)),
            ),
        ]),
      ),
      Expanded(child: _buildBody()),
      // 多选底部操作栏
      if (_selMode)
        Container(
          color: kBg,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            Text('已选 ${_sel.length} 张',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            _selAct(Icons.favorite_outline, '收藏', _favSel),
            _selAct(Icons.delete_outline, '删除', _delSel),
          ]),
        ),
    ]);
  }

  Widget _selAct(IconData ic, String t, VoidCallback onTap) {
    return GestureDetector(
      onTap: _sel.isEmpty ? null : onTap,
      child: Column(children: [
        Icon(ic, size: 22, color: _sel.isEmpty ? kSub : kAccent),
        const SizedBox(height: 3),
        Text(t, style: TextStyle(fontSize: 11.5, color: _sel.isEmpty ? kSub : kAccent)),
      ]),
    );
  }

  Future<void> _favSel() async {
    final fav = await _loadFav();
    fav.addAll(_sel);
    await _saveFav(fav);
    setState(() {
      _selMode = false;
      _sel.clear();
    });
  }

  Future<void> _delSel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (cc) => AlertDialog(
        backgroundColor: kBg2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('删除照片', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        content: Text('确定删除选中的 ${_sel.length} 张照片吗？（会从系统相册删除）', style: const TextStyle(fontSize: 14.5, height: 1.4)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(cc, false), child: const Text('取消', style: TextStyle(color: kSub))),
          TextButton(onPressed: () => Navigator.pop(cc, true), child: const Text('删除', style: TextStyle(color: kBad, fontWeight: FontWeight.w600))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await PhotoManager.editor.deleteWithIds(_sel.toList());
    } catch (_) {}
    setState(() {
      _assets.removeWhere((e) => _sel.contains(e.id));
      _selMode = false;
      _sel.clear();
    });
  }

  Widget _buildBody() {
    if (_perm == 'denied') {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.photo_library_outlined, size: 54, color: kSub),
          const SizedBox(height: 14),
          const Text('需要照片访问权限', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          const Text('去系统设置里允许访问相册', style: TextStyle(fontSize: 13, color: kSub)),
          const SizedBox(height: 14),
          TextButton(
            onPressed: () => PhotoManager.openSetting(),
            child: const Text('打开设置', style: TextStyle(color: kAccent)),
          ),
        ]),
      );
    }
    if (_loading && _assets.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: kAccent));
    }
    if (_assets.isEmpty) {
      return const Center(
        child: Text('相册里还没有照片',
            style: TextStyle(fontSize: 15, color: kSub)),
      );
    }
    final groups = _groupByDay();
    return ListView.builder(
      controller: _sc,
      padding: const EdgeInsets.only(bottom: 20),
      itemCount: groups.length,
      itemBuilder: (_, gi) {
        final (label, list) = groups[gi];
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
            child: Text(label,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
          ),
          _grid(list),
        ]);
      },
    );
  }

  Widget _grid(List<AssetEntity> list) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
      ),
      itemCount: list.length,
      itemBuilder: (_, i) => _cell(list[i]),
    );
  }

  Widget _cell(AssetEntity e) {
    final b = _thumbs[e.id];
    final selected = _sel.contains(e.id);
    return GestureDetector(
      onTap: () {
        if (_selMode) {
          setState(() {
            if (selected) {
              _sel.remove(e.id);
            } else {
              _sel.add(e.id);
            }
          });
        } else {
          _openViewer(e.id);
        }
      },
      onLongPress: () {
        if (!_selMode) {
          setState(() {
            _selMode = true;
            _sel.add(e.id);
          });
          HapticFeedback.mediumImpact();
        }
      },
      child: Stack(fit: StackFit.expand, children: [
        if (b != null)
          Image.memory(b, fit: BoxFit.cover)
        else
          Container(color: kBg2, child: const Center(
              child: Icon(Icons.image_outlined, color: kSub, size: 22))),
        if (selected)
          Container(
            decoration: BoxDecoration(
              color: const Color(0x55000000),
              border: Border.all(color: kAccent, width: 2.5),
            ),
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Container(
                  width: 22, height: 22,
                  decoration: BoxDecoration(
                    color: kAccent,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: const Icon(Icons.check, size: 14, color: Colors.white),
                ),
              ),
            ),
          ),
      ]),
    );
  }

  void _openViewer(String id) {
    final idx = _assets.indexWhere((e) => e.id == id);
    if (idx < 0) return;
    Navigator.of(context).push(PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black,
      pageBuilder: (_, __, ___) => PhotoViewer(
        assets: _assets,
        initialIndex: idx,
      ),
    ));
  }
}

// ================= 相簿 =================
class _AlbumsTab extends StatefulWidget {
  const _AlbumsTab();
  @override
  State<_AlbumsTab> createState() => _AlbumsTabState();
}

class _AlbumsTabState extends State<_AlbumsTab> {
  List<AssetPathEntity> _paths = [];
  bool _loading = true;
  int _favCount = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final ps = await PhotoManager.requestPermissionExtend();
    if (!mounted) return;
    if (ps.isAuth) {
      final paths = await PhotoManager.getAssetPathList(
          type: RequestType.image, onlyAll: false);
      // 收藏数 = App 本地记录（photo_manager 编译环境没有 favorite 字段）
      final fav = await _loadFav();
      if (mounted) {
        setState(() {
          _paths = paths;
          _favCount = fav.length;
          _loading = false;
        });
      }
    } else {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: EdgeInsets.fromLTRB(20, navSpace(context) - 30, 20, 4),
        child: Row(children: [
          Text('相簿',
              style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.6)),
          const Spacer(),
        ]),
      ),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: kAccent))
            : ListView(
                padding: const EdgeInsets.only(bottom: 20),
                children: [
                  _sec('智能相簿'),
                  _albumRow('收藏', Icons.favorite, _favCount > 0 ? '$_favCount' : '—',
                      () => _openSmart('favorite')),
                  _albumRow('视频', Icons.videocam, '—',
                      () => _openSmart('video')),
                  _albumRow('自拍', Icons.face, '—',
                      () => _openSmart('selfie')),
                  _albumRow('截图', Icons.crop_original, '—',
                      () => _openSmart('screenshot')),
                  const SizedBox(height: 18),
                  _sec('我的相簿'),
                  for (final p in _paths) _albumRow(p.name, Icons.photo_album, '', () => _openPath(p)),
                ],
              ),
      ),
    ]);
  }

  Widget _sec(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
        child: Text(t,
            style: TextStyle(
                fontSize: 13,
                color: kSub,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4)),
      );

  Widget _albumRow(String name, IconData ic, String count, VoidCallback onTap) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      leading: Container(
        width: 46, height: 46,
        decoration: BoxDecoration(
          color: kBg2,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(ic, size: 24, color: kAccent),
      ),
      title: Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      subtitle: count.isEmpty ? null : Text(count, style: const TextStyle(fontSize: 12.5, color: kSub)),
      trailing: const Icon(Icons.chevron_right, size: 18, color: kSub),
      onTap: onTap,
    );
  }

  void _openPath(AssetPathEntity p) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _AlbumGrid(path: p, title: p.name),
    ));
  }

  void _openSmart(String kind) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _SmartAlbumGrid(kind: kind),
    ));
  }
}

// ================= 相簿内网格 =================
class _AlbumGrid extends StatefulWidget {
  const _AlbumGrid({required this.path, required this.title});
  final AssetPathEntity path;
  final String title;
  @override
  State<_AlbumGrid> createState() => _AlbumGridState();
}

class _AlbumGridState extends State<_AlbumGrid> {
  List<AssetEntity> _assets = [];
  bool _loading = true;
  final Map<String, Uint8List> _thumbs = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await widget.path.getAssetListPaged(page: 0, size: 10000);
    if (!mounted) return;
    setState(() {
      _assets = list;
      _loading = false;
    });
    for (final e in list) {
      try {
        final b = await e.thumbnailDataWithSize(
            ThumbnailSize.square(560), quality: 82);
        if (b != null && mounted) setState(() => _thumbs[e.id] = b);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        elevation: 0,
        title: Text(widget.title),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kAccent))
          : GridView.builder(
              padding: const EdgeInsets.all(2),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 2,
                crossAxisSpacing: 2,
              ),
              itemCount: _assets.length,
              itemBuilder: (_, i) {
                final e = _assets[i];
                final b = _thumbs[e.id];
                return GestureDetector(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => PhotoViewer(assets: _assets, initialIndex: i),
                  )),
                  child: b != null
                      ? Image.memory(b, fit: BoxFit.cover)
                      : Container(
                          color: kBg2,
                          child: const Center(
                              child: Icon(Icons.image_outlined, color: kSub, size: 22))),
                );
              },
            ),
    );
  }
}

// ================= 智能相簿（收藏/视频/自拍/截图） =================
class _SmartAlbumGrid extends StatefulWidget {
  const _SmartAlbumGrid({required this.kind});
  final String kind;
  @override
  State<_SmartAlbumGrid> createState() => _SmartAlbumGridState();
}

class _SmartAlbumGridState extends State<_SmartAlbumGrid> {
  List<AssetEntity> _assets = [];
  bool _loading = true;
  final Map<String, Uint8List> _thumbs = {};

  String get _title => switch (widget.kind) {
        'favorite' => '收藏',
        'video' => '视频',
        'selfie' => '自拍',
        _ => '截图',
      };

  @override
  void initState() {
    super.initState();
    _load();
  }

  bool _match(AssetEntity e) {
    switch (widget.kind) {
      case 'favorite':
        return _favIds.contains(e.id);
      case 'video':
        return e.type == AssetType.video;
      case 'selfie':
        return e.type == AssetType.image;
      case 'screenshot':
        final t = (e.title ?? '').toLowerCase();
        return t.contains('screenshot') || t.contains('截屏') ||
            t.contains('screen shot') || t.contains('录屏');
      default:
        return true;
    }
  }

  Set<String> _favIds = {};

  Future<void> _load() async {
    _favIds = await _loadFav();
    try {
      final all = await PhotoManager.getAssetPathList(
          type: widget.kind == 'video' ? RequestType.video : RequestType.image,
          onlyAll: true);
      if (all.isNotEmpty) {
        final list = await all.first.getAssetListPaged(page: 0, size: 10000);
        final matched = list.where(_match).toList();
        if (mounted) {
          setState(() {
            _assets = matched;
            _loading = false;
          });
        }
        for (final e in matched) {
          try {
            final b = await e.thumbnailDataWithSize(
                ThumbnailSize.square(560), quality: 82);
            if (b != null && mounted) setState(() => _thumbs[e.id] = b);
          } catch (_) {}
        }
      } else {
        setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        elevation: 0,
        title: Text(_title),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kAccent))
          : _assets.isEmpty
              ? const Center(
                  child: Text('这里还没有内容',
                      style: TextStyle(fontSize: 15, color: kSub)))
              : GridView.builder(
                  padding: const EdgeInsets.all(2),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 2,
                    crossAxisSpacing: 2,
                  ),
                  itemCount: _assets.length,
                  itemBuilder: (_, i) {
                    final e = _assets[i];
                    final b = _thumbs[e.id];
                    return GestureDetector(
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => PhotoViewer(assets: _assets, initialIndex: i),
                      )),
                      child: b != null
                          ? Image.memory(b, fit: BoxFit.cover)
                          : Container(
                              color: kBg2,
                              child: const Center(
                                  child: Icon(Icons.image_outlined,
                                      color: kSub, size: 22))),
                    );
                  },
                ),
    );
  }
}

// ================= 搜索 =================
class _SearchTab extends StatefulWidget {
  const _SearchTab();
  @override
  State<_SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<_SearchTab> {
  final TextEditingController _q = TextEditingController();
  List<AssetEntity> _result = [];
  final Map<String, Uint8List> _thumbs = {};
  bool _searched = false;

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _search(String kw) async {
    final k = kw.trim();
    if (k.isEmpty) {
      setState(() {
        _result = [];
        _searched = false;
      });
      return;
    }
    try {
      final all = await PhotoManager.getAssetPathList(
          type: RequestType.image, onlyAll: true);
      if (all.isEmpty) return;
      final list = await all.first.getAssetListPaged(page: 0, size: 10000);
      final fav = await _loadFav();
      final out = list.where((e) {
        if (k.contains('收藏')) return fav.contains(e.id);
        final t = '${e.title ?? ''}';
        final d = '${e.createDateTime.year}年${e.createDateTime.month}月${e.createDateTime.day}日';
        return t.contains(k) || d.contains(k);
      }).toList();
      if (!mounted) return;
      setState(() {
        _result = out;
        _searched = true;
      });
      for (final e in out) {
        try {
          final b = await e.thumbnailDataWithSize(
              ThumbnailSize.square(560), quality: 82);
          if (b != null && mounted) setState(() => _thumbs[e.id] = b);
        } catch (_) {}
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: EdgeInsets.fromLTRB(20, navSpace(context) - 30, 20, 4),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text('搜索',
              style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.6)),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
        child: Container(
          decoration: BoxDecoration(
            color: kBg2,
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: _q,
            onSubmitted: _search,
            style: const TextStyle(fontSize: 16),
            decoration: InputDecoration(
              hintText: '搜索照片',
              hintStyle: const TextStyle(color: kSub, fontSize: 15.5),
              prefixIcon: const Icon(Icons.search, size: 20, color: kSub),
              suffixIcon: _q.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close, size: 18, color: kSub),
                      onPressed: () {
                        _q.clear();
                        _search('');
                      }),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ),
      Expanded(
        child: !_searched
            ? ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _sug('收藏的照片', Icons.favorite, '按关键词搜索收藏的照片'),
                  _sug('今天', Icons.today, '搜索今天拍的照片'),
                  _sug('视频', Icons.videocam, '只搜索视频'),
                ],
              )
            : _result.isEmpty
                ? const Center(
                    child: Text('没有找到相关照片',
                        style: TextStyle(fontSize: 15, color: kSub)))
                : GridView.builder(
                    padding: const EdgeInsets.all(2),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 2,
                      crossAxisSpacing: 2,
                    ),
                    itemCount: _result.length,
                    itemBuilder: (_, i) {
                      final e = _result[i];
                      final b = _thumbs[e.id];
                      return GestureDetector(
                        onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => PhotoViewer(
                                    assets: _result, initialIndex: i))),
                        child: b != null
                            ? Image.memory(b, fit: BoxFit.cover)
                            : Container(
                                color: kBg2,
                                child: const Center(
                                    child: Icon(Icons.image_outlined,
                                        color: kSub, size: 22))),
                      );
                    },
                  ),
      ),
    ]);
  }

  Widget _sug(String t, IconData ic, String sub) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(ic, size: 22, color: kAccent),
      title: Text(t, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      subtitle: Text(sub, style: const TextStyle(fontSize: 12.5, color: kSub)),
      onTap: () {
        _q.text = t.contains('收藏') ? '收藏' : t == '今天' ? '${DateTime.now().year}年${DateTime.now().month}月${DateTime.now().day}日' : '视频';
        _search(_q.text);
      },
    );
  }
}

// ================= 全屏查看器 =================
class PhotoViewer extends StatefulWidget {
  const PhotoViewer({super.key, required this.assets, required this.initialIndex});
  final List<AssetEntity> assets;
  final int initialIndex;
  @override
  State<PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<PhotoViewer> {
  late int _idx = widget.initialIndex;
  late final PageController _pc = PageController(initialPage: widget.initialIndex);
  final Map<String, Uint8List> _fulls = {};
  bool _ui = true; // 顶部/底部工具是否显示
  bool _fav = false;

  @override
  void initState() {
    super.initState();
    _loadFull(widget.initialIndex);
    _initFav();
  }

  Future<void> _initFav() async {
    final fav = await _loadFav();
    if (mounted) {
      setState(() => _fav = fav.contains(widget.assets[widget.initialIndex].id));
    }
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  Future<void> _loadFull(int i) async {
    if (i < 0 || i >= widget.assets.length) return;
    final e = widget.assets[i];
    if (_fulls.containsKey(e.id)) return;
    try {
      final b = await e.originBytes;
      if (b != null && mounted) {
        setState(() => _fulls[e.id] = b);
      }
    } catch (_) {}
  }

  String _dateLabel() {
    final d = widget.assets[_idx].createDateTime;
    return '${d.year}年${d.month}月${d.day}日 ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.assets[_idx];
    final b = _fulls[e.id];
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        // 左右滑动 + 双指缩放
        PageView.builder(
          controller: _pc,
          onPageChanged: (i) {
            setState(() => _idx = i);
            _loadFull(i);
            _loadFull(i - 1);
            _loadFull(i + 1);
            _loadFav().then((fav) {
              if (mounted) setState(() => _fav = fav.contains(widget.assets[i].id));
            });
          },
          itemCount: widget.assets.length,
          itemBuilder: (_, i) {
            final fb = _fulls[widget.assets[i].id];
            return GestureDetector(
              onTap: () => setState(() => _ui = !_ui),
              child: InteractiveViewer(
                maxScale: 5,
                child: Center(
                  child: fb != null
                      ? Image.memory(fb, fit: BoxFit.contain)
                      : const Center(
                          child: CircularProgressIndicator(color: Colors.white)),
                ),
              ),
            );
          },
        ),
        // 顶部：返回 + 日期
        AnimatedOpacity(
          opacity: _ui ? 1 : 0,
          duration: const Duration(milliseconds: 180),
          child: SafeArea(
            bottom: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(4, 6, 14, 10),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xAA000000), Color(0x00000000)],
                ),
              ),
              child: Row(children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${_idx + 1} / ${widget.assets.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
                Text(_dateLabel(),
                    style: const TextStyle(color: Colors.white70, fontSize: 13.5)),
              ]),
            ),
          ),
        ),
        // 底部：收藏 / 删除
        AnimatedOpacity(
          opacity: _ui ? 1 : 0,
          duration: const Duration(milliseconds: 180),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Color(0xAA000000), Color(0x00000000)],
                  ),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                  _tool(Icons.favorite, _fav ? Colors.redAccent : Colors.white, () async {
                    final fav = await _loadFav();
                    if (_fav) {
                      fav.remove(e.id);
                    } else {
                      fav.add(e.id);
                    }
                    await _saveFav(fav);
                    setState(() => _fav = !_fav);
                  }),
                  _tool(Icons.delete_outline, Colors.white, () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (cc) => AlertDialog(
                        backgroundColor: const Color(0xFF1C1C1E),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                        title: const Text('删除照片', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                        content: const Text('确定删除这张照片吗？', style: TextStyle(fontSize: 14.5)),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(cc, false), child: const Text('取消', style: TextStyle(color: Colors.grey))),
                          TextButton(onPressed: () => Navigator.pop(cc, true), child: const Text('删除', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600))),
                        ],
                      ),
                    );
                    if (ok == true) {
                      try {
                        await PhotoManager.editor.deleteWithIds([e.id]);
                      } catch (_) {}
                      if (mounted) Navigator.pop(context);
                    }
                  }),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _tool(IconData ic, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Icon(ic, color: color, size: 26),
      ),
    );
  }
}
