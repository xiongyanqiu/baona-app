// 包娜 App · 会话列表页（微信式：列表 → 点进去全屏对话）
// ★2026-09-30 新结构：
//   聊天 tab = 这个列表页（有底栏），点某个会话 → push 全屏对话页（ConversationPage，无底栏）
//   会话数据模型做成可扩展的 List，以后加好友/多角色就是往 _chats 里加一项
import 'dart:convert';

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
import 'audiolib.dart';
import 'group_chat.dart';

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
  bool _didIntro = false; // ★26.2.24 首屏交错浮现只播一次（滚动重建不再重复动画）
  String _last = '';
  int _lastT = 0;
  late Future<String> _vlAvatarFuture = Future.value('');
  String _alName = '包娜的音频库';
  String _alAvatar = ''; // ★26.2.12：音频库自定义头像（dataURL）
  // ★26.2.14：独立角色自定义备注/头像（本地存储，角色页改了立刻同步）——所有角色通用
  final Map<String, String> _roleNames = {};
  final Map<String, String> _roleAvatars = {};

  /// ★通用：读全部角色的本地备注/头像（以后新增角色自动进来）
  Future<void> _loadRolePrefs() async {
    final sp = await SharedPreferences.getInstance();
    bool changed = false;
    for (final rid in roleIds()) {
      final n = sp.getString('role.$rid.name') ?? '';
      final a = sp.getString('role.$rid.avatar') ?? '';
      if ((_roleNames[rid] ?? '') != n || (_roleAvatars[rid] ?? '') != a) {
        if (n.trim().isNotEmpty) {
          _roleNames[rid] = n;
        } else {
          _roleNames.remove(rid);
        }
        if (a.isNotEmpty) {
          _roleAvatars[rid] = a;
        } else {
          _roleAvatars.remove(rid);
        }
        changed = true;
      }
    }
    if (mounted && changed) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _vlAvatarFuture = SharedPreferences.getInstance()
        .then((sp) => sp.getString('vl.avatar') ?? '');
    // ★26.2.12：音频库头像/名字本地同步（在音频库页改了，列表立刻显示）
    SharedPreferences.getInstance().then((sp) {
      final n = sp.getString('al.name') ?? '';
      final a = sp.getString('al.avatar') ?? '';
      if (mounted && (n != _alName || a != _alAvatar)) {
        setState(() {
          if (n.isNotEmpty) _alName = n;
          _alAvatar = a;
        });
      }
    });
    _loadRolePrefs();
    _refresh();
  }

  Future<void> _refresh() async {
    final dynamic a = app.brainOrApi;
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

  /// ★26.2.17 添加自建角色（手机本地，不用编译）
  Future<void> _openAddRole() async {
    final nameCtl = TextEditingController();
    final personaCtl = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1D1D23),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (c) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('添加新角色', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              TextField(
                controller: nameCtl,
                decoration: const InputDecoration(labelText: '名字', hintText: '比如：鞠婧祎', filled: true),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: personaCtl,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: '人设（她是谁、什么性格、怎么说话…）',
                  hintText: '写清楚点，模型才不会理解歪。\n支持：性格 / 口头禅 / 关系 / 说话风格 / 边界',
                  filled: true,
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  child: OutlinedButton(onPressed: () => Navigator.pop(c, false), child: const Text('取消')),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(c, true),
                    child: const Text('添加'),
                  ),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final name = nameCtl.text.trim();
    final persona = personaCtl.text.trim();
    if (name.isEmpty) {
      toast(context, '名字不能空');
      return;
    }
    final brain = app.brain;
    if (brain == null) return;
    final r = await brain.roleAdd({'name': name, 'persona': persona.isNotEmpty ? persona : '你是$name。像微信打字一样回消息：只发你说的话，不写动作不写括号不写表情。短句、口语、有来有回。'});
    if (r['ok'] == true) {
      toast(context, '已添加，快去跟她聊吧');
      await _loadRolePrefs();
      if (mounted) setState(() {});
    } else {
      toast(context, '添加失败：${r['error'] ?? ''}');
    }
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
                // ★2026-10-01 v26.2.11：包娜的音频库 —— 手机本地音频，本地播放
                {
                  'id': 'audiolib',
                  'name': _alName,
                  'avatar': _alAvatar,
                  'last': '点进来听会儿～',
                  'lastT': 0,
                  'unread': 0,
                },
                // ★v26.2.16：姐妹聊天群 —— 包娜+刘紫灵，你说话她们依次接（完全隔离的第三个分支）
                {
                  'id': 'group.nvg',
                  'name': '姐妹聊天群',
                  'avatar': '',
                  'last': app.sideLastOf('group.nvg').isNotEmpty
                      ? app.sideLastOf('group.nvg')
                      : '包娜和刘紫灵在群里等你',
                  'lastT': 0,
                  'unread': app.sideUnreadOf('group.nvg'),
                },
                // ★独立角色们（刘紫灵 + 女娲/后土/西王母/美杜莎/云韵/萧薰儿/比比东/千仞雪/小舞/古月娜/狠人大帝/安妙依/姬紫月/颜如玉/火灵儿）
                //   人设/上下文/记忆完全隔离；备注头像可自定义
                ...roleIds().map((rid) => {
                  'id': rid,
                  'name': _roleNames[rid] ?? roleNameOf(rid),
                  'avatar': _roleAvatars[rid] ?? '',
                  'last': app.sideLastOf(rid).isNotEmpty ? app.sideLastOf(rid) : '来找我聊聊',
                  'lastT': 0,
                  'unread': app.sideUnreadOf(rid),
                }),
              ]
            : <Map<String, dynamic>>[];
      // ★26.2.23 功能整理：列表分区 —— 会话（包娜+群聊）/ 我的角色（15+自建）/ 功能（抖音·视频库·音频库）
      //   功能入口不再和角色对话混在一起，一眼看清
      final rows = <Widget>[];
      void sec(String t) => rows.add(Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
            child: Text(t.toUpperCase(),
                style: const TextStyle(fontSize: 11.5, color: kSub, letterSpacing: 0.9, fontWeight: FontWeight.w600)),
          ));
      Widget card(Map<String, dynamic> c) => Padding(
            padding: const EdgeInsets.fromLTRB(14, 3, 14, 3),
            child: GlassSurface(radius: 18, blur: 0, pad: EdgeInsets.zero, child: _row(c)),
          );
      final byId = <String, Map<String, dynamic>>{for (final c in chats) '${c['id']}': c};
      sec('会话');
      for (final id in ['baona', 'group.nvg']) {
        final c = byId[id];
        if (c != null) rows.add(card(c));
      }
      sec('我的角色');
      for (final c in chats) {
        if (roleIds().contains('${c['id']}')) rows.add(card(c));
      }
      sec('功能');
      for (final id in ['douyin', 'videolib', 'audiolib']) {
        final c = byId[id];
        if (c != null) rows.add(card(c));
      }
      return Column(children: [
      // 顶部：苹果官网式大标题（大而轻、带副标题，跟 iOS 消息 App 一个味道）
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 14, 6),
        child: Row(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('消息',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -0.9, height: 1.1)),
            const SizedBox(height: 3),
            Text('包娜和她的朋友们',
                style: TextStyle(fontSize: 12.5, color: kSub.withValues(alpha: 0.9))),
          ]),
          const Spacer(),
          // ★26.2.17 全本地化：自己添加角色（不用编译，人设写进手机本地）
          IconButton(
            tooltip: '添加角色',
            icon: const Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF7B2FFF)),
            onPressed: _openAddRole,
          ),
          const SizedBox(width: 4),
        ]),
      ),
      Expanded(
        // ★26.2.22 苹果官网感：会话列表卡片化 —— 每行一张圆角玻璃卡（纯渐变，不实时模糊省电）
        // ★26.2.24 修复"滑到底部还没浮现"：交错浮现只给首屏前 8 项、只播一次；
        //   滚动加载的项直接显示 —— 之前每项都 delay=i*45ms，底部项要等一秒多才开始浮现
        child: ListView.builder(
          padding: EdgeInsets.only(top: 2, bottom: navSpace(context) + 10),
          itemCount: rows.length,
          itemBuilder: (_, i) {
            if (_didIntro || i >= 8) return rows[i];
            return Appear(
              delay: i * 40,
              dy: 14,
              onDone: () {
                if (mounted) setState(() => _didIntro = true);
              },
              child: rows[i],
            );
          },
        ),
      ),
        ]);
      },
    );
  }

  /// ★26.2.12：音频库头像——有图就显示，没有就默认图标
  /// ★2026-10-02 闪屏修复：改走 avatarOf 的 provider 缓存 —— 之前每次 build 都重新
  ///   base64Decode + 新建 MemoryImage → 新 provider = 缓存 miss → 头像反复解码闪
  Widget _avatarOf(String dataUrl, {required Widget child}) {
    final p = avatarOf(dataUrl);
    if (p != null) {
      return Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          image: DecorationImage(image: p, fit: BoxFit.cover),
        ),
      );
    }
    return Container(
      width: 52,
      height: 52,
      decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [Color(0xFF7B2FFF), Color(0xFFC95BFF)])),
      child: Center(child: child),
    );
  }

  /// ★26.2.14：独立角色头像——自定义（dataURL）优先，没有就默认紫青渐变 + 角色字
  Widget _roleAvatarOf(String dataUrl, String letter) {
    final p = avatarOf(dataUrl);
    if (p != null) {
      return Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          image: DecorationImage(image: p, fit: BoxFit.cover),
        ),
      );
    }
    return Container(
      width: 52,
      height: 52,
      decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [Color(0xFF2F6BFF), Color(0xFF7B2FFF)])),
      child: Center(
          child: Text(letter, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white))),
    );
  }

  Widget _row(Map<String, dynamic> c) {
    final id = '${c['id'] ?? 'baona'}';
    final av = '${c['avatar'] ?? ''}';
    final unread = (c['unread'] as int?) ?? 0;
    final isGroup = id.startsWith('group.');
    // ★26.2.20 自建角色（id 以 u 开头）长按可删除：人设/对话/记忆/备注头像/群成员一起清
    final isCustom = id.startsWith('u');
    return GestureDetector(
      onLongPress: isCustom
          ? () => _delRole(id, '${c['name'] ?? ''}')
          : null,
      child: InkWell(
      onTap: () {
        final isRole = roleIds().contains(id);
        final isGroup = id.startsWith('group.');
        final f = Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => id == 'douyin'
                ? const DouyinPage()
                : id == 'videolib'
                    ? const VideoLibPage()
                    : id == 'audiolib'
                        ? const AudioLibPage()
                        : isGroup
                            ? GroupChatPage(gid: id.substring(6)) // ★群聊会话
                            : isRole
                                ? ConversationPage(roleId: id) // ★独立角色会话
                                : const ConversationPage()));
        // ★角色页改了备注/头像，返回列表立刻同步
        if (isRole) f.then((_) => _loadRolePrefs());
        // ★2026-10-02 点进角色/群聊会话就清它的未读（不占主对话红点）
        if (isRole || isGroup) app.sideClear(id);
      },
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
              // 视频库头像：本地设置的头像（dataURL）或默认紫底播放三角
              FutureBuilder<String>(
                future: _vlAvatarFuture,
                builder: (c, s) {
                  final av = s.data ?? '';
                  // ★2026-10-02 闪屏修复：走 avatarOf 缓存 provider，不再每次 build 重新解码
                  final p = av.startsWith('data:image/') ? avatarOf(av) : null;
                  if (p != null) {
                    return Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        image: DecorationImage(image: p, fit: BoxFit.cover),
                      ),
                    );
                  }
                  return Container(
                    width: 52,
                    height: 52,
                    decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [Color(0xFF7B2FFF), Color(0xFF2F6BFF)])),
                    child: const Center(child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 26)),
                  );
                },
              )
            else if (id == 'audiolib')
              // 音频库头像：本地设置的头像（dataURL）或默认紫底音符
              _avatarOf(_alAvatar,
                  child: const Icon(Icons.music_note_rounded, color: Colors.white, size: 26))
            else if (roleIds().contains(id))
              // ★独立角色头像：自定义（dataURL）优先，没有就用默认紫青渐变 + 角色字
              _roleAvatarOf(_roleAvatars[id] ?? '', roleLetterOf(id))
            else if (isGroup)
              // ★群聊头像：双人头像叠层（微信群像风格）
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [Color(0xFFFF8A65), Color(0xFF2F6BFF)])),
                child: const Stack(alignment: Alignment.center, children: [
                  Icon(Icons.people_alt_rounded, color: Colors.white, size: 26),
                  Positioned(right: 11, bottom: 8, child: Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 12)),
                ]),
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
    ),
    );
  }

  /// ★26.2.20 长按删除自建角色：确认后清人设/对话/记忆/备注头像/群成员
  Future<void> _delRole(String id, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF1D1D23),
        title: Text('删除角色「$name」？'),
        content: const Text('会一起清掉：对话记录、记忆、备注头像；如果她在群里也会被移出群。删了就找不回来了。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('取消')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFFF4D4F)),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final r = await app.brain?.roleDel(id);
    if (r?['ok'] == true) {
      if (mounted) toast(context, '已删除「$name」');
      await _loadRolePrefs();
      if (mounted) setState(() {});
    } else if (mounted) {
      toast(context, '删除失败：${r?['error'] ?? ''}');
    }
  }
}
