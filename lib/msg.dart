// msg.dart — 包娜 App v27 消息区：仅包娜一人的聊天对话页
// 设计：iOS 27 Liquid Glass + 系统色（无紫色底板）
// 布局：左上角=名字+头像（她的，点击可换）；右上角=设置（对话/记忆/头像）；
//       每条消息带头像：我的在右侧（我的头像，可换）、她在左侧（她的头像）
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'main.dart';
import 'msglocal.dart';
import 'theme.dart';
import 'us.dart'; // ★v27.0.12 壁纸：pickAlbumImage 从手机相册选背景图

class MsgPage extends StatefulWidget {
  const MsgPage({super.key});
  // ★v27.0.11 对话页是 push 的全屏沉浸页（主页"聊天"卡片进入），
  //   "返回主界面" = Navigator.pop 回主页；输入框左边箭头呼出对话功能区

  @override
  State<MsgPage> createState() => _MsgPageState();
}

class _MsgPageState extends State<MsgPage> {
  List<Msg> _msgs = [];
  bool _loading = true;
  bool _typing = false;
  int _memCount = 0;
  int _cidSeq = 0;
  String _myAv = ''; // ★v27.0.1 我的头像本地兜底（双写：SP + brain._herSet，重装也不丢）
  bool _drawerOpen = false; // ★v27.0.10 对话功能区（输入框左边箭头呼出/收起）
  final Set<String> _fresh = {}; // ★v27.0.14.5 新消息标记：刚到的消息 3D 翻入，播完移除
  final TextEditingController _inp = TextEditingController();
  final ScrollController _sc = ScrollController();
  StreamSubscription<Map<String, dynamic>>? _sub;

  dynamic get _a => app.brain ?? app.api;

  @override
  void initState() {
    super.initState();
    _load();
    _sub = _a?.events.listen(_onEv);
    _loadMyAv();
  }

