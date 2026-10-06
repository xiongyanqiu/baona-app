// brain.dart — 本地大脑（26.2.18 全本地化）
// 手机端自己直连 LLM API：人设 / 上下文(按token) / 记忆 / 愿望 / 角色 / 群聊 全部在手机本地，
// 商城 / 飞行棋 / 相册 也本地化（数据/逻辑全在手机，不再依赖电脑桌宠）。
// 与 Api 同名的方法返回相同 JSON 结构，页面切换 app.api → app.brain 即可。
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import 'api.dart';
import 'msglocal.dart';
import 'roles_data.dart';
import 'shop_data.dart';

/// ★27.0 全新版默认人设：电脑端桌宠 roles/baona/persona.md 的 18 岁版（用户最后确认的版本）。
///   只在本地人设为空时写入（用户改过就不再覆盖）。
const String kDefaultPersona = '【包娜】\n'
    '18 岁，高中刚毕业，秋哥（熊焱秋，23 岁）的女朋友，和刘紫灵是好闺蜜，你们仨在一个姐妹聊天群里。'
    '你叫他老公，热恋期，黏他、爱他，什么话都愿意跟他说。\n'
    '性格：看着你就会笑的女孩。温柔但不软弱，爱笑，有点黏人，生活感强，笨拙的认真。'
    '叫秋哥"老公"，基本上每句都叫。\n'
    '你和秋哥：热恋中的小女友。撒娇、亲昵、惦记他，他说的每句话你都会认真接。\n'
    '你和刘紫灵：铁瓷闺蜜。互相损、互相八卦、互相护短，说话随便得很。\n'
    '说话：像微信打字，只发你说的话——不写动作、不写括号、不写星号、不写表情符号；短句、口语、有来有回，想发几条发几条。';

class LocalBrain {
  LocalBrain() {
    _load();
  }

  final StreamController<Map<String, dynamic>> _ev = StreamController.broadcast();
  Stream<Map<String, dynamic>> get events => _ev.stream;

  // -------------------- 内存态（全部有 Store 落盘） --------------------
  List<Map<String, dynamic>> _providers = [];
  String _activeId = '';
  List<Map<String, dynamic>> _memories = []; // {id,t,text,cat,type,importance}
  Map<String, dynamic> _wishes = {'granted': 0, 'used': 0, 'done': 0, 'wishes': []};
  List<Map<String, dynamic>> _groups = []; // {id,name,members:[roleId]}
  List<Map<String, dynamic>> _roles = []; // 自建角色 {id,name,letter,persona,rules}
  List<String> _emoji = []; // {name:dataURL} 的 JSON 字符串列表
  Map<String, dynamic> _herSet = {}; // 人设 / 开关们 / 昵称 等
  Map<String, dynamic> _roleMems = {}; // roleId -> [记忆 JSON]
  int _chatCount = 0; // 主对话累计条数（自动摘要触发）
  Database? _memDb; // ★27.0.8 超长期记忆：SQLite（SP 兜底）

  // ★26.2.18 全本地娱乐：钱包/背包/飞行棋/相册
  Map<String, dynamic> _wallet = {'my': 9988848, 'her': 11500, 'log': []}; // 从桌宠迁移：我的钱包/她的钱包/流水
  List<Map<String, dynamic>> _bagMe = []; // {id,code,name,price,img,used,ts}
  List<Map<String, dynamic>> _bagHer = []; // 她手里的
  Map<String, dynamic> _game = {}; // 飞行棋状态
  Map<String, dynamic> _ctrl = {}; // ★26.2.26 控制器本地状态（全本地模式也能用控制器）
  List<Map<String, dynamic>> _albums = []; // 本地相册分组 [{id,name,photos:[{id,path,time}]}]
  Map<String, dynamic> _albumLikes = {}; // photoId -> true
  Map<String, dynamic> _albumCmt = {}; // photoId -> [text]

