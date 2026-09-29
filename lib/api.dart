// 包娜 App · 和电脑端通话的那一层
// 电脑端（桌宠）是服务端，App 是客户端：接口全走 http，她的话走 WebSocket 实时推。
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// 默认地址（家里局域网 / 蒲公英）
const List<Map<String, String>> kHosts = [
  {'name': '家里', 'url': 'http://192.168.31.120:9000'},
  {'name': '蒲公英', 'url': 'http://172.16.3.209:9000'},
];

/* ----------------------------- 本地存的东西 ----------------------------- */
class Store {
  static late SharedPreferences _p;

  static Future<void> init() async => _p = await SharedPreferences.getInstance();

  static String get baseUrl => _p.getString('baseUrl') ?? '';
  static Future<void> setBaseUrl(String v) => _p.setString('baseUrl', v);
  static String get token => _p.getString('token') ?? '';
  static Future<void> setToken(String v) => _p.setString('token', v);
  static String get pwd => _p.getString('pwd') ?? '';
  static Future<void> setPwd(String v) => _p.setString('pwd', v);
  static String get albumPin => _p.getString('albumPin') ?? '';
  static Future<void> setAlbumPin(String v) => _p.setString('albumPin', v);

  /// 界面设置（字号/气泡色/背景/提示音……）存本地
  static Map<String, dynamic> get cfg {
    try {
      final s = _p.getString('cfg');
      if (s == null || s.isEmpty) return Map<String, dynamic>.from(kDefCfg);
      final j = jsonDecode(s);
      if (j is Map) {
        final m = Map<String, dynamic>.from(kDefCfg);
        m.addAll(Map<String, dynamic>.from(j));
        return m;
      }
    } catch (_) {}
    return Map<String, dynamic>.from(kDefCfg);
  }

  static Future<void> setCfg(Map<String, dynamic> cfg) => _p.setString('cfg', jsonEncode(cfg));
  static Future<void> wipe() async {
    await _p.remove('token');
    await _p.remove('pwd');
  }
}

const Map<String, dynamic> kDefCfg = {
  'fontSize': 16.0,   // 聊天字号
  'myColor': '#7C6BF5',
  'herColor': '#2A2A35',
  'bg': '',           // 背景图地址（空 = 默认深色）
  'bubbleMax': 4,     // 一次最多几条气泡
  'showTime': false,
  'sound': true,
  'vibrate': true,
  'notify': true,
  'liveWatch': false,
};

/* ------------------------------- 数据模型 ------------------------------- */
class Msg {
  Msg({required this.role, required this.content, this.sticker, this.voice, this.idx, this.time, this.st = 'ok', this.cid});

  String role;          // me / assistant
  String content;
  String? sticker;      // /emoji/xxx.jpg 里的相对名
  String? voice;        // 语音条文件名
  int? idx;             // 服务端序号
  int? time;
  String st;            // ok / pending / failed
  String? imgUrl;       // 本地乐观显示用
  String? cid;          // ★服务端给这条消息的编号（用于就地更新，比如语音条后到）

  factory Msg.fromJson(Map m) => Msg(
        role: '${m['role'] ?? 'assistant'}',
        content: '${m['content'] ?? ''}',
        sticker: _s(m['sticker']),
        voice: _s(m['voice']),
        idx: _i(m['idx']),
        time: _i(m['time']),
        cid: _s(m['cid']),
      );

  static String? _s(dynamic v) {
    final s = v == null ? '' : '$v';
    return s.isEmpty || s == 'null' ? null : s;
  }

  static int? _i(dynamic v) => v is int ? v : int.tryParse('$v');

  /// 给别的文件用（下划线是文件私有，外面看不到）
  static int? toInt(dynamic v) => _i(v);
}

class ShopItem {
  ShopItem(this.code, this.name, this.price, this.cat, this.catName, this.img, this.ico, this.note, this.use, this.durable);
  String code, name, cat, catName, img, ico, note, use;
  int price;
  bool durable;
  factory ShopItem.fromJson(Map m) => ShopItem(
        '${m['code'] ?? ''}', '${m['name'] ?? ''}', (m['price'] as num?)?.toInt() ?? 0,
        '${m['cat'] ?? ''}', '${m['catName'] ?? ''}', '${m['img'] ?? ''}', '${m['ico'] ?? ''}',
        '${m['note'] ?? ''}', '${m['use'] ?? ''}', m['durable'] == true,
      );
}

