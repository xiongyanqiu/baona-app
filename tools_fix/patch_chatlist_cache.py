# -*- coding: utf-8 -*-
import io

p = r'C:\Users\xilisi\Doubao\chats\2026-09-27\new-chat\baona-app\lib\chatlist.dart'
s = io.open(p, encoding='utf-8').read()

old_imp = "import 'api.dart';\nimport 'chat.dart';"
new_imp = "import 'api.dart';\nimport 'chat.dart';\nimport 'msglocal.dart';"
assert old_imp in s, 'import fail'
s = s.replace(old_imp, new_imp)

old_ref = """  Future<void> _refresh() async {
    final a = app.api;
    if (a != null) {
      final j = await a.history(limit: 3);
      if (mounted && j['ok'] != false) {
        final list = ((j['messages'] as List?) ?? []);
        if (list.isNotEmpty) {
          final m = Msg.fromJson(Map<String, dynamic>.from(list.last));
          _last = m.content.isNotEmpty
              ? m.content
              : (m.sticker != null && m.sticker!.isNotEmpty ? '[表情]' : (m.voice != null && m.voice!.isNotEmpty ? '[语音]' : ''));
          _lastT = m.time ?? 0;
        }
      }
    }
    if (mounted) setState(() => _loaded = true);
  }"""

new_ref = """  Future<void> _refresh() async {
    final a = app.api;
    if (a != null) {
      // ★2026-09-30 断网也能显示最后一条：优先网络，失败退回本地缓存
      try {
        final j = await a.history(limit: 3);
        if (mounted && j['ok'] != false) {
          final list = ((j['messages'] as List?) ?? []);
          if (list.isNotEmpty) {
            final m = Msg.fromJson(Map<String, dynamic>.from(list.last));
            _last = m.content.isNotEmpty
                ? m.content
                : (m.sticker != null && m.sticker!.isNotEmpty ? '[表情]' : (m.voice != null && m.voice!.isNotEmpty ? '[语音]' : ''));
            _lastT = m.time ?? 0;
          }
        }
      } catch (_) {
        // 断网 → 读本地缓存最后一条（不弹错）
        final cached = await MsgsLocal.load('baona');
        if (mounted && cached.isNotEmpty) {
          final m = cached.last;
          _last = m.content.isNotEmpty
              ? m.content
              : (m.sticker != null && m.sticker!.isNotEmpty ? '[表情]' : (m.voice != null && m.voice!.isNotEmpty ? '[语音]' : ''));
          _lastT = m.time ?? 0;
        }
      }
    }
    if (mounted) setState(() => _loaded = true);
  }"""
assert old_ref in s, 'refresh match fail'
s = s.replace(old_ref, new_ref)

io.open(p, 'w', encoding='utf-8', newline='').write(s)
print('chatlist.dart 本地缓存预览已加')
