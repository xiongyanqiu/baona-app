# -*- coding: utf-8 -*-
import io

p = r'C:\Users\xilisi\Doubao\chats\2026-09-27\new-chat\baona-app\lib\chatlist.dart'
s = io.open(p, encoding='utf-8').read()

# 1. 状态：_chats 列表换成 _last/_lastT 两个字段（头像/名字/未读实时从 app 读）
old_state = '''  // ★会话模型：id/name/avatar/last/lastT/unread
  //   现在服务端只有包娜一个会话，先放一个；以后多角色往这里加
  List<Map<String, dynamic>> _chats = [];
  bool _loaded = false;
'''
new_state = '''  // ★会话模型（可扩展）：现在服务端只有包娜一个会话；
  //   以后多角色往 _rows() 里加就行。头像/名字/未读实时从 app 读（改了就同步），
  //   最后一条消息预览来自服务端历史（_refresh 拉一次）
  bool _loaded = false;
  String _last = '';
  int _lastT = 0;
'''
assert old_state in s, 'state match fail'
s = s.replace(old_state, new_state)

# 2. _refresh：改成只更新最后一条预览
old_refresh = '''  Future<void> _refresh() async {
    final a = app.api;
    String last = '';
    int lastT = 0;
    if (a != null) {
      final j = await a.history(limit: 3);
      if (mounted && j['ok'] != false) {
        final list = ((j['messages'] as List?) ?? []);
        if (list.isNotEmpty) {
          final m = Msg.fromJson(Map<String, dynamic>.from(list.last));
          last = m.content.isNotEmpty
              ? m.content
              : (m.sticker != null && m.sticker!.isNotEmpty ? '[表情]' : (m.voice != null && m.voice!.isNotEmpty ? '[语音]' : ''));
          lastT = m.time ?? 0;
        }
      }
    }
    if (!mounted) return;
    setState(() {
      _chats = [
        {
          'id': 'baona',
          'name': app.nick,
          'avatar': '${app.herSet['herAvatar'] ?? ''}',
          'last': last,
          'lastT': lastT,
          'unread': app.unread,
        },
      ];
      _loaded = true;
    });
  }
'''
new_refresh = '''  Future<void> _refresh() async {
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
  }
'''
assert old_refresh in s, 'refresh match fail'
s = s.replace(old_refresh, new_refresh)

# 3. build：包 AnimatedBuilder，实时组装
old_build = '''  @override
  Widget build(BuildContext context) {
    final chats = _loaded ? _chats : <Map<String, dynamic>>[];
    return Column(children: [
'''
new_build = '''  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: app,
      builder: (context, _) {
        // ★实时从 app 读：她改头像/名字/来了新消息 → 列表立刻同步（不再卡在 initState 那一帧）
        final chats = _loaded
            ? [
                {
                  'id': 'baona',
                  'name': app.nick,
                  'avatar': '${app.herSet['herAvatar'] ?? ''}',
                  'last': _last,
                  'lastT': _lastT,
                  'unread': app.unread,
                },
              ]
            : <Map<String, dynamic>>[];
        return Column(children: [
'''
assert old_build in s, 'build match fail'
s = s.replace(old_build, new_build)

# 4. build 结尾：补一个闭合
old_end = '''      ),
    ]);
  }

  Widget _row(Map<String, dynamic> c) {
'''
new_end = '''      ),
        ]);
      },
    );
  }

  Widget _row(Map<String, dynamic> c) {
'''
assert old_end in s, 'end match fail'
s = s.replace(old_end, new_end)

io.open(p, 'w', encoding='utf-8', newline='').write(s)
print('chatlist.dart synced OK')
