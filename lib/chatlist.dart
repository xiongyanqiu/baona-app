// 包娜 App · 会话列表页（微信式：列表 → 点进去全屏对话）
// ★2026-09-30 新结构：
//   聊天 tab = 这个列表页（有底栏），点某个会话 → push 全屏对话页（ConversationPage，无底栏）
//   会话数据模型做成可扩展的 List，以后加好友/多角色就是往 _chats 里加一项
import 'package:flutter/material.dart';

import 'api.dart';
import 'chat.dart';
import 'main.dart';
import 'theme.dart';

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  // ★会话模型：id/name/avatar/last/lastT/unread
  //   现在服务端只有包娜一个会话，先放一个；以后多角色往这里加
  List<Map<String, dynamic>> _chats = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
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

  String _time(int t) {
    if (t <= 0) return '';
    final d = DateTime.fromMillisecondsSinceEpoch(t);
    final now = DateTime.now();
    final sameDay = d.year == now.year && d.month == now.month && d.day == now.day;
    String two(int v) => v.toString().padLeft(2, '0');
    if (sameDay) return '${two(d.hour)}:${two(d.minute)}';
    return '${d.month}/${d.day}';
  }

  @override
  Widget build(BuildContext context) {
    final chats = _loaded ? _chats : <Map<String, dynamic>>[];
    return Column(children: [
      // 顶部：微信那种大标题"消息"
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 14, 6),
        child: Row(children: [
          const Text('消息',
              style: TextStyle(fontSize: 27, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
          const Spacer(),
          // ★先不放右侧按钮（新建/搜索等），列表页细节等老公定
        ]),
      ),
      Expanded(
        child: ListView.separated(
          padding: EdgeInsets.only(top: 4, bottom: navSpace(context) + 8),
          itemCount: chats.length,
          separatorBuilder: (_, __) => const Hair(),
          itemBuilder: (_, i) => _row(chats[i]),
        ),
      ),
    ]);
  }

  Widget _row(Map<String, dynamic> c) {
    final av = '${c['avatar'] ?? ''}';
    final unread = (c['unread'] as int?) ?? 0;
    return InkWell(
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const ConversationPage())),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(children: [
          // 头像 + 未读红点
          Stack(clipBehavior: Clip.none, children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(colors: [kAccent, kAccent2]),
                image: avatarOf(av) == null ? null : DecorationImage(image: avatarOf(av)!, fit: BoxFit.cover),
              ),
              child: av.isEmpty ? const Center(child: Text('娜', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600))) : null,
            ),
            if (unread > 0)
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF4D4F),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF1A1B1F), width: 2),
                  ),
                  child: Text('$unread',
                      style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w600, height: 1)),
                ),
              ),
          ]),
          const SizedBox(width: 13),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text('${c['name']}',
                      style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w600),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                if ((c['lastT'] as int?) != 0)
                  Text(_time((c['lastT'] as int?) ?? 0), style: const TextStyle(fontSize: 11.5, color: kSub)),
              ]),
              const SizedBox(height: 4),
              Text('${c['last']}',
                  style: TextStyle(
                      fontSize: 13.5,
                      color: unread > 0 ? const Color(0xFFE8E8EC) : kSub,
                      fontWeight: unread > 0 ? FontWeight.w500 : FontWeight.normal),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right_rounded, size: 20, color: kSub),
        ]),
      ),
    );
  }
}
