# -*- coding: utf-8 -*-
import io

# ============ 1. api.dart Store 加缓存存取（相册列表 + 启动数据） ============
p = r'C:\Users\xilisi\Doubao\chats\2026-09-27\new-chat\baona-app\lib\api.dart'
s = io.open(p, encoding='utf-8').read()
old = """  static Future<void> wipe() async {
    await _p.remove('token');
    await _p.remove('pwd');
  }
}"""
new = """  static Future<void> wipe() async {
    await _p.remove('token');
    await _p.remove('pwd');
  }

  // ★b21 相册列表缓存（秒开）与启动数据缓存（秒开），内容 + 时间戳
  static String get albumCache => _p.getString('album.cache') ?? '';
  static Future<void> setAlbumCache(String v) => _p.setString('album.cache', v);

  static String get bootCache => _p.getString('boot.cache') ?? '';
  static Future<void> setBootCache(String v) => _p.setString('boot.cache', v);
}"""
assert old in s, 'store cache fail'
s = s.replace(old, new)
io.open(p, 'w', encoding='utf-8', newline='').write(s)
print('api.dart Store 缓存方法已加')

# ============ 2. us.dart：3 处相册图 → CacheImg + 相册列表缓存 ============
p = r'C:\Users\xilisi\Doubao\chats\2026-09-27\new-chat\baona-app\lib\us.dart'
s = io.open(p, encoding='utf-8').read()
old_imp = "import 'api.dart';"
new_imp = "import 'api.dart';\nimport 'imgsrv.dart';"
assert old_imp in s, 'us import fail'
s = s.replace(old_imp, new_imp)

old1 = "child: ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(app.api!.albumPhotoUrl(all[i].url, w: 500), fit: BoxFit.cover)),"
new1 = "child: CacheImg(app.api!.albumPhotoUrl(all[i].url, w: 500), fit: BoxFit.cover, radius: BorderRadius.circular(10)),"
assert old1 in s, 'us1 fail'
s = s.replace(old1, new1)

old2 = """                  child: Image.network(
                    // ★2026-09-29 缩略图：网格只下小图（服务端 ?w=500 返回，流量少一大截），点开才看原图
                    app.api!.albumPhotoUrl(ph.url, w: 500),
                    fit: BoxFit.cover,
                    // 缩略图解码：内存少一大截（网络也走缩略图了）
                    cacheWidth: 420,"""
new2 = """                  child: CacheImg(
                    // ★2026-09-29 缩略图：网格只下小图（服务端 ?w=500 返回，流量少一大截），点开才看原图
                    app.api!.albumPhotoUrl(ph.url, w: 500),
                    fit: BoxFit.cover,
                    // ★b21 缩略图解码 + 磁盘缓存：秒开不烫
                    cacheWidth: 420,"""
assert old2 in s, 'us2 fail'
s = s.replace(old2, new2)

old3 = "ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.network(app.api!.albumPhotoUrl(ph.url), fit: BoxFit.contain)),"
new3 = "CacheImg(app.api!.albumPhotoUrl(ph.url), fit: BoxFit.contain, radius: BorderRadius.circular(14)),"
assert old3 in s, 'us3 fail'
s = s.replace(old3, new3)

# 相册列表缓存：_loadAlbumWithPin 先读缓存秒开（TTL 5 分钟）
old_alb = """Future<List<AlbGroup>> _loadAlbumWithPin(BuildContext context) async {
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
  return ((j['groups'] as List?) ?? []).map((e) => AlbGroup.fromJson(Map.from(e))).toList();
}"""
new_alb = """Future<List<AlbGroup>> _loadAlbumWithPin(BuildContext context) async {
  final a = app.api;
  if (a == null) return [];
  // ★b21 相册秒开：5 分钟内直接读本地缓存，不再每次进相册都全量拉网络
  try {
    final raw = Store.albumCache;
    if (raw.isNotEmpty) {
      final c = jsonDecode(raw);
      if (c is Map && c['t'] is int && (DateTime.now().millisecondsSinceEpoch - (c['t'] as int)) < 300000) {
        final groups = ((c['groups'] as List?) ?? []);
        if (groups.isNotEmpty) return groups.map((e) => AlbGroup.fromJson(Map.from(e))).toList();
      }
    }
  } catch (_) {/* 缓存坏了就正常走网络 */}
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
  // 成功拉到 → 写缓存（含时间戳），下次进相册秒开
  try {
    await Store.setAlbumCache(jsonEncode({'t': DateTime.now().millisecondsSinceEpoch, 'groups': j['groups']}));
  } catch (_) {/* ignore */}
  return groups;
}"""
assert old_alb in s, 'us album fail'
s = s.replace(old_alb, new_alb)
io.open(p, 'w', encoding='utf-8', newline='').write(s)
print('us.dart 相册图缓存 + 相册列表缓存完成')