class BagItem {
  BagItem(this.id, this.code, this.name, this.price, this.img, this.used, this.forHer, this.by, this.ts);
  String id, code, name, img, by;
  int price, used, ts;
  bool forHer;
  factory BagItem.fromJson(Map m) => BagItem(
        '${m['id'] ?? ''}', '${m['code'] ?? ''}', '${m['name'] ?? ''}', (m['price'] as num?)?.toInt() ?? 0,
        '${m['img'] ?? ''}', (m['used'] as num?)?.toInt() ?? 0, m['forHer'] == true, '${m['by'] ?? ''}',
        (m['ts'] as num?)?.toInt() ?? 0,
      );
}

class LogRow {
  LogRow(this.t, this.who, this.act, this.name, this.price);
  int t, price;
  String who, act, name;
  factory LogRow.fromJson(Map m) => LogRow((m['t'] as num?)?.toInt() ?? 0, '${m['who'] ?? ''}', '${m['act'] ?? ''}',
      '${m['name'] ?? ''}', (m['price'] as num?)?.toInt() ?? 0);
}

class ShopState {
  ShopState();
  int my = 0, her = 0, logAll = 0;
  List<BagItem> bagMe = [], bagHer = [];
  List<LogRow> log = [];
  List<Map> cats = [];
  factory ShopState.fromJson(Map j) => ShopState()
    ..my = (j['my'] as num?)?.toInt() ?? 0
    ..her = (j['her'] as num?)?.toInt() ?? 0
    ..logAll = (j['logAll'] as num?)?.toInt() ?? 0
    ..bagMe = ((j['bagMe'] as List?) ?? []).map((e) => BagItem.fromJson(Map.from(e))).toList()
    ..bagHer = ((j['bagHer'] as List?) ?? []).map((e) => BagItem.fromJson(Map.from(e))).toList()
    ..log = ((j['log'] as List?) ?? []).map((e) => LogRow.fromJson(Map.from(e))).toList()
    ..cats = ((j['cats'] as List?) ?? []).map((e) => Map.from(e)).toList();
}

class Tile {
  Tile(this.i, this.t, this.k);
  int i;
  String t, k;
  factory Tile.fromJson(Map m) => Tile((m['i'] as num?)?.toInt() ?? 0, '${m['t'] ?? ''}', '${m['k'] ?? ''}');
}

class GameState {
  GameState();
  bool on = false;
  int me = 1, her = 1, n = 48, winMe = 0, winHer = 0;
  String turn = 'me', mode = 'adv';
  String? winner, prize;
  List<Tile> tiles = [];
  List<Map> modes = [];
  List<Map> log = [];
  factory GameState.fromJson(Map j) => GameState()
    ..on = j['on'] == true
    ..me = (j['me'] as num?)?.toInt() ?? 1
    ..her = (j['her'] as num?)?.toInt() ?? 1
    ..n = (j['n'] as num?)?.toInt() ?? 48
    ..turn = '${j['turn'] ?? 'me'}'
    ..mode = '${j['mode'] ?? 'adv'}'
    ..winner = j['winner']?.toString()
    ..prize = j['prize']?.toString()
    ..tiles = ((j['tiles'] as List?) ?? []).map((e) => Tile.fromJson(Map.from(e))).toList()
    ..modes = ((j['modes'] as List?) ?? []).map((e) => Map.from(e)).toList()
    ..log = ((j['log'] as List?) ?? []).map((e) => Map.from(e)).toList()
    ..winMe = ((j['wins'] as Map?)?['me'] as num?)?.toInt() ?? 0
    ..winHer = ((j['wins'] as Map?)?['her'] as num?)?.toInt() ?? 0;
}

