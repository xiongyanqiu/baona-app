// 包娜 App · 会话列表页（微信式：列表 → 点进去全屏对话）
// ★2026-09-30 新结构：
//   聊天 tab = 这个列表页（有底栏），点某个会话 → push 全屏对话页（ConversationPage，无底栏）
//   会话数据模型做成可扩展的 List，以后加好友/多角色就是往 _chats 里加一项
import 'package:flutter/material.dart';

import 'api.dart';
import 'douyin.dart';
import 'chat.dart';
import 'msglocal.dart';
import 'imgsrv.dart';
import 'main.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme.dart';
import 'videolib.dart';

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  // ★会话模型（可扩展）：现在服务端只有包娜一个会话；
  //   以后多角色往 _rows() 里加就行。头像/名字/未读实时从 app 读（改了就同步），
  //   最后一条消息预览来自服务端历史（_refresh 拉一次）
  bool _loaded = false;
  String _last = '';
  int _lastT = 0;

  @override
  void initState() {
    super.initState();
    _vlAvatarFuture = SharedPreferences.getInstance()
        .then((sp) => sp.getString('vl.avatar') ?? '');
    _refresh();
  }

  Future<void> _refresh() async {
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
                // ★2026-09-30：抖音入口 —— 点进去是全屏抖音风格短视频页（模拟源）
                {
                  'id': 'douyin',
                  'name': '抖音',
                  'avatar': '',
                  'last': '点进来刷会儿视频～',
                  'lastT': 0,
                  'unread': 0,
                },
                // ★b47：肉便器包娜的视频库 —— 点进去是抖音网页版
                {
                  'id': 'videolib',
                  'name': '肉便器包娜的视频库',
                  'avatar': '',
                  'last': '点进来刷会儿视频～',
                  'lastT': 0,
                  'unread': 0,
                },
              ]
            : <Map<String, dynamic>>[];
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
      },
    );
  }

  Widget _row(Map<String, dynamic> c) {
    final id = '${c['id'] ?? 'baona'}';
    final av = '${c['avatar'] ?? ''}';
    final unread = (c['unread'] as int?) ?? 0;
    return InkWell(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => id == 'douyin'
              ? const DouyinPage()
              : id == 'videolib'
                  ? const VideoLibPage()
                  : const ConversationPage())),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(children: [
          // 头像 + 未读红点
          Stack(clipBehavior: Clip.none, children: [
            if (id == 'douyin')
              // 抖音头像：黑底 + 音符（近似 logo）
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF111318)),
                child: const Stack(alignment: Alignment.center, children: [
                  Icon(Icons.music_note, color: Color(0xFF39F2FF), size: 24),
                  Positioned(right: 13, bottom: 12, child: Icon(Icons.music_note, color: Color(0xFFFF3B5C), size: 12)),
                ]),
              )
            else if (id == 'videolib')
              // 视频库头像：深紫底 + 播放三角
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [Color(0xFF7B2FFF), Color(0xFF2F6BFF)])),
                child: const Center(child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 26)),
              )
            else if (av.isEmpty)
                Container(
                    width: 52,
                    height: 52,
                    decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [kAccent, kAccent2])),
                    child: const Center(child: Text('娜', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600))),
                  )
                else FutureBuilder<ImageProvider>(
                    // ★b21 头像磁盘缓存：列表频繁重建不再反复下载
                    future: ImgCache.provider(av),
                    builder: (c, s) => Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(colors: [kAccent, kAccent2]),
                        image: s.data == null ? null : DecorationImage(image: s.data!, fit: BoxFit.cover),
                      ),
                    ),
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