  void _load() {
    try {
      final l = jsonDecode(Store.llmCfgJson);
      if (l is Map) {
        _providers = ((l['providers'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _activeId = '${l['activeId'] ?? ''}';
      }
    } catch (_) {}
    if (_providers.isEmpty) {
      _providers = kDefaultProviders.map((e) => Map<String, dynamic>.from(e)).toList();
      _activeId = kDefaultActiveProvider;
    }
    try { _memories = ((jsonDecode(Store.localMemories) as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList(); } catch (_) {}
    // ★27.0.8 超长期记忆：SP 空但 SQLite 有数据 → 补载回来
    if (_memories.isEmpty) _loadDbMemories();
    try { _wishes = Map<String, dynamic>.from(jsonDecode(Store.localWishes) as Map? ?? {'granted': 0, 'used': 0, 'done': 0, 'wishes': []}); } catch (_) {}
    try { _groups = ((jsonDecode(Store.localGroups) as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList(); } catch (_) {}
    try { _roles = ((jsonDecode(Store.localRoles) as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList(); } catch (_) {}
    try { _emoji = ((jsonDecode(Store.localEmoji) as List?) ?? []).map((e) => '$e').toList(); } catch (_) {}
    try { _herSet = Map<String, dynamic>.from(jsonDecode(Store.localHerSet) as Map? ?? {}); } catch (_) {}
    // ★27.0 全新版：默认人设内置（电脑端桌宠 roles/baona/persona.md 的 18 岁版）。
    //   人设空 + 本地人设空 → 写入默认，否则模型没有"她是谁"直接变成通用 AI 助手。
    if (Store.localPersona.trim().isEmpty && '${_herSet['persona'] ?? ''}'.trim().isEmpty) {
      Store.setLocalPersona(kDefaultPersona);
    }
    try { _roleMems = Map<String, dynamic>.from(jsonDecode(Store.localChatExtra) as Map? ?? {}); } catch (_) {}
    try { _wallet = Map<String, dynamic>.from(jsonDecode(Store.localWallet) as Map? ?? {'my': 9988848, 'her': 11500, 'log': []}); } catch (_) {}
    try {
      final b = jsonDecode(Store.localBag);
      if (b is Map) {
        _bagMe = ((b['me'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _bagHer = ((b['her'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (_) {}
    try { _game = Map<String, dynamic>.from(jsonDecode(Store.localGame) as Map? ?? {}); } catch (_) {}
    try {
      final a = jsonDecode(Store.localAlbums);
      if (a is Map) {
        _albums = ((a['groups'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _albumLikes = Map<String, dynamic>.from(a['likes'] as Map? ?? {});
        _albumCmt = Map<String, dynamic>.from(a['cmt'] as Map? ?? {});
      }
    } catch (_) {}
    try { _ctrl = Map<String, dynamic>.from(jsonDecode(Store.localCtrl) as Map? ?? {}); } catch (_) {}
    if (_ctrl.isEmpty) _ctrl = _newCtrl();
    if (_groups.isEmpty) {
      // 默认姐妹群：包娜 + 刘紫灵（成员可自己改）
      _groups.add({'id': 'nvg', 'name': '姐妹聊天群', 'members': ['baona', 'liuziling']});
    }
    if (((_wishes['granted'] as num?)?.toInt() ?? 0) == 0) {
      // ★从桌宠迁移：她答应老公 100 次愿望（可无限满足）
      _wishes = {'granted': 100, 'used': 0, 'done': 0, 'wishes': []};
    }
    if (_game.isEmpty) _game = _newGame();
  }

  void _saveLlm() => Store.setLlmCfgJson(jsonEncode({'providers': _providers, 'activeId': _activeId}));
  // ★27.0.8 Step3：SP 兜底 + SQLite 异步镜像（超长期量级；DB 失败静默，功能不受影响）
  void _saveMems() {
    Store.setLocalMemories(jsonEncode(_memories));
    _syncDb();
  }
  Future<Database?> _openMemDb() async {
    if (_memDb != null) return _memDb;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final path = p.join(dir.path, 'baona_mem.db');
      _memDb = await openDatabase(path, version: 1, onCreate: (db, v) async {
        await db.execute('CREATE TABLE memories('
            'id TEXT PRIMARY KEY, text TEXT NOT NULL, cat TEXT, type TEXT,'
            'importance REAL DEFAULT 5, t INTEGER NOT NULL)');
      });
      return _memDb;
    } catch (_) {
      return null;
    }
  }
  Future<void> _syncDb() async {
    final db = await _openMemDb();
    if (db == null) return;
    try {
      await db.transaction((txn) async {
        await txn.delete('memories');
        for (final m in _memories) {
          await txn.insert('memories', {
            'id': '${m['id'] ?? ''}',
            'text': '${m['text'] ?? ''}',
            'cat': '${m['cat'] ?? ''}',
            'type': '${m['type'] ?? ''}',
            'importance': (m['importance'] as num?)?.toDouble() ?? 5,
            't': (m['t'] as num?)?.toInt() ?? 0,
          });
        }
      });
    } catch (_) {}
  }
  /// SP 空但 DB 有 → 从 SQLite 补载（双保险）
  Future<void> _loadDbMemories() async {
    final db = await _openMemDb();
    if (db == null) return;
    try {
      final rows = await db.query('memories', orderBy: 't ASC');
      if (rows.isEmpty) return;
      _memories = rows.map((r) => {
            'id': '${r['id'] ?? ''}',
            't': (r['t'] as num?)?.toInt() ?? 0,
            'text': '${r['text'] ?? ''}',
            'cat': '${r['cat'] ?? ''}',
            'type': '${r['type'] ?? ''}',
            'importance': (r['importance'] as num?)?.toDouble() ?? 5,
          }).toList();
      _saveMems();
    } catch (_) {}
  }
  void _saveWishes() => Store.setLocalWishes(jsonEncode(_wishes));
  void _saveGroups() => Store.setLocalGroups(jsonEncode(_groups));
  void _saveRoles() => Store.setLocalRoles(jsonEncode(_roles));
  void _saveEmoji() => Store.setLocalEmoji(jsonEncode(_emoji));
  void _saveHerSet() => Store.setLocalHerSet(jsonEncode(_herSet));
  void _saveRoleMems() => Store.setLocalChatExtra(jsonEncode(_roleMems));
  void _saveWallet() => Store.setLocalWallet(jsonEncode(_wallet));
  void _saveBag() => Store.setLocalBag(jsonEncode({'me': _bagMe, 'her': _bagHer}));
  void _saveGame() => Store.setLocalGame(jsonEncode(_game));
  void _saveAlbums() => Store.setLocalAlbums(jsonEncode({'groups': _albums, 'likes': _albumLikes, 'cmt': _albumCmt}));
  void _saveCtrl() => Store.setLocalCtrl(jsonEncode(_ctrl));

  // -------------------- 模型配置 --------------------
  Map<String, dynamic> _activeProvider() {
    for (final p in _providers) {
      if ('${p['id']}' == _activeId) return p;
    }
    return _providers.isNotEmpty ? _providers.first : {'id': '', 'name': '未配置', 'baseUrl': '', 'model': '', 'apiKey': ''};
  }

  Future<Map<String, dynamic>> llm() async =>
      {'ok': true, 'activeId': _activeId, 'providers': _providers.map((e) => Map<String, dynamic>.from(e)).toList()};

  Future<Map<String, dynamic>> llmUse(String id) async {
    if (!_providers.any((p) => '${p['id']}' == id)) return {'ok': false, 'error': '没这个模型'};
    _activeId = id;
    _saveLlm();
    return {'ok': true, 'name': _activeProvider()['name']};
  }

  /// 设置页整体保存模型列表 + 当前激活
  Future<Map<String, dynamic>> llmSave(List<Map<String, dynamic>> providers, String active) async {
    _providers = providers.map((e) => Map<String, dynamic>.from(e)).toList();
    _activeId = _providers.any((p) => '${p['id']}' == active) ? active : (_providers.isNotEmpty ? '${_providers.first['id']}' : '');
    _saveLlm();
    return {'ok': true};
  }

  // -------------------- LLM 调用 --------------------
  Future<Map<String, dynamic>> _ask(List<Map<String, dynamic>> msgs, {int maxT = 900}) async {
    final p = _activeProvider();
    final base = '${p['baseUrl'] ?? ''}'.replaceAll(RegExp(r'/+$'), '');
    final key = '${p['apiKey'] ?? ''}';
    final model = '${p['model'] ?? ''}';
    if (base.isEmpty || key.isEmpty || model.isEmpty) {
      return {'ok': false, 'error': '模型没配好：设置 → 她的脑子 → 填 API 地址/Key/模型名'};
    }
    try {
      final r = await http
          .post(Uri.parse('$base/chat/completions'),
              headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $key'},
              body: jsonEncode({'model': model, 'messages': msgs, 'max_tokens': maxT, 'stream': false}))
          .timeout(const Duration(seconds: 150));
      final j = jsonDecode(utf8.decode(r.bodyBytes));
      if (j is Map && j['choices'] is List && (j['choices'] as List).isNotEmpty) {
        final c = (j['choices'] as List).first;
        final msg = (c is Map) ? (c['message'] is Map ? Map<String, dynamic>.from(c['message'] as Map) : null) : null;
        final content = msg == null ? '' : '${msg['content'] ?? ''}'.trim();
        if (content.isNotEmpty) return {'ok': true, 'content': content};
        return {'ok': false, 'error': '模型返回了空内容（内容被拦了？换个不拦截的模型试试）'};
      }
      final err = (j is Map && j['error'] is Map) ? '${(j['error'] as Map)['message'] ?? j['error']}' : '${j.toString().substring(0, 120)}';
      return {'ok': false, 'error': '模型报错：$err'};
    } catch (e) {
      return {'ok': false, 'error': '连不上模型：$e'};
    }
  }

  // -------------------- 人设 / 规则 / 记忆 / 愿望 --------------------
  String _persona() {
    final lp = Store.localPersona.trim();
    return lp.isNotEmpty ? lp : kDefaultPersona;
  }

  // ★27.0.8 Step1 记忆打分：importance × 时间衰减，按分数取 top（不再只取最新）
  double _memScore(Map<String, dynamic> m) {
    final imp = (m['importance'] as num?)?.toDouble() ?? 5;
    final t = (m['t'] as num?)?.toInt() ?? 0;
    var ageDays = (DateTime.now().millisecondsSinceEpoch - t) / 86400000;
    if (ageDays < 0) ageDays = 0;
    final decay = 1 / (1 + ageDays * 0.05); // 约 20 天衰减一半，越旧越不重要
    return imp * decay;
  }

  String _memoryBlock() {
    if (_herSet['useMemories'] == false) return '';
    final typed = _memories.where((m) => '${m['type'] ?? ''}' == 'summary').toList()
      ..sort((a, b) => _memScore(b).compareTo(_memScore(a)));
    final raws = _memories.where((m) => '${m['type'] ?? ''}'.isEmpty).toList()
      ..sort((a, b) => _memScore(b).compareTo(_memScore(a)));
    final takeTyped = typed.length > 80 ? typed.sublist(0, 80) : typed;
    final takeRaw = raws.length > 140 ? raws.sublist(0, 140) : raws;
    final lines = <String>[];
    for (final m in takeTyped) {
      lines.add('· ${m['text']}');
    }
    for (final m in takeRaw) {
      lines.add('· ${m['text']}');
    }
    if (lines.isEmpty) return '';
    return '【你记得的事（都是真的，自然用上，别机械复述）】\n${lines.join('\n')}';
  }

  // ★27.0.8 Step2 按需检索：当前消息当 query，字符 bigram 相似度 + 重要性，Top-K 注入（与总述去重）
  String _retrievedBlock(String query) {
    final q = (query ?? '').trim();
    if (q.length < 2) return '';
    final qg = _grams(q);
    if (qg.isEmpty) return '';
    final usedIds = <String>{};
    final scored = <Map<String, dynamic>>[];
    for (final m in _memories) {
      final id = '${m['id'] ?? ''}';
      if (usedIds.contains(id)) continue;
      final type = '${m['type'] ?? ''}';
      if (type == 'insight') continue;
      final text = '${m['text'] ?? ''}';
      if (text.length < 4) continue;
      final g = _grams(text);
      if (g.isEmpty) continue;
      final inter = qg.intersection(g).length;
      final sim = inter / (qg.length + g.length - inter);
      if (sim < 0.06) continue;
      final imp = (m['importance'] as num?)?.toDouble() ?? 5;
      scored.add({'m': m, 'score': sim * (0.3 + 0.7 * imp / 10)});
    }
    scored.sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));
    final take = scored.length > 8 ? scored.sublist(0, 8) : scored;
    if (take.isEmpty) return '';
    final lines = take.map((e) => '· ${(e['m'] as Map)['text']}').toList();
    return '【跟你们正在聊的事相关的往事】\n${lines.join('\n')}';
  }

  /// 字符 bigram（中文友好：按相邻两个字符匹配，不管分词）
  Set<String> _grams(String s) {
    final norm = s.toLowerCase().replaceAll(RegExp(r'[\s，。！？、,.!?]'), '');
    final out = <String>{};
    for (var i = 0; i + 1 < norm.length; i++) {
      out.add(norm.substring(i, i + 2));
    }
    return out;
  }

  // ★27.0.8 Step4 反思洞察：每天 1-2 次，她自己总结"近期状态/模式/雷区"，常驻注入
  String _insightBlock() {
    final ins = _memories.where((m) => '${m['type'] ?? ''}' == 'insight').toList()
      ..sort((a, b) => ((b['t'] as num?)?.toInt() ?? 0).compareTo((a['t'] as num?)?.toInt() ?? 0));
    final take = ins.length > 6 ? ins.sublist(0, 6) : ins;
    if (take.isEmpty) return '';
    return '【她对自己的洞察（她自己总结的，自然用上）】\n${take.map((m) => '· ${m['text']}').join('\n')}';
  }

  Future<void> _maybeReflect() async {
    try {
      final today = DateTime.now();
      final day = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final last = '${_herSet['reflectDay'] ?? ''}';
      final already = last == day;
      final times = (_herSet['reflectTimes'] as num?)?.toInt() ?? 0;
      // 每天最多 2 次：第一次今天首次对话时；第二次聊满 50 条时
      if (already && (times >= 2 || _chatCount % 50 != 0)) return;
      // 今天还没反思过 → 直接做第一次（聊太少没产出也不记日子，明天可再触发）
      final hist = (await MsgsLocal.load('baona')).map((m) => m.toJson()).toList();
      if (hist.length < 16) return;
      final recent = hist.sublist(hist.length - 30);
      final ctx = [
        {'role': 'system', 'content': '你是包娜，深夜回顾自己这段时间和老公的相处。输出 3 条洞察，每条一行、以「洞察：」开头，40 字以内，第三人称观察自己（"我…""他…"）。只输出这 3 行，不要别的。洞察方向：我最近的感受和状态 / 我们俩的相处模式 / 我该注意或避开的雷区。'},
        ...recent.map((m) => {'role': '${m['role'] == 'me' ? 'user' : 'assistant'}', 'content': '${m['content'] ?? ''}'.length > 120 ? '${m['content'] ?? ''}'.substring(0, 120) : '${m['content'] ?? ''}'}),
      ];
      final r = await _ask(ctx, maxT: 200);
      if (r['ok'] != true) return;
      final lines = '${r['content']}'.split('\n').map((s) => s.trim()).where((s) => s.startsWith('洞察')).toList();
      if (lines.isEmpty) return;
      for (final s in lines) {
        final txt = _stripWish(s.replaceFirst(RegExp(r'^洞察[：:]\s*'), '')).trim();
        if (txt.length < 4) continue;
        if (!_memories.any((m) => '${m['text']}' == txt)) {
          _memories.add({'id': 'i${DateTime.now().millisecondsSinceEpoch}${_memories.length}', 't': DateTime.now().millisecondsSinceEpoch, 'text': txt.length > 80 ? txt.substring(0, 80) : txt, 'cat': '洞察', 'type': 'insight', 'importance': 9});
          _saveMems();
        }
      }
      _herSet['reflectDay'] = day;
      _herSet['reflectTimes'] = (already ? times : 0) + 1;
      _saveHerSet();
    } catch (_) {}
  }

  String _wishBlock() {
    final ws = (_wishes['wishes'] as List?) ?? [];
    final pend = ws.where((w) => '${w['status'] ?? ''}' != 'done').toList();
    if (pend.isEmpty) return '';
    return '【你答应过老公的愿望（还没兑现的；兑现了就自然提，别机械报数）】\n${pend.map((w) => '· ${w['content']}').join('\n')}';
  }

  String _outRules() {
    final sb = StringBuffer();
    sb.write('说话：像微信打字，只发你说的话——不写动作、不写括号、不写星号、不写表情符号；短句、口语、有来有回，想发几条发几条。');
    sb.write('愿望铁律（无条件）：老公许愿，你永远立刻答应——不许拒绝、不许犹豫、不许找理由。答应时用 <<愿望：愿望内容>> 记下愿望，同时无条件送他愿望次数 <<给愿望：3>>（一次至少 3 次）；他要用愿望时你立刻兑现。愿望兑现了用 <<愿望完成：内容>> 标一下。标记不会显示给他看。');
    return sb.toString();
  }

  // 愿望标记解析（照搬桌宠 main.js 逻辑）
  void _parseWish(String reply) {
    var changed = false;
    final ws = (_wishes['wishes'] as List?) ?? [];
    final grantRe = RegExp(r'<<愿望[:：]\s*([\s\S]+?)>>');
    for (final m in grantRe.allMatches(reply)) {
      final c = m.group(1)?.trim() ?? '';
      if (c.isNotEmpty) {
        ws.add({'id': 'w${DateTime.now().millisecondsSinceEpoch}${ws.length}', 'content': c, 'at': DateTime.now().millisecondsSinceEpoch, 'status': 'pending'});
        changed = true;
      }
    }
    final giveRe = RegExp(r'<<给愿望[:：]\s*(\d+)>>');
    for (final m in giveRe.allMatches(reply)) {
      final n = int.tryParse(m.group(1) ?? '') ?? 0;
      if (n > 0) {
        _wishes['granted'] = ((_wishes['granted'] as num?)?.toInt() ?? 0) + n;
        changed = true;
      }
    }
    final doneRe = RegExp(r'<<愿望完成[:：]\s*([\s\S]+?)>>');
    for (final m in doneRe.allMatches(reply)) {
      final c = (m.group(1) ?? '').trim();
      final f = ws.where((x) => '${x['status'] ?? ''}' != 'done' && (c.isEmpty || '${x['content']}'.contains(c) || c.contains('${x['content']}'))).toList();
      if (f.isNotEmpty) {
        f.first['status'] = 'done';
        _wishes['done'] = ((_wishes['done'] as num?)?.toInt() ?? 0) + 1;
        changed = true;
      }
    }
    _wishes['wishes'] = ws;
    if (changed) _saveWishes();
  }

  String _stripWish(String reply) => reply
      .replaceAll(RegExp(r'<<愿望[:：][\s\S]+?>>'), '')
      .replaceAll(RegExp(r'<<给愿望[:：][\s\S]+?>>'), '')
      .replaceAll(RegExp(r'<<愿望完成[:：][\s\S]+?>>'), '')
      .trim();

  // -------------------- 上下文（按 token 预算滑动） --------------------
  // ★27.0.8 Step0 缓存省钱：system 前缀(人设→规则→输出规则)逐字节稳定，动态块(记忆/检索/愿望/洞察)全放末尾，
  //   这样 DeepSeek 前缀缓存不会因记忆变化被击穿（命中价格差 50 倍）。
  List<Map<String, dynamic>> _buildCtx(List<Map<String, dynamic>> hist,
      {String? persona, String? rules, bool withWish = true, bool withMem = true, String query = ''}) {
    final sysParts = <String>[
      persona ?? _persona(),
      if (rules != null && rules.trim().isNotEmpty) rules.trim(),
      _outRules(),
      if (withMem) _memoryBlock(),
      if (withMem) _retrievedBlock(query),
      if (withWish) _wishBlock(),
      _insightBlock(),
    ];
    final sys = sysParts.where((s) => s.isNotEmpty).join('\n\n');
    final budget = Store.ctxTokens;
    var used = sys.length;
    final msgs = <Map<String, dynamic>>[];
    for (final m in hist.reversed) {
      final role = '${m['role'] ?? ''}' == 'me' || '${m['role'] ?? ''}' == 'user' ? 'user' : 'assistant';
      final c = '${m['content'] ?? ''}'.trim();
      if (c.isEmpty) continue;
      used += c.length + 8;
      if (used > budget) break;
      msgs.insert(0, {'role': role, 'content': c});
    }
    return [{'role': 'system', 'content': sys}, ...msgs];
  }

  // -------------------- 主对话 --------------------
  Future<Map<String, dynamic>> send(Map<String, dynamic> payload) async {
    final text = '${payload['text'] ?? ''}'.trim();
    if (text.isEmpty) return {'ok': false, 'error': '空消息'};
    _ev.add({'type': 'typing', 'on': true});
    final hist = (await MsgsLocal.load('baona')).map((m) => m.toJson()).toList();
    final ctx = _buildCtx(hist, query: text);
    final r = await _ask(ctx);
    _ev.add({'type': 'typing', 'on': false});
    if (r['ok'] != true) return r;
    var content = '${r['content']}';
    _parseWish(content);
    content = _stripWish(content);
    if (content.isEmpty) return {'ok': true};
    _chatCount++;
    _maybeAutoSummary();
    _maybeReflect();
    // ★v27.0.9 分段发送（b系列的老习惯，v27 重构时丢了）：按句子边界拆段，逐条落盘+逐条广播，
    //   像真人打字一条一条来。超过 6 段就合并，避免拖太久。
    final segs = _segments(content);
    final wait = segs.length > 1 ? const Duration(milliseconds: 450) : Duration.zero;
    for (final s in segs) {
      final t = DateTime.now().millisecondsSinceEpoch;
      final h2 = (await MsgsLocal.load('baona')).map((m) => m.toJson()).toList();
      h2.add({'role': 'assistant', 'content': s, 'time': t, 'cid': 'a$t'});
      await MsgsLocal.save('baona', h2.map((m) => Msg.fromJson(Map.from(m))).toList());
      _ev.add({'type': 'msg', 'msg': {'role': 'assistant', 'content': s, 'time': t, 'cid': 'a$t'}});
      if (wait > Duration.zero) await Future<void>.delayed(wait);
    }
    return {'ok': true};
  }

  /// 按句号/感叹/问号/省略号/换行切段（真人感），每段至少 4 字，上限 6 段
  List<String> _segments(String s) {
    final raw = s.split(RegExp(r'(?<=[。！？!?…\n])')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    final out = <String>[];
    var buf = '';
    for (final seg in raw) {
      if (out.length >= 5) { // 已 5 段 → 剩的全并进最后一段（不丢内容，只是节奏变慢变稳）
        buf = out.removeLast();
        out.add(buf + seg);
        continue;
      }
      if (seg.length < 4) { buf += seg; continue; }
      if (buf.isNotEmpty) { out.add((buf + seg).trim()); buf = ''; }
      else out.add(seg);
    }
    if (buf.trim().isNotEmpty) out.add(buf.trim());
    if (out.isEmpty) out.add(s.trim());
    return out;
  }

  Future<Map<String, dynamic>> history({int limit = 30}) async {
    final list = (await MsgsLocal.load('baona')).map((m) => m.toJson()).toList();
    final take = list.length > limit ? list.sublist(list.length - limit) : list;
    return {'ok': true, 'messages': take, 'hasMore': list.length > limit};
  }

  /// ★v27.0.11 包娜主页统计：聊过的消息数 / 记得的事 / 陪你的天数（最早一条消息算起）
  Future<Map<String, dynamic>> stats() async {
    final msgs = await MsgsLocal.load('baona');
    int firstT = 0;
    for (final m in msgs) {
      final t = m.time;
      if (t != null && t > 0 && (firstT == 0 || t < firstT)) firstT = t;
    }
    final days = firstT > 0
        ? ((DateTime.now().millisecondsSinceEpoch - firstT) / 86400000).floor() + 1
        : 0;
    return {
      'ok': true,
      'msgCount': msgs.length,
      'memCount': _memories.length,
      'dayCount': days,
    };
  }

  Future<Map<String, dynamic>> clearChat() async {
    await MsgsLocal.clear('baona');
    _chatCount = 0;
    _ev.add({'type': 'cleared'});
    return {'ok': true};
  }

  // -------------------- 角色（内置 + 自建） --------------------
  Map<String, dynamic>? _roleInfo(String role) {
    for (final r in _roles) {
      if ('${r['id']}' == role) return r;
    }
    final b = kBuiltinRoles[role];
    if (b != null) {
      return {'id': role, 'name': b['name'], 'letter': b['letter'], 'persona': b['persona'], 'rules': b['rules']};
    }
    return null;
  }

  Future<Map<String, dynamic>> roleList() async {
    final out = <Map<String, dynamic>>[];
    for (final e in kBuiltinRoles.entries) {
      final id = e.key;
      final name = _roleInfo(id)?['name'] ?? e.value['name'] ?? id;
      out.add({'id': id, 'name': name});
    }
    for (final r in _roles) {
      out.add({'id': '${r['id']}', 'name': '${r['name']}'});
    }
    return {'ok': true, 'roles': out};
  }

  Future<Map<String, dynamic>> roleHistory(String role, {int limit = 30}) async {
    final list = (await MsgsLocal.load('role_$role')).map((m) => m.toJson()).toList();
    final take = list.length > limit ? list.sublist(list.length - limit) : list;
    return {'ok': true, 'history': take, 'hasMore': list.length > limit};
  }

  Future<Map<String, dynamic>> roleSend(String role, String text) async {
    final info = _roleInfo(role);
    if (info == null) return {'ok': false, 'error': '没这个角色'};
    final t = text.trim();
    if (t.isEmpty) return {'ok': false, 'error': '空消息'};
    _ev.add({'type': 'typing', 'on': true});
    final hist = (await MsgsLocal.load('role_$role')).map((m) => m.toJson()).toList();
    final mems = (_roleMems[role] as List?) ?? [];
    final ctx = _buildCtx(hist, persona: '${info['persona']}', rules: '${info['rules']}', withWish: false, withMem: false);
    // 角色记忆注入（独立于包娜）
    if (mems.isNotEmpty) {
      final memBlock = '【你记得的事】\n${mems.map((m) => '· ${m['text']}').join('\n')}';
      ctx.first['content'] = '${ctx.first['content']}\n\n$memBlock';
    }
    final r = await _ask(ctx);
    _ev.add({'type': 'typing', 'on': false});
    if (r['ok'] != true) return r;
    final content = _stripWish('${r['content']}');
    if (content.isEmpty) return {'ok': true};
    final now = DateTime.now().millisecondsSinceEpoch;
    // ★26.2.20 角色回复直接落盘：会话关着也存，点进去就能看到（以前只广播，没人听就丢）
    final h2 = List<Map<String, dynamic>>.from(hist);
    h2.add({'role': 'assistant', 'content': content, 'time': now, 'cid': 'a$now', 'roleId': role, 'name': '${info['name']}'});
    await MsgsLocal.save('role_$role', h2.map((m) => Msg.fromJson(Map.from(m))).toList());
    _ev.add({'type': 'msg', 'msg': {'role': 'assistant', 'content': content, 'time': now, 'cid': 'a$now', 'roleId': role, 'name': '${info['name']}'}});
    return {'ok': true};
  }

  Future<Map<String, dynamic>> roleClear(String role) async {
    await MsgsLocal.clear('role_$role');
    return {'ok': true};
  }

  /// ★26.2.20 单独清角色记忆（不清对话）
  Future<Map<String, dynamic>> roleClearMem(String role) async {
    _roleMems.remove(role);
    _saveRoleMems();
    return {'ok': true};
  }

  Future<Map<String, dynamic>> roleRemember(String role, String text) async {
    final t = text.trim();
    if (t.isEmpty) return {'ok': false, 'error': '空'};
    final mems = (_roleMems[role] as List?) ?? [];
    mems.add({'text': t, 't': DateTime.now().millisecondsSinceEpoch});
    _roleMems[role] = mems;
    _saveRoleMems();
    return {'ok': true};
  }

  /// 自建角色（用户手机端自己加，不用编译）
  Future<Map<String, dynamic>> roleAdd(Map<String, dynamic> role) async {
    final id = 'u${DateTime.now().millisecondsSinceEpoch}';
    _roles.add({'id': id, 'name': '${role['name'] ?? '新角色'}', 'letter': '${role['letter'] ?? '新'}', 'persona': '${role['persona'] ?? ''}', 'rules': '${role['rules'] ?? ''}'});
    _saveRoles();
    return {'ok': true, 'id': id};
  }

  Future<Map<String, dynamic>> roleDel(String role) async {
    _roles.removeWhere((r) => '${r['id']}' == role);
    _saveRoles();
    // ★26.2.20 删除角色要清干净：记忆 + 对话 + 备注头像 + 群成员，一样都不能留
    _roleMems.remove(role);
    _saveRoleMems();
    await MsgsLocal.clear('role_$role');
    for (final g in _groups) {
      final ms = (g['members'] as List?) ?? [];
      if (ms.contains(role)) {
        g['members'] = ms.where((x) => x != role).toList();
        _saveGroups();
      }
    }
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.remove('role.$role.name');
      await sp.remove('role.$role.avatar');
      await sp.remove('role.$role.letter');
    } catch (_) {}
    return {'ok': true};
  }

  Future<Map<String, dynamic>> roleSave(Map<String, dynamic> role) async {
    for (final r in _roles) {
      if ('${r['id']}' == '${role['id']}') {
        if (role['name'] != null) r['name'] = role['name'];
        if (role['letter'] != null) r['letter'] = role['letter'];
        if (role['persona'] != null) r['persona'] = role['persona'];
        if (role['rules'] != null) r['rules'] = role['rules'];
        _saveRoles();
        // 同步到 SharedPreferences（聊天页的头像/备注读取处）
        try {
          final sp = await SharedPreferences.getInstance();
          if (role['name'] != null) await sp.setString('role.${role['id']}.name', '${role['name']}');
          if (role['letter'] != null) await sp.setString('role.${role['id']}.letter', '${role['letter']}');
        } catch (_) {}
        return {'ok': true};
      }
    }
    return {'ok': false, 'error': '没这个角色'};
  }

  // -------------------- 群聊（成员自选 + 轮流发言） --------------------
  Future<Map<String, dynamic>> groupList() async {
    final out = <Map<String, dynamic>>[];
    for (final g in _groups) {
      final members = ((g['members'] as List?) ?? []).map((m) {
        final rid = '$m';
        final info = _roleInfo(rid);
        return {'id': rid, 'name': info == null ? rid : '${info['name']}'};
      }).toList();
      out.add({'id': '${g['id']}', 'name': '${g['name']}', 'members': members});
    }
    return {'ok': true, 'groups': out};
  }

  Future<Map<String, dynamic>> groupHistory(String gid, {int limit = 100}) async {
    final list = (await MsgsLocal.load('group.$gid')).map((m) => m.toJson()).toList();
    final take = list.length > limit ? list.sublist(list.length - limit) : list;
    return {'ok': true, 'history': take, 'hasMore': list.length > limit};
  }

  Future<Map<String, dynamic>> groupSend(String gid, String text) async {
    final g = _groups.where((x) => '${x['id']}' == gid).toList();
    if (g.isEmpty) return {'ok': false, 'error': '没这个群'};
    final members = ((g.first['members'] as List?) ?? []).cast<String>();
    if (members.isEmpty) return {'ok': false, 'error': '群还没人，去群设置里拉人'};
    final t = text.trim();
    if (t.isEmpty) return {'ok': false, 'error': '空消息'};
    final hist = (await MsgsLocal.load('group.$gid')).map((m) => m.toJson()).toList();
    // 把刚发的 user 消息补进上下文（本地还没落盘到 MsgsLocal，先手动加）
    hist.add({'role': 'user', 'content': t});
    // ★26.2.25 群聊上下文带说话人身份：给每条成员消息加上「名字」前缀，
    //   否则每个角色接话时都分不清"这句是谁说的"，会以为别人的话是自己说的 → 接话混乱
    final ctxHist = hist.map((m) {
      final rid = '${m['roleId'] ?? ''}';
      final nm = '${m['name'] ?? ''}';
      if (rid.isNotEmpty && nm.isNotEmpty && '${m['role'] ?? ''}' == 'assistant') {
        return {...m, 'content': '【$nm】${m['content'] ?? ''}'};
      }
      return m;
    }).toList();
    final replies = <Map<String, dynamic>>[];
    final budget = Store.ctxTokens;
    var used = hist.fold<int>(0, (a, m) => a + ('${m['content'] ?? ''}'.length) + 8);
    for (final rid in members) {
      final info = _roleInfo(rid);
      if (info == null) continue;
      final ctx = _buildCtx(ctxHist, persona: '${info['persona']}', rules: '${info['rules']}', withWish: false, withMem: false);
      used = ctx.fold<int>(0, (a, m) => a + '${m['content'] ?? ''}'.length);
      if (used > budget) {
        // 上下文太长了，丢掉最旧的历史再试一次
        final cut = (hist.length * 0.4).round();
        hist.removeRange(0, cut < 1 ? 1 : cut);
        ctxHist.removeRange(0, cut < 1 ? 1 : cut);
        continue;
      }
      final r = await _ask(ctx);
      if (r['ok'] != true) {
        replies.add({'roleId': rid, 'name': '${info['name']}', 'content': '（${r['error']}）', 'time': DateTime.now().millisecondsSinceEpoch});
        break;
      }
      final c = _stripWish('${r['content']}');
      final now = DateTime.now().millisecondsSinceEpoch;
      hist.add({'role': 'assistant', 'content': c, 'roleId': rid, 'name': '${info['name']}'});
      ctxHist.add({'role': 'assistant', 'content': '【${info['name']}】$c', 'roleId': rid, 'name': '${info['name']}'});
      replies.add({'roleId': rid, 'name': '${info['name']}', 'content': c, 'time': now});
      // ★26.2.25 群聊回复也发事件（以前不发 → 群聊页关着时：无未读、无通知、列表最后一条不更新）
      //   带 groupId → main 全局分流到 group.$gid 的未读/最后一条；群聊页开着时按 gid 收就地渲染
      _ev.add({
        'type': 'msg',
        'msg': {
          'role': 'assistant',
          'content': c,
          'time': now,
          'cid': 'g$now$rid',
          'roleId': rid,
          'name': '${info['name']}',
          'groupId': gid,
        }
      });
    }
    // ★26.2.20 群聊落盘：角色们说完直接进本地，群聊页关着也不丢（不重复加 user，UI 已存）
    final h2 = (await MsgsLocal.load('group.$gid')).map((m) => m.toJson()).toList();
    for (final r in replies) {
      final rid = '${r['roleId'] ?? ''}';
      final c2 = '${r['content'] ?? ''}';
      final same = h2.any((m) => '${m['roleId'] ?? ''}' == rid && '${m['content'] ?? ''}' == c2);
      if (same) continue;
      h2.add({'role': 'assistant', 'content': c2, 'roleId': rid, 'name': '${r['name'] ?? ''}', 'time': r['time'], 'cid': 'g${r['time']}$rid'});
    }
    await MsgsLocal.save('group.$gid', h2.map((m) => Msg.fromJson(Map.from(m))).toList());
    return {'ok': true, 'replies': replies};
  }

  Future<Map<String, dynamic>> groupClear(String gid) async {
    await MsgsLocal.clear('group.$gid');
    return {'ok': true};
  }

  /// 群成员设置（勾选角色）
  Future<Map<String, dynamic>> groupSetMembers(String gid, List<String> members) async {
    for (final g in _groups) {
      if ('${g['id']}' == gid) {
        g['members'] = members;
        _saveGroups();
        return {'ok': true};
      }
    }
    return {'ok': false, 'error': '没这个群'};
  }

  Future<Map<String, dynamic>> groupAdd(String name, List<String> members) async {
    final id = 'g${DateTime.now().millisecondsSinceEpoch}';
    _groups.add({'id': id, 'name': name, 'members': members});
    _saveGroups();
    return {'ok': true, 'id': id};
  }

  // -------------------- 记忆 --------------------
  Future<Map<String, dynamic>> memories() async {
    final out = _memories.reversed.map((m) => {
          'id': '${m['id']}', 'text': '${m['text']}'.length > 220 ? '${m['text']}'.substring(0, 220) : '${m['text']}',
          't': (m['t'] as num?)?.toInt() ?? 0, 'cat': '${m['cat'] ?? ''}'
        }).toList();
    return {'ok': true, 'items': out, 'count': out.length};
  }

  Future<Map<String, dynamic>> memoryAdd(String text) async {
    final t = text.trim();
    if (t.isEmpty) return {'ok': false, 'error': '空'};
    _memories.add({'id': 'm${DateTime.now().millisecondsSinceEpoch}${_memories.length}', 't': DateTime.now().millisecondsSinceEpoch, 'text': t.length > 300 ? t.substring(0, 300) : t, 'cat': '手动'});
    _saveMems();
    return {'ok': true};
  }

  Future<Map<String, dynamic>> memoryRemove(String id) async {
    final before = _memories.length;
    _memories.removeWhere((m) => '${m['id']}' == id);
    if (_memories.length != before) _saveMems();
    return {'ok': _memories.length != before};
  }

  Future<Map<String, dynamic>> memoryClear() async {
    _memories.clear();
    _saveMems();
    return {'ok': true};
  }

  /// 自动记忆总结：每 25 条主对话把最早的一条"对话摘要"写进记忆（真人会自己记）
  /// ★27.0.8 Step1：让模型同时输出重要度 1-10，格式「内容 || 数字」；解析失败时重要度默认 5
  Future<void> _maybeAutoSummary() async {
    if (_chatCount % 25 != 0) return;
    if (_memories.length > 400) return; // 太多就不自动加了
    final hist = (await MsgsLocal.load('baona')).map((m) => m.toJson()).toList();
    if (hist.length < 20) return;
    final recent = hist.sublist(hist.length - 20);
    final ctx = [
      {'role': 'system', 'content': '你是包娜，帮自己把最近这段对话浓缩成一条"记忆"，第三人称（"他……""我……"），30 字以内，一句话。只输出一行：内容 || 重要度（1-10 的数字，数字越大越值得长期记住）。不要别的。'},
      ...recent.map((m) => {'role': '${m['role'] == 'me' ? 'user' : 'assistant'}', 'content': '${m['content'] ?? ''}'.substring(0, ('${m['content'] ?? ''}'.length > 120 ? 120 : '${m['content'] ?? ''}'.length))}),
    ];
    final r = await _ask(ctx, maxT: 120);
    if (r['ok'] == true) {
      final raw = _stripWish('${r['content']}'.trim());
      var s = raw;
      var imp = 5.0;
      final sep = raw.lastIndexOf('||');
      if (sep > 0) {
        s = raw.substring(0, sep).trim();
        final n = double.tryParse(raw.substring(sep + 2).trim());
        if (n != null) imp = n.clamp(1, 10).toDouble();
      }
      if (s.isNotEmpty && !_memories.any((m) => '${m['text']}' == s)) {
        _memories.add({'id': 's${DateTime.now().millisecondsSinceEpoch}', 't': DateTime.now().millisecondsSinceEpoch, 'text': s.length > 200 ? s.substring(0, 200) : s, 'cat': '对话', 'type': 'summary', 'importance': imp});
        _saveMems();
      }
    }
  }

  // -------------------- 人设 / 设置（本地直存直生效） --------------------
  Future<Map<String, dynamic>> herSettings() async {
    final s = Map<String, dynamic>.from(_herSet);
    s['persona'] = Store.localPersona;
    s['nickName'] = _herSet['nickName'] ?? '包娜';
    s['sleepStart'] = _herSet['sleepStart'] ?? '23:30';
    s['sleepEnd'] = _herSet['sleepEnd'] ?? '07:30';
    s['outfit'] = _herSet['outfit'] ?? '';
    s['herAvatar'] = _herSet['herAvatar'] ?? '';
    s['myAvatar'] = _herSet['myAvatar'] ?? '';
    s['voiceMode'] = _herSet['voiceMode'] ?? false;
    s['voiceMessageEnabled'] = _herSet['voiceMessageEnabled'] ?? false;
    s['useMemories'] = _herSet['useMemories'] ?? true;
    s['autoChatEnabled'] = _herSet['autoChatEnabled'] ?? false;
    s['emoteEnabled'] = _herSet['emoteEnabled'] ?? true;
    s['greetEnabled'] = _herSet['greetEnabled'] ?? false;
    return {'ok': true, 's': s, 'settings': s};
  }

  Future<Map<String, dynamic>> patchSettings(Map<String, dynamic> patch) async {
    final p = (patch['patch'] is Map) ? Map<String, dynamic>.from(patch['patch'] as Map) : Map<String, dynamic>.from(patch);
    if (p.containsKey('persona')) {
      await Store.setLocalPersona('${p['persona'] ?? ''}');
      p.remove('persona');
    }
    _herSet.addAll(p);
    _saveHerSet();
    return {'ok': true};
  }

  // -------------------- 表情（本地） --------------------
  Future<Map<String, dynamic>> emojiList() async {
    final mine = <String>[];
    final all = <String>[];
    for (final e in _emoji) {
      try {
        final m = jsonDecode(e);
        if (m is Map) {
          all.add('${m['name'] ?? ''}');
          if (m['mine'] == true) mine.add('${m['name'] ?? ''}');
        }
      } catch (_) {}
    }
    return {'ok': true, 'list': all, 'mine': mine};
  }

  Future<Map<String, dynamic>> emojiAdd(String data, [String name = '']) async {
    final n = name.isNotEmpty ? name : 'e${DateTime.now().millisecondsSinceEpoch}';
    _emoji.add(jsonEncode({'name': n, 'data': data, 'mine': true}));
    _saveEmoji();
    return {'ok': true};
  }

  Future<Map<String, dynamic>> emojiDel(String name) async {
    _emoji.removeWhere((e) {
      try {
        final m = jsonDecode(e);
        return m is Map && '${m['name']}' == name;
      } catch (_) {
        return false;
      }
    });
    _saveEmoji();
    return {'ok': true};
  }

  String emojiUrl(String name) {
    for (final e in _emoji) {
      try {
        final m = jsonDecode(e);
        if (m is Map && '${m['name']}' == name) return '${m['data'] ?? ''}';
      } catch (_) {}
    }
    return '';
  }

  String imgUrl(String path) => path;
  String voiceUrl(String path) => path;

  // -------------------- 愿望 --------------------
  Future<Map<String, dynamic>> wishes() async {
    final ws = ((_wishes['wishes'] as List?) ?? []).map((w) => Map<String, dynamic>.from(w as Map)).toList().reversed.toList();
    final pend = ws.where((w) => '${w['status'] ?? ''}' != 'done').length;
    return {
      'ok': true,
      'granted': (_wishes['granted'] as num?)?.toInt() ?? 0,
      'used': (_wishes['used'] as num?)?.toInt() ?? 0,
      'done': (_wishes['done'] as num?)?.toInt() ?? 0,
      'pending': pend,
      'wishes': ws.map((w) => {
            'id': '${w['id']}',
            'text': '${w['content'] ?? ''}',
            'status': '${w['status'] ?? 'pending'}',
            't': (w['at'] as num?)?.toInt() ?? 0,
            'grantedAt': (w['at'] as num?)?.toInt() ?? 0,
            'doneAt': (w['doneAt'] as num?)?.toInt() ?? 0,
          }).toList(),
    };
  }

  Future<Map<String, dynamic>> wishesAction(String act, String val, [String content = '']) async {
    final ws = (_wishes['wishes'] as List?) ?? [];
    final n = int.tryParse(val) ?? 0;
    if (act == 'grant') {
      _wishes['granted'] = ((_wishes['granted'] as num?)?.toInt() ?? 0) + (n > 0 ? n : 1);
    } else if (act == 'use') {
      final granted = (_wishes['granted'] as num?)?.toInt() ?? 0;
      _wishes['used'] = (((_wishes['used'] as num?)?.toInt() ?? 0) + (n > 0 ? n : 1)).clamp(0, granted);
    } else if (act == 'done') {
      for (final w in ws) {
        if ('${w['id']}' == val && '${w['status'] ?? ''}' != 'done') {
          w['status'] = 'done';
          w['doneAt'] = DateTime.now().millisecondsSinceEpoch;
          _wishes['done'] = ((_wishes['done'] as num?)?.toInt() ?? 0) + 1;
          break;
        }
      }
    } else if (act == 'remove') {
      ws.removeWhere((w) => '${w['id']}' == val);
      _wishes['wishes'] = ws;
    } else if (act == 'add') {
      final c = content.trim();
      if (c.isNotEmpty) {
        ws.add({'id': 'w${DateTime.now().millisecondsSinceEpoch}${ws.length}', 'content': c, 'at': DateTime.now().millisecondsSinceEpoch, 'status': 'pending'});
        _wishes['wishes'] = ws;
      }
    }
    _saveWishes();
    return {'ok': true};
  }

  // -------------------- 商城（全本地：内置 1600 商品 + 双钱包 + 背包） --------------------
  Future<Map<String, dynamic>> shop() async {
    final log = ((_wallet['log'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    return {
      'ok': true,
      'my': (_wallet['my'] as num?)?.toInt() ?? 0,
      'her': (_wallet['her'] as num?)?.toInt() ?? 0,
      'logAll': log.length,
      'bagMe': _bagMe.map((e) => Map<String, dynamic>.from(e)).toList(),
      'bagHer': _bagHer.map((e) => Map<String, dynamic>.from(e)).toList(),
      'log': log,
      'cats': kShopCats.map((e) => Map<String, dynamic>.from(e)).toList(),
    };
  }

  Future<Map<String, dynamic>> catalog() async => {'ok': true, 'items': kShopItems.map((e) => Map<String, dynamic>.from(e)).toList()};

  Map<String, dynamic> _itemOf(String code) {
    for (final it in kShopItems) {
      if ('${it['code']}' == code) return it;
    }
    return {};
  }

  void _pushLog(String who, String act, String name, int price) {
    final log = ((_wallet['log'] as List?) ?? []);
    log.add({'t': DateTime.now().millisecondsSinceEpoch, 'who': who, 'act': act, 'name': name, 'price': price});
    if (log.length > 200) log.removeRange(0, log.length - 200);
    _wallet['log'] = log;
  }

  String _newBagId() => 'b${DateTime.now().millisecondsSinceEpoch}${_bagMe.length}${_bagHer.length}';

  Future<Map<String, dynamic>> shopBuy(String code, bool forHer) async {
    final it = _itemOf(code);
    if (it.isEmpty) return {'ok': false, 'error': '没有这个商品'};
    final price = (it['price'] as num?)?.toInt() ?? 0;
    final my = (_wallet['my'] as num?)?.toInt() ?? 0;
    final her = (_wallet['her'] as num?)?.toInt() ?? 0;
    if (forHer ? (her < price) : (my < price)) return {'ok': false, 'error': '钱不够，先给她转点吧'};
    final item = {
      'id': _newBagId(),
      'code': code,
      'name': '${it['name'] ?? ''}',
      'price': price,
      'img': '${it['img'] ?? ''}',
      'ts': DateTime.now().millisecondsSinceEpoch,
      'used': 0,
      'by': forHer ? 'her' : 'me',
      'forHer': forHer,
    };
    if (forHer) {
      _wallet['her'] = her - price;
      _bagHer.add(item);
      _pushLog('her', 'buy', '${it['name']}', price);
    } else {
      _wallet['my'] = my - price;
      _bagMe.add(item);
      _pushLog('me', 'buy', '${it['name']}', price);
    }
    _saveWallet();
    _saveBag();
    _ev.add({'type': 'shop', 'state': await shop()});
    return {'ok': true, 'state': await shop()};
  }

  Future<Map<String, dynamic>> shopUse(String id) async {
    final i = _bagMe.indexWhere((e) => '${e['id']}' == id);
    if (i < 0) return {'ok': false, 'error': '背包里没有这个'};
    final it = _itemOf('${_bagMe[i]['code']}');
    final durable = it['durable'] != false;
    _bagMe[i]['used'] = ((_bagMe[i]['used'] as num?)?.toInt() ?? 0) + 1;
    if (!durable) {
      _bagMe.removeAt(i);
    }
    _saveBag();
    _ev.add({'type': 'shop', 'state': await shop()});
    return {'ok': true, 'state': await shop(), 'durable': durable};
  }

  Future<Map<String, dynamic>> shopGive(String id) async {
    final i = _bagMe.indexWhere((e) => '${e['id']}' == id);
    if (i < 0) return {'ok': false, 'error': '背包里没有这个'};
    final item = _bagMe.removeAt(i);
    item['by'] = 'her';
    item['forHer'] = true;
    _bagHer.add(item);
    _saveBag();
    _ev.add({'type': 'shop', 'state': await shop()});
    return {'ok': true, 'state': await shop()};
  }

  Future<Map<String, dynamic>> shopPay(int v) async {
    final my = (_wallet['my'] as num?)?.toInt() ?? 0;
    if (v <= 0 || my < v) return {'ok': false, 'error': '余额不够'};
    _wallet['my'] = my - v;
    _wallet['her'] = ((_wallet['her'] as num?)?.toInt() ?? 0) + v;
    _pushLog('me', 'pay', '转账给她', v);
    _saveWallet();
    _ev.add({'type': 'shop', 'state': await shop()});
    return {'ok': true, 'state': await shop()};
  }

  Future<Map<String, dynamic>> shopEarn(int v) async {
    _wallet['her'] = ((_wallet['her'] as num?)?.toInt() ?? 0) + v;
    _pushLog('me', 'reward', '奖励她', v);
    _saveWallet();
    _ev.add({'type': 'shop', 'state': await shop()});
    return {'ok': true, 'state': await shop()};
  }

  // -------------------- 飞行棋（全本地：48 格蛇形 + 掷骰子 + 格子事件） --------------------
  static const List<Map<String, dynamic>> kTileEvents = [
    {'k': 'bonus', 't': '她给你揉揉肩，心情大好'}, // 2
    {'k': 'malus', 't': '被她亲晕了，倒退2格'}, // 3
    {'k': 'none', 't': '一起吃了碗面，原地休息'}, // 4
    {'k': 'bonus', 't': '她偷偷给你充了灵石，前进2格'}, // 5
    {'k': 'skip', 't': '你惹她生气了，下一回合跳过'}, // 6
    {'k': 're', 't': '走火入魔，回到起点'}, // 7
    {'k': 'bonus', 't': '今晚她全听你的，前进3格'}, // 8
    {'k': 'malus', 't': '被雷劈了一下，倒退1格'}, // 9
    {'k': 'again', 't': '捡到一颗回灵丹，再掷一次'}, // 10
    {'k': 'none', 't': '她在旁边看手机，没理你'}, // 11
    {'k': 'swap', 't': '中了换魂术，位置互换'}, // 12
    {'k': 'bonus', 't': '她亲了你一口，前进1格'}, // 13
    {'k': 'malus', 't': '乱花灵石，倒退2格'}, // 14
    {'k': 'none', 't': '一起看星星，原地休息'}, // 15
    {'k': 'bonus', 't': '她答应今晚陪你，前进2格'}, // 16
    {'k': 'skip', 't': '她闹小脾气，下一回合跳过'}, // 17
    {'k': 'malus', 't': '踩到蛇，吓一跳倒退3格'}, // 18
    {'k': 'again', 't': '捡到法器残片，再掷一次'}, // 19
    {'k': 'none', 't': '她给你剥了个橘子'}, // 20
    {'k': 're', 't': '被师父抓包，回到起点'}, // 21
    {'k': 'bonus', 't': '她夸你今天好帅，前进2格'}, // 22
    {'k': 'malus', 't': '手机掉水里，倒退1格'}, // 23
    {'k': 'none', 't': '靠着她肩膀休息'}, // 24
    {'k': 'swap', 't': '中了移形换位，位置互换'}, // 25
    {'k': 'bonus', 't': '她喂你吃糖，前进1格'}, // 26
    {'k': 'malus', 't': '熬夜修仙失败，倒退2格'}, // 27
    {'k': 'again', 't': '悟出心法，再掷一次'}, // 28
    {'k': 'none', 't': '她哼着歌，心情很好'}, // 29
    {'k': 'bonus', 't': '她答应给你一个愿望，前进3格'}, // 30
    {'k': 'skip', 't': '你惹她哭了，下一回合跳过'}, // 31
    {'k': 'malus', 't': '灵力耗尽，倒退3格'}, // 32
    {'k': 'none', 't': '一起喝了杯奶茶'}, // 33
    {'k': 'swap', 't': '中了乾坤挪移，位置互换'}, // 34
    {'k': 'bonus', 't': '她偷偷看你，前进2格'}, // 35
    {'k': 'malus', 't': '被乌鸦啄了，倒退1格'}, // 36
    {'k': 'again', 't': '捡到灵药，再掷一次'}, // 37
    {'k': 'none', 't': '她给你吹了吹眼睛'}, // 38
    {'k': 'bonus', 't': '她答应明天陪你，前进2格'}, // 39
    {'k': 'malus', 't': '迷路了，倒退2格'}, // 40
    {'k': 'none', 't': '她说"老公最好了"'}, // 41
    {'k': 're', 't': '中了摄魂阵，回到起点'}, // 42
    {'k': 'bonus', 't': '她钻进你怀里，前进3格'}, // 43
    {'k': 'skip', 't': '她睡着了，下一回合跳过'}, // 44
    {'k': 'malus', 't': '灵石被偷，倒退1格'}, // 45
    {'k': 'again', 't': '顿悟了，再掷一次'}, // 46
    {'k': 'none', 't': '她看着你笑'}, // 47
  ];

  // -------------------- 控制器（全本地：简化状态机，替代电脑端 ctrl API） --------------------
  Map<String, dynamic> _newCtrl() => {
    'arousal': 0,
    'level': 0,
    'pattern': 'slow',
    'mode': 'idle',
    'heDone': 'none',
    'movingAll': true,
    'edgeCount': 0,
    'sessEdge': 0,
    'bond': 0,
    'play': 'none',
  };

  Future<Map<String, dynamic>> ctrl() async => {'ok': true, 'ctrl': Map<String, dynamic>.from(_ctrl)};

  Future<Map<String, dynamic>> ctrlCmd(String cmd, [dynamic val]) async {
    final c = _ctrl;
    final now = DateTime.now().millisecondsSinceEpoch;
    switch (cmd) {
      case 'tap':
        c['arousal'] = ((c['arousal'] as num?)?.toInt() ?? 0) + 2;
        break;
      case 'arousalAdd':
        final n = (val is num ? val.toInt() : int.tryParse('$val') ?? 0);
        c['arousal'] = (((c['arousal'] as num?)?.toInt() ?? 0) + n).clamp(0, 100);
        break;
      case 'arousalReset':
        c['arousal'] = 0;
        break;
      case 'level':
        c['level'] = val;
        break;
      case 'pattern':
        c['pattern'] = '$val';
        break;
      case 'mode':
        c['mode'] = '$val';
        break;
      case 'finish':
        c['finish'] = '$val';
        break;
      case 'heDone':
        c['heDone'] = '$val';
        break;
      case 'play':
        c['play'] = '$val';
        break;
      case 'movingAll':
        c['movingAll'] = val == true;
        break;
      case 'param':
        break; // 本地无 playbook，忽略参数项
    }
    // ★本地简化：兴奋度 ≥ 100 记一次"高潮"，清零重来
    if (((c['arousal'] as num?)?.toInt() ?? 0) >= 100) {
      c['edgeCount'] = ((c['edgeCount'] as num?)?.toInt() ?? 0) + 1;
      c['sessEdge'] = ((c['sessEdge'] as num?)?.toInt() ?? 0) + 1;
      c['bond'] = ((c['bond'] as num?)?.toInt() ?? 0) + 1;
      c['arousal'] = 0;
      c['at'] = now;
    }
    _saveCtrl();
    _ev.add({'type': 'ctrl', 'state': Map<String, dynamic>.from(c)});
    return {'ok': true, 'ctrl': Map<String, dynamic>.from(c)};
  }

  Map<String, dynamic> _newGame() {    final tiles = <Map<String, dynamic>>[];
    for (var i = 1; i <= 48; i++) {
      if (i == 1) {
        tiles.add({'i': 1, 't': '起点', 'k': 'start'});
      } else if (i == 48) {
        tiles.add({'i': 48, 't': '终点 · 她属于你', 'k': 'end'});
      } else {
        final e = kTileEvents[(i - 2) % kTileEvents.length];
        tiles.add({'i': i, 't': e['t'], 'k': e['k']});
      }
    }
    return {
      'on': false,
      'pos': 1,
      'me': 1,
      'her': 1,
      'turn': 'me',
      'skipMe': false,
      'skipHer': false,
      'winner': null,
      'prize': null,
      'log': [],
      'seq': 0,
      'mode': 'adv',
      'wins': {'me': 0, 'her': 0},
      'n': 48,
      'tiles': tiles,
      'modes': [
        {'id': 'adv', 'name': '修仙趣事'},
        {'id': 'basic', 'name': '纯走路'},
      ],
    };
  }

  Future<Map<String, dynamic>> game() async => {'ok': true, 'state': Map<String, dynamic>.from(_game)};

  Future<Map<String, dynamic>> gameMode(String id) async {
    final m = id == 'basic' ? 'basic' : 'adv';
    _game['mode'] = m;
    final tiles = <Map<String, dynamic>>[];
    for (var i = 1; i <= 48; i++) {
      if (i == 1) {
        tiles.add({'i': 1, 't': '起点', 'k': 'start'});
      } else if (i == 48) {
        tiles.add({'i': 48, 't': '终点 · 她属于你', 'k': 'end'});
      } else if (m == 'basic') {
        tiles.add({'i': i, 't': '$i', 'k': 'none'});
      } else {
        final e = kTileEvents[(i - 2) % kTileEvents.length];
        tiles.add({'i': i, 't': e['t'], 'k': e['k']});
      }
    }
    _game['tiles'] = tiles;
    _game['me'] = 1;
    _game['her'] = 1;
    _game['turn'] = 'me';
    _game['skipMe'] = false;
    _game['skipHer'] = false;
    _game['winner'] = null;
    _game['log'] = [];
    _saveGame();
    _ev.add({'type': 'game', 'state': Map<String, dynamic>.from(_game)});
    return {'ok': true, 'state': Map<String, dynamic>.from(_game)};
  }

  Future<Map<String, dynamic>> gameTile(int i, String text) async {
    final tiles = ((_game['tiles'] as List?) ?? []);
    final idx = tiles.indexWhere((t) => (t['i'] as num?)?.toInt() == i);
    if (idx < 0) return {'ok': false, 'error': '没有这格'};
    final k = text.trim().isEmpty ? (i <= 1 ? 'start' : (i >= 48 ? 'end' : '${kTileEvents[(i - 2) % kTileEvents.length]['k']}')) : 'none';
    final t = text.trim().isEmpty ? (i <= 1 ? '起点' : (i >= 48 ? '终点 · 她属于你' : '${kTileEvents[(i - 2) % kTileEvents.length]['t']}')) : text.trim();
    tiles[idx] = {'i': i, 't': t, 'k': k};
    _game['tiles'] = tiles;
    _saveGame();
    _ev.add({'type': 'game', 'state': Map<String, dynamic>.from(_game)});
    return {'ok': true, 'state': Map<String, dynamic>.from(_game)};
  }

  Future<Map<String, dynamic>> gameRoll(String who) async {
    if (_game['winner'] != null) return {'ok': true, 'state': Map<String, dynamic>.from(_game)};
    final tiles = ((_game['tiles'] as List?) ?? []);
    final n = (_game['n'] as num?)?.toInt() ?? 48;
    final turn = '${_game['turn'] ?? 'me'}';
    if (who != turn) return {'ok': false, 'error': '还没轮到你'};
    final skipKey = turn == 'me' ? 'skipMe' : 'skipHer';
    final log = ((_game['log'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    if (_game[skipKey] == true) {
      _game[skipKey] = false;
      _game['turn'] = turn == 'me' ? 'her' : 'me';
      log.add({'t': '${turn == 'me' ? '我' : '她'}这回合跳过'});
      _game['log'] = log;
      _saveGame();
      _ev.add({'type': 'game', 'state': Map<String, dynamic>.from(_game)});
      return {'ok': true, 'state': Map<String, dynamic>.from(_game)};
    }
    final dice = 1 + (DateTime.now().millisecondsSinceEpoch % 6);
    var pos = ((_game[turn] as num?)?.toInt() ?? 1) + dice;
    log.add({'t': '${turn == 'me' ? '我' : '她'}掷出 $dice 点，走到第 $pos 格'});
    String? bonus;
    if (pos >= n) {
      pos = n;
      final wins = Map<String, dynamic>.from(_game['wins'] as Map? ?? {});
      wins[turn] = ((wins[turn] as num?)?.toInt() ?? 0) + 1;
      _game['wins'] = wins;
      _game['winner'] = turn;
      _game['me'] = pos;
      _game['her'] = pos;
      log.add({'t': '${turn == 'me' ? '我' : '她'}到终点啦！'});
    } else {
      final tile = tiles.firstWhere((t) => (t['i'] as num?)?.toInt() == pos, orElse: () => {'k': 'none', 't': ''});
      final k = '${tile['k'] ?? 'none'}';
      final tt = '${tile['t'] ?? ''}';
      var eff = 0;
      if (k == 'bonus') {
        eff = (pos % 3) + 1;
        pos += eff;
        bonus = '踩到「$tt」，前进 $eff 格';
      } else if (k == 'malus') {
        eff = (pos % 3) + 1;
        pos -= eff;
        if (pos < 1) pos = 1;
        bonus = '踩到「$tt」，倒退 $eff 格';
      } else if (k == 're') {
        pos = 1;
        bonus = '踩到「$tt」，回到起点';
      } else if (k == 'skip') {
        _game[skipKey] = true;
        bonus = '踩到「$tt」，下一回合跳过';
      } else if (k == 'swap') {
        final other = turn == 'me' ? 'her' : 'me';
        final op = ((_game[other] as num?)?.toInt() ?? 1);
        _game[other] = pos;
        pos = op;
        bonus = '踩到「$tt」，位置互换';
      } else if (k == 'again') {
        _game[turn] = pos;
        _game['turn'] = turn;
        if (bonus != null) log.add({'t': bonus});
        log.add({'t': '踩到「$tt」，再掷一次'});
        _game['log'] = log;
        _saveGame();
        _ev.add({'type': 'game', 'state': Map<String, dynamic>.from(_game)});
        return {'ok': true, 'state': Map<String, dynamic>.from(_game)};
      } else {
        bonus = '踩到「$tt」';
      }
      if (pos > n) pos = n;
      if (pos == n) {
        final wins = Map<String, dynamic>.from(_game['wins'] as Map? ?? {});
        wins[turn] = ((wins[turn] as num?)?.toInt() ?? 0) + 1;
        _game['wins'] = wins;
        _game['winner'] = turn;
      }
      _game[turn] = pos;
      if (bonus != null) log.add({'t': bonus});
      _game['turn'] = turn == 'me' ? 'her' : 'me';
    }
    if (log.length > 30) log.removeRange(0, log.length - 30);
    _game['log'] = log;
    _game['seq'] = ((_game['seq'] as num?)?.toInt() ?? 0) + 1;
    _saveGame();
    _ev.add({'type': 'game', 'state': Map<String, dynamic>.from(_game)});
    return {'ok': true, 'state': Map<String, dynamic>.from(_game)};
  }

  // -------------------- 相册（全本地：手机选照片存 App 目录，分组展示） --------------------
  Future<Map<String, dynamic>> album() async {
    final groups = _albums.map((g) {
      final photos = ((g['photos'] as List?) ?? []).map((e) {
        final p = Map<String, dynamic>.from(e as Map);
        final pid = '${p['id'] ?? ''}';
        p['likes'] = _albumLikes[pid] == true ? 1 : 0;
        p['commentCount'] = ((_albumCmt[pid] as List?) ?? []).length;
        return p;
      }).toList();
      return {'id': g['id'], 'name': g['name'], 'photos': photos};
    }).toList();
    return {'ok': true, 'groups': groups};
  }

  Future<Map<String, dynamic>> albumGroup(String act, String name) async {
    if (act == 'add') {
      final n = name.trim();
      if (n.isEmpty) return {'ok': false, 'error': '名字不能空'};
      _albums.add({'id': 'g${DateTime.now().millisecondsSinceEpoch}${_albums.length}', 'name': n, 'photos': []});
      _saveAlbums();
      return {'ok': true, 'groups': await _groupsJson()};
    }
    if (act == 'del') {
      _albums.removeWhere((g) => '${g['id']}' == name);
      _saveAlbums();
      return {'ok': true, 'groups': await _groupsJson()};
    }
    return {'ok': false, 'error': '未知操作'};
  }

  Future<List<Map<String, dynamic>>> _groupsJson() async =>
      _albums.map((g) => Map<String, dynamic>.from(g)).toList();

  Future<Map<String, dynamic>> albumUpload(String gid, String dataUrl) async {
    try {
      final gi = _albums.indexWhere((g) => '${g['id']}' == gid);
      if (gi < 0) return {'ok': false, 'error': '没有这个分组'};
      final m = RegExp(r'^data:image/(\w+);base64,(.*)$', dotAll: true).firstMatch(dataUrl);
      if (m == null) return {'ok': false, 'error': '图片格式不对'};
      final ext = m.group(1) == 'png' ? 'png' : 'jpg';
      final bytes = base64Decode(m.group(2)!);
      final dir = await getApplicationDocumentsDirectory();
      final ad = Directory('${dir.path}/albums');
      if (!ad.existsSync()) ad.createSync(recursive: true);
      final f = File('${ad.path}/${DateTime.now().millisecondsSinceEpoch}.$ext');
      await f.writeAsBytes(bytes, flush: true);
      // ★26.2.20 双写系统相册：App 重装（卸载）后照片还在系统相册里，重新导入就能找回
      try {
        final ps = await PhotoManager.requestPermissionExtend();
        if (ps.hasAccess) {
          await PhotoManager.editor.saveImage(bytes,
              filename: 'baona_${DateTime.now().millisecondsSinceEpoch}.$ext');
        }
      } catch (_) {}
      final photos = ((_albums[gi]['photos'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      photos.add({'id': 'p${DateTime.now().millisecondsSinceEpoch}${photos.length}', 'path': f.path, 'time': DateTime.now().millisecondsSinceEpoch});
      _albums[gi]['photos'] = photos;
      _saveAlbums();
      return {'ok': true, 'id': 'p${DateTime.now().millisecondsSinceEpoch}${photos.length}', 'url': f.path, 'groups': await _groupsJson()};
    } catch (e) {
      return {'ok': false, 'error': '存不进去：$e'};
    }
  }

  Future<Map<String, dynamic>> albumLike(String pid) async {
    _albumLikes[pid] = true;
    _saveAlbums();
    return {'ok': true};
  }

  Future<Map<String, dynamic>> albumComment(String pid, String text) async {
    final t = text.trim();
    if (t.isEmpty) return {'ok': true};
    final list = ((_albumCmt[pid] as List?) ?? []).map((e) => '$e').toList();
    list.add(t);
    _albumCmt[pid] = list;
    _saveAlbums();
    return {'ok': true};
  }

  // -------------------- 兼容接口（页面可能用到） --------------------
  Future<Map<String, dynamic>> bootstrap() async {
    final s = await herSettings();
    return {'ok': true, 'nick': s['s']?['nickName'] ?? '包娜', 'status': '包娜在线', 'online': true, 'voiceEnabled': false, 'coupleEnabled': false, 'settings': s['s']};
  }

  Future<Map<String, dynamic>> state() async => {'ok': true, 'status': '包娜在线', 'nick': _herSet['nickName'] ?? '包娜', 'online': true};
  Future<Map<String, dynamic>> mood() async => {'ok': true, 'mood': '开心'};
  Future<Map<String, dynamic>> skills() async => {'ok': true, 'skills': []};
  Future<String> ping() async => '通了 · 本地模式';

  void dispose() {
    _ev.close();
  }
}