class CplPost {
  CplPost(this.id, this.text, this.t, this.likes);
  String id, text;
  int t, likes;
  List<Map> comments = [];
  factory CplPost.fromJson(Map m) => CplPost('${m['id'] ?? ''}', '${m['text'] ?? ''}', (m['t'] as num?)?.toInt() ?? 0,
      (m['likes'] as num?)?.toInt() ?? 0)
    ..comments = ((m['comments'] as List?) ?? []).map((e) => Map.from(e)).toList();
}

class MemItem {
  MemItem(this.id, this.text, this.t);
  String id, text;
  int t;
  factory MemItem.fromJson(Map m) =>
      MemItem('${m['id'] ?? ''}', '${m['text'] ?? ''}', (m['t'] as num?)?.toInt() ?? 0);
}

class AlbPhoto {
  AlbPhoto(this.id, this.url, this.likes, this.t);
  String id, url;
  int likes, t;
  List<Map> comments = [];
  factory AlbPhoto.fromJson(Map m) => AlbPhoto('${m['id'] ?? ''}', '${m['url'] ?? ''}', (m['likes'] as num?)?.toInt() ?? 0,
      (m['t'] as num?)?.toInt() ?? 0)
    ..comments = ((m['comments'] as List?) ?? []).map((e) => Map.from(e)).toList();
}

class AlbGroup {
  AlbGroup(this.id, this.name);
  String id, name;
  List<AlbPhoto> photos = [];
  factory AlbGroup.fromJson(Map m) => AlbGroup('${m['id'] ?? ''}', '${m['name'] ?? ''}')
    ..photos = ((m['photos'] as List?) ?? []).map((e) => AlbPhoto.fromJson(Map.from(e))).toList();
}

/* -------------------------------- 请求层 -------------------------------- */
class Api {
  Api(this.host);
  String host;                       // http://192.168.31.120:9000
  String token = '';
  String albumKey = '';              // ★相册照片的保密 key（/api/album 返回，必须带在照片地址后面）
  WebSocketChannel? _ws;
  final StreamController<Map<String, dynamic>> _ev = StreamController.broadcast();

  Stream<Map<String, dynamic>> get events => _ev.stream;
  bool get hasToken => token.isNotEmpty;

  Uri _u(String path, [Map<String, String>? q]) =>
      Uri.parse(host + path).replace(queryParameters: (q == null || q.isEmpty) ? null : q);

  Map<String, String> get _h => {'x-wc-token': token, 'x-album-pin': Store.albumPin};

  Future<Map<String, dynamic>> get(String path, {Map<String, String>? q}) async {
    try {
      final r = await http.get(_u(path, q), headers: _h).timeout(const Duration(seconds: 25));
      return _dec(r);
    } catch (e) {
      return {'ok': false, 'error': '连不上：$e'};
    }
  }

  Future<Map<String, dynamic>> post(String path, [Map<String, dynamic>? body]) async {
    try {
      final r = await http
          .post(_u(path), headers: {..._h, 'Content-Type': 'application/json'}, body: jsonEncode(body ?? {}))
          .timeout(const Duration(seconds: 30));
      return _dec(r);
    } catch (e) {
      return {'ok': false, 'error': '连不上：$e'};
    }
  }

  Map<String, dynamic> _dec(http.Response r) {
    try {
      final j = jsonDecode(utf8.decode(r.bodyBytes));
      if (j is Map) return Map<String, dynamic>.from(j);
    } catch (_) {}
    return {'ok': false, 'error': '服务端返回看不懂（${r.statusCode}）'};
  }

  /// 登录：口令换令牌
  Future<Map<String, dynamic>> login(String pwd) async {
    final j = await post('/api/login', {'password': pwd});
    if (j['ok'] == true) token = '${j['token']}';
    return j;
  }

  /// 探活：能不能连上电脑端（login 页用）
  Future<String> ping() async {
    try {
      final r = await http.get(_u('/version'), headers: _h).timeout(const Duration(seconds: 6));
      final j = jsonDecode(utf8.decode(r.bodyBytes));
      if (j is Map && j['ok'] == true) return '通了 · 电脑端版本 ${j['build']}';
    } catch (_) {}
    return '连不上（电脑端的桌宠开着吗？同一个 WiFi 吗？）';
  }

