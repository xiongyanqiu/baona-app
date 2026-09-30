// 包娜 App · 本地消息缓存 —— 断网也能看聊天记录
// ★2026-09-30 老公提的：连接要网络没问题，但聊天记录不该每次靠网络加载。
//   打开对话先读本地（秒开），再后台同步服务端增量；断网时历史照常看。
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';

class MsgsLocal {
  // 按会话分 key：现在单会话用 baona，以后多角色传各自的 id 就行
  static String _key(String role) => 'msgs.v1.$role';

  static Future<List<Msg>> load(String role) async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_key(role));
      if (raw == null || raw.isEmpty) return [];
      final list = (jsonDecode(raw) as List?) ?? [];
      return list.map((e) => Msg.fromJson(Map<String, dynamic>.from(e))).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> save(String role, List<Msg> msgs) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_key(role), jsonEncode(msgs.map((m) => m.toJson()).toList()));
    } catch (_) {/* 缓存写失败不影响聊天 */}
  }

  static Future<void> clear(String role) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.remove(_key(role));
    } catch (_) {/* ignore */}
  }

  /// 合并去重：以服务端为权威；本地独有的（乐观发出还没确认/失败的）补在末尾
  static List<Msg> merge(List<Msg> server, List<Msg> local) {
    final out = <Msg>[];
    final seen = <String>{};
    for (final m in server) {
      final k = _keyOf(m);
      if (k != null) {
        if (seen.contains(k)) continue;
        seen.add(k);
      }
      out.add(m);
    }
    for (final m in local) {
      final k = _keyOf(m);
      if (k != null && seen.contains(k)) continue;
      // 只有还没确认/失败的本地消息才补（正常的都在服务端返回里了）
      if (m.st == 'pending' || m.st == 'failed') {
        out.add(m);
      }
    }
    return out;
  }

  static String? _keyOf(Msg m) {
    if (m.cid != null && m.cid!.isNotEmpty) return 'c:${m.cid}';
    if (m.idx != null) return 'i:${m.idx}';
    return null;
  }
}