  /// 我的头像：SharedPreferences 里的最优先（本地双写兜底）
  Future<void> _loadMyAv() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final v = sp.getString('v27.myAvatar') ?? '';
      if (v.isNotEmpty && mounted) setState(() => _myAv = v);
    } catch (_) {}
  }

  @override
  void dispose() {
    _sub?.cancel();
    _inp.dispose();
    _sc.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final a = _a;
    if (a == null) return;
    final r = await a.history(limit: 300);
    final list = (r['messages'] as List?) ?? [];
    if (mounted) {
      setState(() {
        _msgs = list.map((m) => Msg.fromJson(Map<String, dynamic>.from(m))).toList();
        _loading = false;
      });
      _jumpBottom(instant: true);
    }
    try {
      final mr = await a.memories();
      if (mounted) setState(() => _memCount = (mr['count'] as num?)?.toInt() ?? 0);
    } catch (_) {}
  }

  void _onEv(Map<String, dynamic> e) {
    final t = '${e['type'] ?? ''}';
    if (t == 'msg') {
      final m = e['msg'];
      if (m is Map) {
        final msg = Msg.fromJson(Map<String, dynamic>.from(m));
        // 防重复：本地 pending 是自己画的那条（cid 不同），assistant 广播直接加
        setState(() {
          _msgs.add(msg);
          _fresh.add(_mkey(msg)); // ★v27.0.14.5 新消息 3D 翻入
        });
        _jumpBottom();
      }
    } else if (t == 'typing') {
      setState(() => _typing = e['on'] == true);
    } else if (t == 'cleared') {
      setState(() => _msgs.clear());
    }
  }

  void _jumpBottom({bool instant = false}) {
    if (!mounted) return; // ★v27.0.9 页面已销毁就别再碰滚动条（发送后延迟补偿可能晚于退出）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_sc.hasClients) return;
      try {
        _sc.animateTo(_sc.position.maxScrollExtent,
            duration: instant ? Duration.zero : const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic);
      } catch (_) {}
    });
  }

  Future<void> _send() async {
    final a = _a;
    final t = _inp.text.trim();
    if (a == null || t.isEmpty) return;
    _inp.clear();
    // ★v27.0.2 发送后收键盘（微信习惯，也避免键盘状态卡住）
    FocusManager.instance.primaryFocus?.unfocus();
    try {
      HapticFeedback.lightImpact();
    } catch (_) {}
    final cid = 'c${DateTime.now().millisecondsSinceEpoch}-${++_cidSeq}';
    final m = Msg(role: 'me', content: t, st: 'pending', time: DateTime.now().millisecondsSinceEpoch, cid: cid);
    setState(() {
      _msgs.add(m);
      _fresh.add(cid); // ★v27.0.14.5 自己发的消息也从远处翻入
    });
    await MsgsLocal.save('baona', _msgs);
    // ★v27.0.9 发送时不再追键盘动画：键盘收起过程中列表高度一直在变，
    //   animateTo 追着变动的 maxScrollExtent 跑 → 页面乱弹。改成瞬时定位两次：
    //   先立刻贴底，等键盘动画（约 250ms）结束后再纠正一次最终位置。
    _jumpBottom(instant: true);
    Future.delayed(const Duration(milliseconds: 380), () => _jumpBottom(instant: true));
    final r = await a.send({'text': t, 'cid': cid});
    if (mounted) {
      setState(() => m.st = r['ok'] == true ? 'ok' : 'failed');
      await MsgsLocal.save('baona', _msgs);
      if (r['ok'] != true) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('发送失败：${r['error'] ?? '未知错误'}'),
            behavior: SnackBarBehavior.floating));
      }
    }
  }

  // ---------- 头像 ----------
  Future<void> _pickAvatar(String who) async {
    final a = _a;
    if (a == null) return;
    try {
      final p = await ImagePicker()
          .pickImage(source: ImageSource.gallery, maxWidth: 512, imageQuality: 80);
      if (p == null) return;
      final bytes = await p.readAsBytes();
      final dataUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      final key = who == 'her' ? 'herAvatar' : 'myAvatar';
      // ★v27.0.1 双写：本地 SP 兜底（我的头像）+ brain._herSet（她的头像 / 模型能看到）
      if (who == 'my') {
        try {
          final sp = await SharedPreferences.getInstance();
          await sp.setString('v27.myAvatar', dataUrl);
        } catch (_) {}
        setState(() => _myAv = dataUrl);
      }
      await a.patchSettings({'patch': {key: dataUrl}});
      if (mounted) {
        setState(() => app.herSet[key] = dataUrl);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('选图失败：$e'), behavior: SnackBarBehavior.floating));
      }
    }
  }

  // ---------- 设置弹窗（对话 / 记忆 / 头像） ----------
  Future<void> _openSettings() async {
    final a = _a;
    if (a == null) return;
    await showModalBottomSheet(
      context: context,
      backgroundColor: kBg2, // secondarySystemBackground
      isScrollControlled: true, // ★v27.0.6 内容超过屏幕时整块能上下滑（不然头像区滑不到）
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (c) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(c).size.height * 0.92),
          child: StatefulBuilder(
            builder: (c, setSt) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Text('设置',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(c),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0x33FFFFFF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, size: 16, color: kSub),
                  ),
                ),
              ]),
              const SizedBox(height: 14),
              _sec('对话'),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.edit_outlined, color: kAccent),
                title: const Text('改她的名字', style: TextStyle(fontSize: 15)),
                subtitle: Text('现在叫：${app.nick}', style: const TextStyle(fontSize: 12.5, color: kSub)),
                trailing: const Icon(Icons.chevron_right, size: 18, color: kSub),
                onTap: () async {
                  await _renameHer();
                  setSt(() {});
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.delete_outline, color: kBad),
                title: const Text('清空聊天记录', style: TextStyle(fontSize: 15)),
                trailing: const Icon(Icons.chevron_right, size: 18, color: kSub),
                onTap: () async {
                  final ok = await _confirm(c, '清空聊天记录', '和包娜的聊天记录会全部删掉，确定吗？');
                  if (ok == true) {
                    await a.clearChat();
                    setSt(() => _msgs.clear());
                  }
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  const Text('字号', style: TextStyle(fontSize: 15)),
                  Expanded(
                    child: Slider(
                      value: app.fontSize.clamp(13, 20),
                      min: 13,
                      max: 20,
                      divisions: 7,
                      activeColor: kAccent,
                      inactiveColor: const Color(0x33FFFFFF),
                      onChanged: (v) => app.put('fontSize', v.round()),
                    ),
                  ),
                  Text('${app.fontSize.round()}', style: const TextStyle(fontSize: 13, color: kSub)),
                ]),
              ),
              const Divider(height: 18, color: kHair),
              _sec('她的记忆'),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.memory, color: kAccent),
                title: Text('她脑子里记着 $_memCount 条', style: const TextStyle(fontSize: 15)),
                subtitle: const Text('她会自己总结对话存进长期记忆，也能手动清'),
                trailing: const Icon(Icons.chevron_right, size: 18, color: kSub),
                onTap: () => _showMemories(c),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.delete_sweep, color: kBad),
                title: const Text('清掉她的长期记忆', style: TextStyle(fontSize: 15, color: kBad)),
                onTap: () async {
                  final ok = await _confirm(c, '清掉她的长期记忆', '她记着的所有事都会忘掉，确定吗？');
                  if (ok == true) {
                    await a.memoryClear();
                    setSt(() => _memCount = 0);
                  }
                },
              ),
              const Divider(height: 18, color: kHair),
              _sec('头像'),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.face_retouching_natural, color: kAccent),
                title: const Text('换她的头像', style: TextStyle(fontSize: 15)),
                subtitle: const Text('左上角和她的消息旁边都会换'),
                trailing: const Icon(Icons.chevron_right, size: 18, color: kSub),
                onTap: () async {
                  Navigator.pop(c);
                  await _pickAvatar('her');
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.person_outline, color: kAccent),
                title: const Text('换我的头像', style: TextStyle(fontSize: 15)),
                subtitle: const Text('我的消息旁边显示的头像'),
                trailing: const Icon(Icons.chevron_right, size: 18, color: kSub),
                onTap: () async {
                  Navigator.pop(c);
                  await _pickAvatar('my');
                },
              ),
              const Divider(height: 18, color: kHair),
              _sec('壁纸'),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.wallpaper, color: kAccent),
                title: const Text('聊天壁纸', style: TextStyle(fontSize: 15)),
                subtitle: Text(app.bg.isEmpty ? '现在是默认深色背景' : '已设置自定义背景',
                    style: const TextStyle(fontSize: 12.5, color: kSub)),
                trailing: const Icon(Icons.chevron_right, size: 18, color: kSub),
                onTap: () async {
                  Navigator.pop(c);
                  await Future.delayed(const Duration(milliseconds: 350));
                  if (!mounted) return;
                  await _pickWallSheet(context, setSt);
                },
              ),
              const SizedBox(height: 6),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  /// ★v27.0.12 对话页壁纸弹窗（和「我的-设置」里的一样）：默认深色 / 从相册选一张 / 清掉
  Future<void> _pickWallSheet(BuildContext bc, StateSetter setSt) async {
    final act = await showModalBottomSheet<String>(
      context: bc,
      backgroundColor: kBg2,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Text('聊天壁纸', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.pop(c),
                child: Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(color: const Color(0x33FFFFFF), shape: BoxShape.circle),
                  child: const Icon(Icons.close, size: 16, color: kSub),
                ),
              ),
            ]),
            const SizedBox(height: 14),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.dark_mode_outlined, color: kAccent),
              title: const Text('默认深色', style: TextStyle(fontSize: 15.5)),
              subtitle: const Text('不设壁纸，用系统深色渐变'),
              trailing: app.bg.isEmpty ? const Icon(Icons.check, color: kAccent, size: 20) : const Icon(Icons.chevron_right, size: 18, color: kSub),
              onTap: () => Navigator.pop(c, 'clear'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.photo_library_outlined, color: kAccent),
              title: const Text('从相册选一张', style: TextStyle(fontSize: 15.5)),
              subtitle: const Text('在手机相册里挑一张当聊天背景'),
              trailing: const Icon(Icons.chevron_right, size: 18, color: kSub),
              onTap: () => Navigator.pop(c, 'album'),
            ),
            if (app.bg.isNotEmpty)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.close, color: kBad),
                title: const Text('清掉壁纸', style: TextStyle(fontSize: 15.5, color: kBad)),
                trailing: const Icon(Icons.chevron_right, size: 18, color: kSub),
                onTap: () => Navigator.pop(c, 'clear'),
              ),
          ]),
        ),
      ),
    );
    if (act == null || !mounted) return;
    if (act == 'clear') {
      app.put('bg', '');
      setSt(() {});
      return;
    }
    // album：先等弹窗关完再开相册，避免动画竞态"点了没反应"
    await Future.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    final url = await pickAlbumImage(context);
    if (!mounted) return;
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('相册里还没有照片，先去「照片」里添加一些吧'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: kBg2,
        duration: Duration(seconds: 2),
      ));
      return;
    }
    app.put('bg', url);
    if (app.bgBlur <= 0) {
      app.cfg['bgBlur'] = 8;
      app.cfg['bgOpacity'] = 0.9;
      app.save();
    }
    setSt(() {});
  }

  /// ★v27.0.1 改她的名字（备注）—— 存 brain._herSet['nickName']，顶栏和模型都能用
  Future<void> _renameHer() async {
    final a = _a;
    if (a == null) return;
    final ctl = TextEditingController(text: app.nick);
    final name = await showDialog<String>(
      context: context,
      builder: (cc) => AlertDialog(
        backgroundColor: kBg2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('改她的名字', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctl,
          autofocus: true,
          maxLength: 12,
          enableSuggestions: false, // ★v27.0.13 关掉 iOS 拼写检查（双黄下划线）
          autocorrect: false,
          style: const TextStyle(fontSize: 16),
          decoration: const InputDecoration(hintText: '输入新名字', counterText: ''),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(cc), child: const Text('取消', style: TextStyle(color: kSub))),
          TextButton(
            onPressed: () => Navigator.pop(cc, ctl.text.trim()),
            child: const Text('保存', style: TextStyle(color: kAccent, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    final n = (name ?? '').trim();
    if (n.isEmpty || n == app.nick) return;
    await a.patchSettings({'patch': {'nickName': n}});
    if (mounted) setState(() => app.nick = n);
  }

  /// 记忆列表弹窗
  Future<void> _showMemories(BuildContext c) async {
    final a = _a;
    if (a == null) return;
    final r = await a.memories();
    final items = (r['items'] as List?) ?? [];
    if (!mounted) return;
    showModalBottomSheet(
      context: c,
      backgroundColor: kBg2,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (cc) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Text('她的长期记忆',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.pop(cc),
                child: Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(color: const Color(0x33FFFFFF), shape: BoxShape.circle),
                  child: const Icon(Icons.close, size: 16, color: kSub),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: Center(child: Text('还没记住什么，聊着聊着她就会自己记了', style: TextStyle(color: kSub, fontSize: 13.5))),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 14, color: kHair),
                  itemBuilder: (_, i) {
                    final it = items[i];
                    return Row(children: [
                      const Icon(Icons.fiber_manual_record, size: 8, color: kAccent),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text('${it['text'] ?? ''}',
                            style: const TextStyle(fontSize: 14, height: 1.4)),
                      ),
                    ]);
                  },
                ),
              ),
          ]),
        ),
      ),
    );
  }

  Widget _sec(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(t.toUpperCase(),
            style: const TextStyle(
                fontSize: 11.5, color: kSub, letterSpacing: 0.9, fontWeight: FontWeight.w600)),
      );

  Future<bool?> _confirm(BuildContext c, String title, String msg) => showDialog<bool>(
        context: c,
        builder: (cc) => AlertDialog(
          backgroundColor: kBg2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          content: Text(msg, style: const TextStyle(fontSize: 14.5, height: 1.4)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(cc, false), child: const Text('取消', style: TextStyle(color: kSub))),
            TextButton(onPressed: () => Navigator.pop(cc, true), child: const Text('确定', style: TextStyle(color: kBad, fontWeight: FontWeight.w600))),
          ],
        ),
      );

  // ---------- 界面 ----------
  @override
  Widget build(BuildContext context) {
    final herAv = '${app.herSet['herAvatar'] ?? ''}';
    final myAv = _myAv.isNotEmpty ? _myAv : '${app.herSet['myAvatar'] ?? ''}';
    // ★v27.0.2：去掉内层 Scaffold —— 之前两层 Scaffold 嵌套，键盘弹起时 body 被双重压缩，
    //   输入栏被挤到顶栏下面、键盘状态卡住收不回。键盘避让由 SafeArea+Column 自己处理。
    // ★★v27.0.14：v27.0.11 对话页改成 push 全屏独立页面后，外层 HomePage 的 Scaffold 不在祖先链上，
    //   整个页面没有 Material —— 所有 Text 继承 Flutter 的"缺 Material"警告样式（黄色下划线）！
    //   这就是双黄下划线的真根因（不是拼写检查）。这里补一层透明 Material 恢复主题文本样式。
    //   GestureDetector 包一层：点空白处收起键盘（微信习惯）。
    // ★v27.0.14.3 键盘跟随修复：对话页是 push 全屏独立页，祖先链上没有任何 Scaffold，
    //   自动避让(resizeToAvoidBottomInset)失效 → 键盘弹起输入框被盖住。
    //   这里补一层透明 Scaffold 恢复键盘跟随（独立 route 无双重压缩问题，v27.0.2 那个 bug 不会回来）。
    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: true,
      body: Wall(
      url: app.bg,
      blur: app.bgBlur,
      opacity: app.bgOpacity,
      // ★v27.0.14.6 宇宙元素：对话页垫一层淡星尘（不影响阅读），消息浮在星空上
      child: Stack(children: [
        const Positioned.fill(
            child: IgnorePointer(child: StarField(count: 30, dim: true))),
        Material(
        type: MaterialType.transparency,
        child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: Column(children: [
          // 顶栏：左上角 名字+头像；右上角 设置
          GlassBar(
            top: true,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 6, 10, 6),
                child: Row(children: [
                  GestureDetector(
                    onTap: () => _pickAvatar('her'),
                    child: _Av(av: herAv, size: 38, fallback: '娜'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(app.nick, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, letterSpacing: -0.2)),
                        const SizedBox(height: 2),
                        Row(children: [
                          Container(
                              width: 6, height: 6,
                              decoration: BoxDecoration(
                                  color: const Color(0xFF30D158), shape: BoxShape.circle)),
                          const SizedBox(width: 5),
                          const Text('包娜在线',
                              style: TextStyle(fontSize: 11.5, color: kSub)),
                        ]),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _openSettings,
                    icon: const Icon(Icons.settings_outlined, size: 21),
                    tooltip: '设置',
                  ),
                ]),
              ),
            ),
          ),
          // 消息列表
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: kAccent))
                : _msgs.isEmpty
                    ? const _EmptyHint()
                    : ListView.builder(
                        controller: _sc,
                        // ★v27.0.10 对话页没有主界面底栏了：底部不再留 navSpace 让位，
                        //   列表直接贴输入框，最新消息始终紧跟输入框（键盘弹起也跟着动）
                        padding: const EdgeInsets.only(top: 10, bottom: 8),
                        itemCount: _msgs.length + (_typing ? 1 : 0),
                        itemBuilder: (_, i) {
                          if (i >= _msgs.length) return _TypingRow();
                          final m = _msgs[i];
                          final row = _row(m, herAv, myAv);
                          final k = _mkey(m);
                          // ★v27.0.14.5 新消息 3D 翻入：只播一次（播完从 _fresh 移除，滚动重建不再播）
                          if (_fresh.contains(k)) {
                            return Appear3D(
                              fromAngle: 0.10,
                              dy: 10,
                              onDone: () => setState(() => _fresh.remove(k)),
                              child: row,
                            );
                          }
                          return row;
                        },
                      ),
          ),
          // ★v27.0.10 对话功能区：输入框左边箭头呼出/收起（替代主界面底栏，对话专用）
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.bottomCenter,
            child: _drawerOpen
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                    child: GlassSurface(
                      radius: 18,
                      blur: kBlur,
                      pad: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                      child: Row(children: [
                        Expanded(
                          child: _DrawerBtn(
                            icon: Icons.home_outlined,
                            label: '返回主界面',
                            // ★v27.0.11 对话页是 push 全屏页：返回 = pop 回主页
                            onTap: () => Navigator.of(context).maybePop(),
                          ),
                        ),
                        Expanded(
                          child: _DrawerBtn(
                            icon: Icons.settings_outlined,
                            label: '对话设置',
                            onTap: () => _openSettings(),
                          ),
                        ),
                        Expanded(
                          child: _DrawerBtn(
                            icon: Icons.delete_outline,
                            label: '清空聊天',
                            onTap: () async {
                              final a = _a;
                              if (a == null) return;
                              final ok = await _confirm(context, '清空聊天记录', '和包娜的聊天记录会全部删掉，确定吗？');
                              if (ok == true) {
                                await a.clearChat();
                                if (mounted) setState(() => _msgs.clear());
                              }
                            },
                          ),
                        ),
                      ]),
                    ),
                  )
                : const SizedBox(width: 0, height: 0),
          ),
          // 输入栏（玻璃胶囊）★v27.0.10 对话页无主底栏：输入栏直接坐底（安全区之上），
          //   键盘弹起时 SafeArea 自动失效贴键盘顶，消息列表紧跟输入框
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
              child: GlassSurface(
                radius: kRCapsule,
                blur: kBlur,
                pad: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                child: Row(children: [
                  // ★v27.0.10 呼出按钮：箭头指向右边 = 点击呼出对话功能区；展开后箭头转左 = 收起
                  GestureDetector(
                    onTap: () => setState(() => _drawerOpen = !_drawerOpen),
                    child: AnimatedRotation(
                      turns: _drawerOpen ? 0.5 : 0,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: _drawerOpen ? kAccent.withValues(alpha: 0.9) : kBg2,
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0x26FFFFFF), width: 0.8),
                        ),
                        child: const Icon(Icons.chevron_right, size: 21, color: kText),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TextField(
                      controller: _inp,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      enableSuggestions: false, // ★v27.0.13 关掉 iOS 拼写检查（双黄下划线）
                      autocorrect: false,
                      style: const TextStyle(fontSize: 16, color: kText),
                      decoration: const InputDecoration(
                        hintText: '跟包娜说点什么…',
                        hintStyle: TextStyle(color: kSub, fontSize: 15.5),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: _send,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: kAccent,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: kAccent.withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 3)),
                        ],
                      ),
                      child: const Icon(Icons.arrow_upward_rounded, size: 20, color: Colors.white),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ]),
        ),
      ),
      ]),
      ),
    );
  }

  /// 消息唯一 key：本地消息用 cid，assistant 消息没 cid 用 time
  String _mkey(Msg m) {
    final c = m.cid;
    return (c != null && c.isNotEmpty) ? c : 't${m.time}';
  }

  Widget _row(Msg m, String herAv, String myAv) {
    final me = m.role == 'me';
    final bubble = Container(
      // ★v27.0.9 文字太窄：0.68 → 0.78（微信级舒适宽度，头像+留白之外几乎铺满）
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: me ? kAccent : kBg2,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(me ? 18 : 6),
          topRight: Radius.circular(me ? 6 : 18),
          bottomLeft: const Radius.circular(18),
          bottomRight: const Radius.circular(18),
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(m.content,
            style: TextStyle(
                fontSize: app.fontSize, height: 1.35, color: me ? Colors.white : kText)),
        const SizedBox(height: 3),
        Text(_hm(m.time ?? 0),
            style: TextStyle(fontSize: 10, color: me ? Colors.white.withValues(alpha: 0.7) : kSub)),
        if (m.st == 'failed')
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Text('发送失败', style: TextStyle(fontSize: 10.5, color: Color(0xFFFF453A))),
          ),
      ]),
    );
    final avatar = _Av(av: me ? myAv : herAv, size: 34, fallback: me ? '我' : '娜');
    // ★v27.0.16.1 气泡宽度修复：Flexible 必须 flex:0（否则默认 flex:1 跟 Spacer 平分宽度，气泡只占一半还往左偏）；
    //   用 mainAxisAlignment 对齐代替 Spacer，气泡按内容取宽、最多到 0.78 屏幕宽
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: me ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: me
            ? [Flexible(flex: 0, child: bubble), const SizedBox(width: 8), avatar]
            : [avatar, const SizedBox(width: 8), Flexible(flex: 0, child: bubble)],
      ),
    );
  }

  String _hm(int t) {
    if (t <= 0) return '';
    final d = DateTime.fromMillisecondsSinceEpoch(t);
    final h = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '$h:$mm';
  }

  Widget _TypingRow() => const Padding(
        padding: EdgeInsets.fromLTRB(14, 8, 14, 8),
        child: Row(children: [
          SizedBox(width: 34),
          SizedBox(width: 8),
          Text('她正在输入…', style: TextStyle(fontSize: 13, color: kSub)),
        ]),
      );
}