  /* ---------- 实时通道（她的新消息/打字中/控制器/游戏/商城） ---------- */
  void wsOpen() {
    wsClose();
    if (token.isEmpty) return;
    try {
      final wsUrl = host.replaceFirst('http://', 'ws://').replaceFirst('https://', 'wss://') + '/ws?t=$token';
      final ch = WebSocketChannel.connect(Uri.parse(wsUrl));
      _ws = ch;
      ch.stream.listen((data) {
        try {
          final j = jsonDecode('$data');
          if (j is Map) _ev.add(Map<String, dynamic>.from(j));
        } catch (_) {}
      }, onDone: () {
        _ws = null;
        Future.delayed(const Duration(seconds: 4), () {
          if (_ev.hasListener && token.isNotEmpty) wsOpen();
        });
      }, onError: (_) {});
    } catch (_) {}
  }

  void wsClose() {
    try {
      _ws?.sink.close();
    } catch (_) {}
    _ws = null;
  }

  void dispose() {
    wsClose();
    _ev.close();
  }

  /* ------------------------------ 接口速查 ------------------------------ */
  Future<Map<String, dynamic>> bootstrap() => get('/api/bootstrap');
  Future<Map<String, dynamic>> history({int limit = 30}) => get('/api/history', q: {'limit': '$limit'});
  Future<Map<String, dynamic>> emojiList() => get('/api/emoji');
  Future<Map<String, dynamic>> state() => get('/api/state');
  Future<Map<String, dynamic>> mood() => get('/api/mood');
  Future<Map<String, dynamic>> skills() => get('/api/skills');
  Future<Map<String, dynamic>> ctrl() => get('/api/ctrl');
  Future<Map<String, dynamic>> ctrlCmd(String cmd, dynamic val) => post('/api/ctrl', {'cmd': cmd, 'val': val});
  Future<Map<String, dynamic>> game() => get('/api/game');
  // ★2026-09-29 修：电脑端这三个口只认 POST（旧版写成 GET → 服务端 404 → 手机上点了没反应）
  Future<Map<String, dynamic>> gameRoll(String who) => post('/api/game/roll', {'who': who});
  Future<Map<String, dynamic>> gameMode(String m) => post('/api/game/mode?m=${Uri.encodeComponent(m)}');
  Future<Map<String, dynamic>> gameTile(int i, String t) => post('/api/game/tile?i=$i&t=${Uri.encodeComponent(t)}');
  Future<Map<String, dynamic>> shop() => get('/api/shop');
  Future<Map<String, dynamic>> catalog() => get('/api/shop/catalog');
  Future<Map<String, dynamic>> shopBuy(String code, bool forHer) => post('/api/shop/buy', {'code': code, 'forHer': forHer});
  Future<Map<String, dynamic>> shopUse(String id) => post('/api/shop/use', {'id': id});
  Future<Map<String, dynamic>> shopGive(String id) => post('/api/shop/give', {'id': id});
  Future<Map<String, dynamic>> shopPay(int amount) => post('/api/shop/pay', {'amount': amount});
  Future<Map<String, dynamic>> shopEarn(int amount, [String why = '陪老公的奖励']) =>
      post('/api/shop/earn', {'amount': amount, 'why': why});
  Future<Map<String, dynamic>> herSettings() => get('/api/settings');
  /// ★她的桌宠实时画面（手机左边缘往右滑看到的那个）
  Future<Map<String, dynamic>> petShot() => get('/api/petshot');
  /// ★她的脑子：模型列表 / 切换（老公 2026-09-29）
  Future<Map<String, dynamic>> llm() => get('/api/llm');
  Future<Map<String, dynamic>> llmUse(String id) => post('/api/llm/use', {'id': id});
  /// ★表情包：手机上加一张 / 删一张（共享库：他加的她也能发）
  Future<Map<String, dynamic>> emojiAdd(String data, [String name = '']) =>
      post('/api/emoji/add', {'data': data, 'name': name});
  Future<Map<String, dynamic>> emojiDel(String name) => post('/api/emoji/del', {'name': name});
  Future<Map<String, dynamic>> patchSettings(Map<String, dynamic> patch) => post('/api/settings', {'patch': patch});
  Future<Map<String, dynamic>> voiceOn(bool en) => post('/api/voice', {'enabled': en});
  Future<Map<String, dynamic>> setPassword(String np) => post('/api/password', {'newPassword': np});
  Future<Map<String, dynamic>> clearChat() => post('/api/clear');
  Future<Map<String, dynamic>> memories() => get('/api/memories');
  Future<Map<String, dynamic>> memoryAdd(String text) => post('/api/memories/add', {'text': text});
  Future<Map<String, dynamic>> memoryRemove(String id) => post('/api/memories/remove', {'id': id});
  Future<Map<String, dynamic>> memoryClear() => post('/api/memory/clear');
  Future<Map<String, dynamic>> couple() => get('/api/couple');
  Future<Map<String, dynamic>> coupleLike(String id) => post('/api/couple/like', {'id': id});
  Future<Map<String, dynamic>> coupleComment(String id, String text) => post('/api/couple/comment', {'id': id, 'text': text});
  Future<Map<String, dynamic>> album() async {
    final j = await get('/api/album');
    // ★相册照片的地址是 /api/album/photo/<id>，但直连会 404 —— 必须带上这个 key（老公 2026-09-29：
    //   之前把 k 丢了，手机上相册全是空白）
    if (j['ok'] == true && j['k'] != null && '${j['k']}'.isNotEmpty) albumKey = '${j['k']}';
    return j;
  }

