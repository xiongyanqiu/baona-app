// brain.dart — 本地大脑（26.2.17 全本地化）
// 手机端自己直连 LLM API：人设 / 上下文(按token) / 记忆 / 愿望 / 角色 / 群聊 全部在手机本地，
// 不再依赖电脑桌宠。商城/游戏/相册等娱乐功能仍可"连电脑"使用（走 app.api）。
// 与 Api 同名的方法返回相同 JSON 结构，页面切换 app.api → app.brain 即可。
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'msglocal.dart';
import 'roles_data.dart';

class LocalBrain {
  LocalBrain() {
    _load();
  }

  final StreamController<Map<String, dynamic>> _ev = StreamController.broadcast();
  Stream<Map<String, dynamic>> get events => _ev.stream;

  // -------------------- 内存态（全部有 Store 落盘） --------------------
  List<Map<String, dynamic>> _providers = [];
  String _activeId = '';
  List<Map<String, dynamic>> _memories = []; // {id,t,text,cat,type}
  Map<String, dynamic> _wishes = {'granted': 0, 'used': 0, 'done': 0, 'wishes': []};
  List<Map<String, dynamic>> _groups = []; // {id,name,members:[roleId]}
  List<Map<String, dynamic>> _roles = []; // 自建角色 {id,name,letter,persona,rules}
  List<String> _emoji = []; // {name:dataURL} 的 JSON 字符串列表
  Map<String, dynamic> _herSet = {}; // 人设 / 开关们 / 昵称 等
  Map<String, dynamic> _roleMems = {}; // roleId -> [记忆 JSON]
  int _chatCount = 0; // 主对话累计条数（自动摘要触发）

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
    try { _wishes = Map<String, dynamic>.from(jsonDecode(Store.localWishes) as Map? ?? {'granted': 0, 'used': 0, 'done': 0, 'wishes': []}); } catch (_) {}
    try { _groups = ((jsonDecode(Store.localGroups) as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList(); } catch (_) {}
    try { _roles = ((jsonDecode(Store.localRoles) as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList(); } catch (_) {}
    try { _emoji = ((jsonDecode(Store.localEmoji) as List?) ?? []).map((e) => '$e').toList(); } catch (_) {}
    try { _herSet = Map<String, dynamic>.from(jsonDecode(Store.localHerSet) as Map? ?? {}); } catch (_) {}
    try { _roleMems = Map<String, dynamic>.from(jsonDecode(Store.localChatExtra) as Map? ?? {}); } catch (_) {}
    if (_groups.isEmpty) {
      // 默认姐妹群：包娜 + 刘紫灵（成员可自己改）
      _groups.add({'id': 'nvg', 'name': '姐妹聊天群', 'members': ['baona', 'liuziling']});
    }
  }

  void _saveLlm() => Store.setLlmCfgJson(jsonEncode({'providers': _providers, 'activeId': _activeId}));
  void _saveMems() => Store.setLocalMemories(jsonEncode(_memories));
  void _saveWishes() => Store.setLocalWishes(jsonEncode(_wishes));
  void _saveGroups() => Store.setLocalGroups(jsonEncode(_groups));
  void _saveRoles() => Store.setLocalRoles(jsonEncode(_roles));
  void _saveEmoji() => Store.setLocalEmoji(jsonEncode(_emoji));
  void _saveHerSet() => Store.setLocalHerSet(jsonEncode(_herSet));
  void _saveRoleMems() => Store.setLocalChatExtra(jsonEncode(_roleMems));

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

  String _memoryBlock() {
    if (_herSet['useMemories'] == false) return '';
    final typed = _memories.where((m) => '${m['type'] ?? ''}'.isNotEmpty).toList();
    final raws = _memories.where((m) => '${m['type'] ?? ''}'.isEmpty).toList();
    final takeTyped = typed.length > 80 ? typed.sublist(typed.length - 80) : typed;
    final takeRaw = raws.length > 140 ? raws.sublist(raws.length - 140) : raws;
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

  String _wishBlock() {
    final ws = (_wishes['wishes'] as List?) ?? [];
    final pend = ws.where((w) => '${w['status'] ?? ''}' != 'done').toList();
    if (pend.isEmpty) return '';
    return '【你答应过老公的愿望（还没兑现的；兑现了就自然提，别机械报数）】\n${pend.map((w) => '· ${w['content']}').join('\n')}';
  }

  String _outRules() {
    final sb = StringBuffer();
    sb.write('说话：像微信打字，只发你说的话——不写动作、不写括号、不写星号、不写表情符号；短句、口语、有来有回，想发几条发几条。');
    sb.write('你答应老公的愿望时，在回复里用标记 <<愿望：愿望内容>> 写下；他许愿/你想要满足他时用 <<给愿望：次数>> 送他愿望次数；愿望兑现了用 <<愿望完成：内容>> 标一下。标记不会显示给他看。');
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
  List<Map<String, dynamic>> _buildCtx(List<Map<String, dynamic>> hist,
      {String? persona, String? rules, bool withWish = true, bool withMem = true}) {
    final sysParts = <String>[
      persona ?? _persona(),
      if (rules != null && rules.trim().isNotEmpty) rules.trim(),
      if (withMem) _memoryBlock(),
      if (withWish) _wishBlock(),
      _outRules(),
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
    final ctx = _buildCtx(hist);
    final r = await _ask(ctx);
    _ev.add({'type': 'typing', 'on': false});
    if (r['ok'] != true) return r;
    var content = '${r['content']}';
    _parseWish(content);
    content = _stripWish(content);
    if (content.isEmpty) return {'ok': true};
    _chatCount++;
    _maybeAutoSummary();
    final t = DateTime.now().millisecondsSinceEpoch;
    _ev.add({'type': 'msg', 'msg': {'role': 'assistant', 'content': content, 'time': t, 'cid': 'a$t'}});
    return {'ok': true};
  }

  Future<Map<String, dynamic>> history({int limit = 30}) async {
    final list = (await MsgsLocal.load('baona')).map((m) => m.toJson()).toList();
    final take = list.length > limit ? list.sublist(list.length - limit) : list;
    return {'ok': true, 'messages': take, 'hasMore': list.length > limit};
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
    _ev.add({'type': 'msg', 'msg': {'role': 'assistant', 'content': content, 'time': now, 'cid': 'a$now', 'roleId': role, 'name': '${info['name']}'}});
    return {'ok': true};
  }

  Future<Map<String, dynamic>> roleClear(String role) async {
    await MsgsLocal.clear('role_$role');
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
    await MsgsLocal.clear('role_$role');
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
    final replies = <Map<String, dynamic>>[];
    final budget = Store.ctxTokens;
    var used = hist.fold<int>(0, (a, m) => a + ('${m['content'] ?? ''}'.length) + 8);
    for (final rid in members) {
      final info = _roleInfo(rid);
      if (info == null) continue;
      final ctx = _buildCtx(hist, persona: '${info['persona']}', rules: '${info['rules']}', withWish: false, withMem: false);
      used = ctx.fold<int>(0, (a, m) => a + '${m['content'] ?? ''}'.length);
      if (used > budget) {
        // 上下文太长了，丢掉最旧的历史再试一次
        final cut = (hist.length * 0.4).round();
        hist.removeRange(0, cut < 1 ? 1 : cut);
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
      replies.add({'roleId': rid, 'name': '${info['name']}', 'content': c, 'time': now});
    }
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
  Future<void> _maybeAutoSummary() async {
    if (_chatCount % 25 != 0) return;
    if (_memories.length > 400) return; // 太多就不自动加了
    final hist = (await MsgsLocal.load('baona')).map((m) => m.toJson()).toList();
    if (hist.length < 20) return;
    final recent = hist.sublist(hist.length - 20);
    final ctx = [
      {'role': 'system', 'content': '你是包娜，帮自己把最近这段对话浓缩成一条"记忆"，第三人称（"他……""我……"），30 字以内，一句话。只输出那句话，不要别的。'},
      ...recent.map((m) => {'role': '${m['role'] == 'me' ? 'user' : 'assistant'}', 'content': '${m['content'] ?? ''}'.substring(0, ('${m['content'] ?? ''}'.length > 120 ? 120 : '${m['content'] ?? ''}'.length))}),
    ];
    final r = await _ask(ctx, maxT: 120);
    if (r['ok'] == true) {
      final s = _stripWish('${r['content']}'.trim());
      if (s.isNotEmpty && !_memories.any((m) => '${m['text']}' == s)) {
        _memories.add({'id': 's${DateTime.now().millisecondsSinceEpoch}', 't': DateTime.now().millisecondsSinceEpoch, 'text': s.length > 200 ? s.substring(0, 200) : s, 'cat': '对话', 'type': 'summary'});
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
    final num = int.tryParse(val) ?? 0;
    if (act == 'grant') {
      _wishes['granted'] = ((_wishes['granted'] as num?)?.toInt() ?? 0) + (num > 0 ? num : 1);
    } else if (act == 'use') {
      final granted = (_wishes['granted'] as num?)?.toInt() ?? 0;
      _wishes['used'] = (((_wishes['used'] as num?)?.toInt() ?? 0) + (num > 0 ? num : 1)).clamp(0, granted);
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

  // -------------------- 兼容接口（页面可能用到） --------------------
  Future<Map<String, dynamic>> bootstrap() async {
    final s = await herSettings();
    return {'ok': true, 'nick': s['s']?['nickName'] ?? '包娜', 'status': '在线', 'online': true, 'voiceEnabled': false, 'coupleEnabled': false, 'settings': s['s']};
  }

  Future<Map<String, dynamic>> state() async => {'ok': true, 'status': '在线', 'nick': _herSet['nickName'] ?? '包娜', 'online': true};
  Future<Map<String, dynamic>> mood() async => {'ok': true, 'mood': '开心'};
  Future<Map<String, dynamic>> skills() async => {'ok': true, 'skills': []};
  Future<String> ping() async => '通了 · 本地模式';

  void dispose() {
    _ev.close();
  }
}