/// ★v27.0.1 空聊天区提示
class _EmptyHint extends StatelessWidget {
  const _EmptyHint();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            color: kBg2,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0x26FFFFFF), width: 0.8),
          ),
          child: const Icon(Icons.favorite_border, size: 30, color: kSub),
        ),
        const SizedBox(height: 16),
        const Text('和包娜说第一句话吧',
            style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        const Text('她会认真回你的',
            style: TextStyle(fontSize: 13, color: kSub)),
      ]),
    );
  }
}

/// 圆形头像：同 URL 走 avatarOf 缓存（不闪回占位字）
class _Av extends StatelessWidget {
  const _Av({required this.av, required this.size, required this.fallback});
  final String av;
  final double size;
  final String fallback;

  @override
  Widget build(BuildContext context) {
    final p = av.isEmpty ? null : avatarOf(av);
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: kBg2,
        border: Border.all(color: const Color(0x33FFFFFF), width: 0.8),
      ),
      child: p == null
          ? Center(
              child: Text(fallback,
                  style: TextStyle(fontSize: size * 0.42, fontWeight: FontWeight.w600, color: kText)))
          : Image(
              image: p,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) => Center(
                  child: Text(fallback,
                      style: TextStyle(fontSize: size * 0.42, fontWeight: FontWeight.w600, color: kText))),
            ),
    );
  }
}

/// ★v27.0.10 对话功能区按钮：图标 + 文字竖排（返回主界面 / 对话设置 / 清空聊天）
class _DrawerBtn extends StatelessWidget {
  const _DrawerBtn({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 21, color: kAccent),
          const SizedBox(height: 3),
          Text(label,
              style: const TextStyle(fontSize: 11, color: kSub, fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }
}
