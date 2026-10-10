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

  // ★26.2.17 全本地化：本地大脑数据（不依赖电脑桌宠，全部存手机本地）
  static String get llmCfgJson => _p.getString('llm.cfg') ?? '';
  static Future<void> setLlmCfgJson(String v) => _p.setString('llm.cfg', v);
  static String get localPersona => _p.getString('local.persona') ?? '';
  static Future<void> setLocalPersona(String v) => _p.setString('local.persona', v);
  static String get localMemories => _p.getString('local.memories') ?? '';
  static Future<void> setLocalMemories(String v) => _p.setString('local.memories', v);
  static String get localWishes => _p.getString('local.wishes') ?? '';
  static Future<void> setLocalWishes(String v) => _p.setString('local.wishes', v);
  static String get localGroups => _p.getString('local.groups') ?? '';
  static Future<void> setLocalGroups(String v) => _p.setString('local.groups', v);
  static String get localRoles => _p.getString('local.roles') ?? '';
  static Future<void> setLocalRoles(String v) => _p.setString('local.roles', v);
  static String get localHerSet => _p.getString('local.herset') ?? '';
  static Future<void> setLocalHerSet(String v) => _p.setString('local.herset', v);
  static String get localEmoji => _p.getString('local.emoji') ?? '';
  static Future<void> setLocalEmoji(String v) => _p.setString('local.emoji', v);
  static String get localChatExtra => _p.getString('local.chat.extra') ?? '';
  static Future<void> setLocalChatExtra(String v) => _p.setString('local.chat.extra', v);
  /// 上下文 token 预算（默认 96K，可在模型设置里调；写 1M 也行，按模型实际上限调）
  static int get ctxTokens => _p.getInt('local.ctxTokens') ?? 96000;
  static Future<void> setCtxTokens(int v) => _p.setInt('local.ctxTokens', v);

  // ★27.0.16 真人感开关：总开关 + 情绪标记显示
  static bool get humanLike => _p.getBool('local.humanLike') ?? true;
  static Future<void> setHumanLike(bool v) => _p.setBool('local.humanLike', v);
  static bool get moodShow => _p.getBool('local.moodShow') ?? true;
  static Future<void> setMoodShow(bool v) => _p.setBool('local.moodShow', v);

  // ★27.0.16.3 思考模式：回复前先在脑子里过一遍（模型 thinking 参数），更聪明但稍慢
  static bool get thinkingMode => _p.getBool('local.thinking') ?? true;
  static Future<void> setThinkingMode(bool v) => _p.setBool('local.thinking', v);

  // ★27.0.16.6 思考强度：1 轻（快，不带 thinking）/ 2 中（默认 thinking）/ 3 强（thinking + 深入思考要求）
  static int get thinkLevel => _p.getInt('local.thinkLevel') ?? 2;
  static Future<void> setThinkLevel(int v) => _p.setInt('local.thinkLevel', v);

  // ★27.0.16.11 本地语义记忆检索（bge-small-zh 本地推理，失败自动降级关键词）
  static bool get embEnabled => _p.getBool('local.emb') ?? true;
  static Future<void> setEmbEnabled(bool v) => _p.setBool('local.emb', v);

  // ★27.0.16.14 主动消息：她隔一段时间随机主动发一句（间隔分钟 ±50% 随机，睡眠时段不打扰）
  // 注意：sleepStart/sleepEnd（String "23:00"）是旧的定时消息睡眠配置，主动消息用 int 分钟版 proSleep*
  static bool get proactiveOn => _p.getBool('local.proactive') ?? false;
  static Future<void> setProactiveOn(bool v) => _p.setBool('local.proactive', v);
  static int get proactiveGap => _p.getInt('local.proactiveGap') ?? 120; // 分钟
  static Future<void> setProactiveGap(int v) => _p.setInt('local.proactiveGap', v);
  static int get proSleepStart => _p.getInt('local.proSleepStart') ?? 0; // 0-1439 分钟（0:00）
  static int get proSleepEnd => _p.getInt('local.proSleepEnd') ?? 0;
  static Future<void> setProSleep(int s, int e) async {
    await _p.setInt('local.proSleepStart', s);
    await _p.setInt('local.proSleepEnd', e);
  }

  // ★27.0.16.6 定时任务（对话里 AI 提取，到点她自动发消息）
  // [{id, content, at(epochMs 下次触发), repeat:'once'|'daily', created}]
  static List<Map<String, dynamic>> get timers {
    try {
      final s = _p.getString('local.timers');
      if (s == null || s.isEmpty) return [];
      final j = jsonDecode(s);
      if (j is List) return j.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {}
    return [];
  }
  static Future<void> setTimers(List<Map<String, dynamic>> v) =>
      _p.setString('local.timers', jsonEncode(v));

  // ★27.0.16.6 主动消息：开关 + 随机触发范围（分钟，完全自定义无预设限制）+ 睡眠时间（HH:mm）
  static bool get autoChatEnabled => _p.getBool('local.autoChat') ?? false;
  static Future<void> setAutoChatEnabled(bool v) => _p.setBool('local.autoChat', v);
  static int get autoMin => _p.getInt('local.autoMin') ?? 30; // 多少分钟后起可能触发
  static Future<void> setAutoMin(int v) => _p.setInt('local.autoMin', v);
  static int get autoMax => _p.getInt('local.autoMax') ?? 120; // 多少分钟内触发
  static Future<void> setAutoMax(int v) => _p.setInt('local.autoMax', v);
  static String get sleepStart => _p.getString('local.sleepStart') ?? '23:00';
  static Future<void> setSleepStart(String v) => _p.setString('local.sleepStart', v);
  static String get sleepEnd => _p.getString('local.sleepEnd') ?? '08:00';
  static Future<void> setSleepEnd(String v) => _p.setString('local.sleepEnd', v);
  static int get nextAutoAt => _p.getInt('local.nextAutoAt') ?? 0; // 下次主动触发时间戳
  static Future<void> setNextAutoAt(int v) => _p.setInt('local.nextAutoAt', v);

  // ★27.0.16.9 番茄阅读器：书源 API 地址（可配置，失效可换）+ 书架 + 章节缓存
  static String get novelBase => _p.getString('local.novel.base') ?? 'http://101.35.133.34:5000';
  static Future<void> setNovelBase(String v) => _p.setString('local.novel.base', v);
  static List<Map<String, dynamic>> get novelShelf {
    try {
      final s = _p.getString('local.novel.shelf');
      if (s == null || s.isEmpty) return [];
      final j = jsonDecode(s);
      if (j is List) return j.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {}
    return [];
  }
  static Future<void> setNovelShelf(List<Map<String, dynamic>> v) =>
      _p.setString('local.novel.shelf', jsonEncode(v));
  static String get novelCache => _p.getString('local.novel.cache') ?? ''; // 最近阅读章节缓存 {bookId:{itemId:content}}
  static Future<void> setNovelCache(String v) => _p.setString('local.novel.cache', v);

  // ★27.0.16.2 万物互联：可连接设备（贝锐蒲公英组网），{pc:{name,ip,port,online}, android:{...}}
  static Map<String, dynamic> get devices {
    try {
      final s = _p.getString('local.devices');
      if (s == null || s.isEmpty) return {};
      final j = jsonDecode(s);
      if (j is Map) return Map<String, dynamic>.from(j);
    } catch (_) {}
    return {};
  }
  static Future<void> setDevices(Map<String, dynamic> v) => _p.setString('local.devices', jsonEncode(v));

  // ★26.2.18 全本地：商城钱包 / 背包 / 飞行棋 / 相册（不依赖电脑桌宠）
  static String get localWallet => _p.getString('local.wallet') ?? '';
  static Future<void> setLocalWallet(String v) => _p.setString('local.wallet', v);
  static String get localBag => _p.getString('local.bag') ?? '';
  static Future<void> setLocalBag(String v) => _p.setString('local.bag', v);
  static String get localGame => _p.getString('local.game') ?? '';
  static Future<void> setLocalGame(String v) => _p.setString('local.game', v);
  static String get localAlbums => _p.getString('local.albums') ?? '';
  static Future<void> setLocalAlbums(String v) => _p.setString('local.albums', v);
  // ★26.2.26 控制器本地状态（全本地模式：兴奋度/档位/模式/记录存在手机）
  static String get localCtrl => _p.getString('local.ctrl') ?? '';
  static Future<void> setLocalCtrl(String v) => _p.setString('local.ctrl', v);

  // ★b21 相册列表缓存（秒开）与启动数据缓存（秒开），内容 + 时间戳
  static String get albumCache => _p.getString('album.cache') ?? '';
  static Future<void> setAlbumCache(String v) => _p.setString('album.cache', v);

  static String get bootCache => _p.getString('boot.cache') ?? '';
  static Future<void> setBootCache(String v) => _p.setString('boot.cache', v);
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
  Msg({required this.role, required this.content, this.sticker, this.voice, this.idx, this.time, this.st = 'ok', this.cid, this.detail, this.roleId, this.groupId, this.name});
  String role;          // me / assistant
  String content;
  String? sticker;      // /emoji/xxx.jpg 里的相对名
  String? voice;        // 语音条文件名
  int? idx;             // 服务端序号
  int? time;
  String st;            // ok / pending / failed
  String? imgUrl;       // 本地乐观显示用
  String? cid;          // ★服务端给这条消息的编号（用于就地更新，比如语音条后到）
  String? detail;        // ★2026-10-01 她的【细节】（动作/表情/心里），折叠显示
  String? roleId;        // ★独立角色会话标识（空 = 包娜主对话）
  String? groupId;       // ★群聊会话标识（空 = 单聊）
  String? name;         // ★群聊成员显示名（群消息才带）

  factory Msg.fromJson(Map m) => Msg(
        role: '${m['role'] ?? 'assistant'}',
        content: '${m['content'] ?? ''}',
        sticker: _s(m['sticker']),
        voice: _s(m['voice']),
        idx: _i(m['idx']),
        time: _i(m['time']),
        cid: _s(m['cid']),
        detail: _s(m['detail']),
        roleId: _s(m['roleId']),
        groupId: _s(m['groupId']),
        name: _s(m['name']),
      );

  static String? _s(dynamic v) {
    final s = v == null ? '' : '$v';
    return s.isEmpty || s == 'null' ? null : s;
  }

  static int? _i(dynamic v) => v is int ? v : int.tryParse('$v');

  /// 给别的文件用（下划线是文件私有，外面看不到）
  static int? toInt(dynamic v) => _i(v);

  /// ★2026-09-30 本地缓存：序列化整条消息（断网也能看历史）
  Map<String, dynamic> toJson() => {
        'role': role,
        'content': content,
        if (sticker != null) 'sticker': sticker,
        if (voice != null) 'voice': voice,
        if (idx != null) 'idx': idx,
        if (time != null) 'time': time,
        'st': st,
        if (cid != null) 'cid': cid,
        if (detail != null) 'detail': detail,
        if (roleId != null) 'roleId': roleId,
        if (groupId != null) 'groupId': groupId,
        if (name != null) 'name': name,
      };
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
  // ★2026-10-02 修"经常断开"：前台心跳保活 + 错误也重连 + 重试上限放宽
  Timer? _hb;          // 前台心跳：每 25s 发一次 ping，pong 没回来就认定通道假死 → 重连
  bool _lastPong = false;
  int _lastHeartbeatAt = 0;

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
  /// ★2026-10-02 修"切后台再回来就断、要手动重连"：
  ///   iOS 后台挂起会把 WebSocket 杀掉、Dart 定时器也冻结，onDone 里的延迟重连在后台根本不会跑。
  ///   所以回前台必须主动重连：先探活（通 = 电脑端活着），通就重建 WebSocket。
  void reconnect() {
    wsClose();
    if (token.isEmpty) return;
    ping().then((m) {
      if (m.startsWith('通了')) wsOpen();
    });
  }

  void wsOpen() {
    wsClose();
    if (token.isEmpty) return;
    try {
      final wsUrl = host.replaceFirst('http://', 'ws://').replaceFirst('https://', 'wss://') + '/ws?t=$token';
      final ch = WebSocketChannel.connect(Uri.parse(wsUrl));
      _ws = ch;
      _startHeartbeat();
      ch.stream.listen((data) {
        try {
          _retry = 0;   // ★收到消息 = 通道活着，清零重试计数
          final j = jsonDecode('$data');
          if (j is Map && '${j['type']}' == 'pong') _lastPong = true;
          if (j is Map) _ev.add(Map<String, dynamic>.from(j));
        } catch (_) {}
      }, onDone: () {
        _ws = null;
        _scheduleReconnect();
      }, onError: (_) {
        // ★2026-10-02 之前 onError 是空的 → 连接死了既不清理也不重连，必须手动重连
        _ws = null;
        _scheduleReconnect();
      });
    } catch (_) {}
  }

  // ★2026-10-02 统一断线重连：退避递增，上限放宽到 10 次（以前 3 次就永久停手，蒲公英抖两下就得手动重连）
  void _scheduleReconnect() {
    _retry = (_retry ?? 0) + 1;
    if ((_retry ?? 0) > 10) { _retry = 0; return; }
    Future.delayed(Duration(seconds: 3 * (_retry ?? 1)), () {
      if (token.isNotEmpty && _ws == null) wsOpen();
    });
  }

  // ★2026-10-02 前台心跳保活：电脑端 25s 会 ping 我们（底层自动回 pong 就行）；
  //   但蒲公英/NAT 假死时两边都不知道 → 我们自己也 25s 发一次 ping，6s 没等到 pong 就主动重连
  void _startHeartbeat() {
    try { _hb?.cancel(); } catch (_) {}
    _lastPong = true;
    _hb = Timer.periodic(const Duration(seconds: 25), (_) {
      if (_ws == null) {
        if (token.isNotEmpty) wsOpen();
        return;
      }
      _lastPong = false;
      try { _ws?.sink.add('{"type":"ping"}'); } catch (_) {}
      Timer(const Duration(seconds: 6), () {
        if (!_lastPong && _ws != null) {
          // pong 没回来 → 通道假死，主动重建
          wsClose();
          _scheduleReconnect();
        }
      });
    });
  }

  int? _retry;   // ★2026-10-02 断线重连续计数（防电脑端没开时无限重试）

  void wsOpenOk() { _retry = 0; }   // ★连上/收到过消息就清零重试计数

  void wsClose() {
    try {
      _hb?.cancel();
    } catch (_) {}
    _hb = null;
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

  /// 相册照片的真实可访问地址（自动带上 k；w>0 时请求缩略图，省流量省内存）
  String albumPhotoUrl(String u, {int? w}) {
    final base = imgUrl(u);
    if (albumKey.isEmpty) return base;
    var s = base + (base.contains('?') ? '&' : '?') + 'k=' + Uri.encodeComponent(albumKey);
    if (w != null && w > 0) s += '&w=$w';
    return s;
  }
  // ★2026-09-29 修：相册这四个口电脑端也只认 POST（旧版 GET → 404 → 建分组/点赞/评论/传照片全没反应）
  Future<Map<String, dynamic>> albumGroup(String action, {String? id, String? name}) =>
      post('/api/album/group', {'action': action, if (id != null) 'id': id, if (name != null) 'name': name});
  Future<Map<String, dynamic>> albumLike(String id) => post('/api/album/like', {'id': id});
  Future<Map<String, dynamic>> albumComment(String id, String text) => post('/api/album/comment', {'id': id, 'text': text});
  Future<Map<String, dynamic>> eyePush(String data, {String why = ''}) =>
      post('/api/eye', {'data': data, if (why.isNotEmpty) 'why': why});
  Future<Map<String, dynamic>> albumUpload(String group, String data) =>
      post('/api/album/upload', {'group': group, 'data': data});
  Future<Map<String, dynamic>> chatImg(String data) => post('/api/chatimg', {'data': data});

  /// 发消息（她那边会真的收到）—— 群里那套 payload 原样带上
  Future<Map<String, dynamic>> send(Map<String, dynamic> payload) {
    final b = Map<String, dynamic>.from(payload);
    // ★2026-09-30 修"发一条出两条"：本地先画的那条（chat.dart）已经带了 cid，别在这里换新的 ——
    //   换了新的编号，服务端广播回来时就认不出是自己那条 → 又被画一遍。
    if (b['cid'] == null) b['cid'] = 'c${DateTime.now().millisecondsSinceEpoch}';
    return post('/api/send', b);
  }

  /* ---------- ★独立角色（刘紫灵等）：人设/上下文/记忆完全隔离 ---------- */
  /// 角色列表：[{id, name, chatCount, memCount}]
  Future<Map<String, dynamic>> roleList() => get('/api/roles');
  /// 角色历史（独立上下文）
  Future<Map<String, dynamic>> roleHistory(String role, {int limit = 30}) =>
      get('/api/role/history', q: {'role': role, 'limit': '$limit'});
  /// 发消息给角色
  Future<Map<String, dynamic>> roleSend(String role, String text) =>
      post('/api/role/send', {'role': role, 'text': text});
  /// 清空角色上下文
  Future<Map<String, dynamic>> roleClear(String role) => post('/api/role/clear', {'role': role});
  /// 教角色记住一件事
  Future<Map<String, dynamic>> roleRemember(String role, String text) =>
      post('/api/role/remember', {'role': role, 'text': text});

  /* ---------- ★群聊（姐妹聊天群）：第三个完全隔离的分支 ---------- */
  /// 群列表：[{id, name, members:[{id,name}], chatCount}]
  Future<Map<String, dynamic>> groupList() => get('/api/groups');
  /// 群聊历史：[{role, roleId, name, content, time}]
  Future<Map<String, dynamic>> groupHistory(String gid, {int limit = 100}) =>
      get('/api/group/history', q: {'gid': gid, 'limit': '$limit'});
  /// 群聊发言 → 群成员依次回复：{ok, replies:[{roleId,name,content}]}
  Future<Map<String, dynamic>> groupSend(String gid, String text) =>
      post('/api/group/send', {'gid': gid, 'text': text});
  /// 清空群聊上下文
  Future<Map<String, dynamic>> groupClear(String gid) => post('/api/group/clear', {'gid': gid});

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

/// 聊天里那行"这时候说的"：今天 14:32 / 昨天 22:10 / 9月27日 23:07
String fmtDay(int t) {
  if (t <= 0) return '';
  final d = DateTime.fromMillisecondsSinceEpoch(t);
  final now = DateTime.now();
  final h = d.hour.toString().padLeft(2, '0'), m = d.minute.toString().padLeft(2, '0');
  final today = DateTime(now.year, now.month, now.day);
  final that = DateTime(d.year, d.month, d.day);
  final diff = today.difference(that).inDays;
  final hhmm = '$h:$m';
  if (diff == 0) return '今天 $hhmm';
  if (diff == 1) return '昨天 $hhmm';
  if (d.year == now.year) return '${d.month}月${d.day}日 $hhmm';
  return '${d.year}年${d.month}月${d.day}日 $hhmm';
}

/// ★2026-09-30 修"发一条出两条"：服务端会把你说的话广播回来（多设备同步要用），
/// 手机端必须认出"这条就是我刚发的本地那条"，就地升级、绝不重复画。
/// 返回列表里该落在哪个下标；-1 = 确实是一条新消息（才 add）。
int findEchoTarget(List<Msg> list, Msg echo, String cid) {
  if (echo.role == 'me' && cid.isNotEmpty) {
    final byCid = list.indexWhere((x) => x.role == 'me' && x.cid == cid);
    if (byCid >= 0) return byCid;   // ① 按编号认（最准）
  }
  // ② 兜底：还没被确认的本地那条 + 内容一样
  return list.lastIndexWhere((x) => x.st == 'pending' && x.role == 'me' && x.content == echo.content);
}