  /// 相册照片的真实可访问地址（自动带上 k）
  String albumPhotoUrl(String u) {
    final base = imgUrl(u);
    if (albumKey.isEmpty) return base;
    return base + (base.contains('?') ? '&' : '?') + 'k=' + Uri.encodeComponent(albumKey);
  }
  // ★2026-09-29 修：相册这四个口电脑端也只认 POST（旧版 GET → 404 → 建分组/点赞/评论/传照片全没反应）
  Future<Map<String, dynamic>> albumGroup(String action, {String? id, String? name}) =>
      post('/api/album/group', {'action': action, if (id != null) 'id': id, if (name != null) 'name': name});
  Future<Map<String, dynamic>> albumLike(String id) => post('/api/album/like', {'id': id});
  Future<Map<String, dynamic>> albumComment(String id, String text) => post('/api/album/comment', {'id': id, 'text': text});
  Future<Map<String, dynamic>> albumUpload(String group, String data) =>
      post('/api/album/upload', {'group': group, 'data': data});
  Future<Map<String, dynamic>> chatImg(String data) => post('/api/chatimg', {'data': data});

  /// 发消息（她那边会真的收到）—— 群里那套 payload 原样带上
  Future<Map<String, dynamic>> send(Map<String, dynamic> payload) {
    final b = Map<String, dynamic>.from(payload);
    b['cid'] = 'c${DateTime.now().millisecondsSinceEpoch}';
    return post('/api/send', b);
  }

  /// 图片地址补全（emoji / 商城图 / 聊天图）
  String imgUrl(String path) {
    if (path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    if (path.startsWith('/')) return host + path;
    return host + '/' + path;
  }

  String emojiUrl(String name) => imgUrl('/emoji/${_enc(name)}');

  /// 表情名里可能是中文（你加的表情）→ 每段都要 URL 编码，不然请求会挂
  static String _enc(String p) => p.split('/').map(Uri.encodeComponent).join('/');

  String voiceUrl(String v) {
    if (v.startsWith('/')) return host + v;
    if (v.contains('/')) return host + '/' + v;
    return host + '/voice/' + v;
  }
}

String fmtClock(int t) {
  if (t <= 0) return '';
  final d = DateTime.fromMillisecondsSinceEpoch(t);
  final h = d.hour.toString().padLeft(2, '0'), m = d.minute.toString().padLeft(2, '0');
  final now = DateTime.now();
  final sameDay = d.year == now.year && d.month == now.month && d.day == now.day;
  return sameDay ? '$h:$m' : '${d.month}/${d.day} $h:$m';
}
