// 包娜 App · 聊天页：她的话、你的话、表情包、照片、语音条、骰子、红包
import 'dart:async';
import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'api.dart';
import 'main.dart';
import 'msglocal.dart';
import 'imgsrv.dart';
import 'theme.dart';
import 'sheets.dart';
import 'stickers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ConversationPage extends StatefulWidget {
  const ConversationPage({super.key, this.roleId});
  final String? roleId;   // ★独立角色会话（null/空 = 包娜主对话）

  @override
  State<ConversationPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ConversationPage> {
  // ★独立角色会话：完全独立的上下文/缓存（包娜的『baona』缓存不碰）
  String get _role => widget.roleId ?? '';
  String get _cacheKey => _role.isEmpty ? 'baona' : 'role_$_role';
  // ★角色自定义备注/头像（本地存储，改完立刻同步到列表）
  String _roleName = '';
  String _roleAvatar = '';
  final List<Msg> _msgs = [];
  final TextEditingController _inp = TextEditingController();
  final FocusNode _focus = FocusNode(); // ★管键盘（弹出来就收面板 / 点空白就收键盘）
  final ScrollController _sc = ScrollController();
  final AudioPlayer _audio = AudioPlayer();
  StreamSubscription? _sub;
  bool _loading = true;
  bool _typing = false;
  int _cidSeq = 0;   // ★2026-09-30 发一条出两条：本地这条自己带编号，服务端广播回来按编号认领
  bool _emojiPanel = false;
  bool _funPanel = false;
  int _limit = 30;
  bool _hasMore = false;
  String? _playingUrl;
  // ★2026-09-30 修"对话记录乱跳"：记录"我现在在不在底部"——
  //   在底部 → 新消息/打字自动钉底；翻看历史 → 绝不打扰（不然你看旧消息时列表老被拉走）
  bool _atBottom = true;

  @override
  void initState() {
    super.initState();
    // ★2026-10-02 角色会话打开就清该会话未读（不进主对话红点）
    if (_role.isNotEmpty) app.sideClear(_role);
    _load();
    // ★角色备注/头像：从本地读（自定义了就显示自定义，没有就用默认）
    if (_role.isNotEmpty) {
      SharedPreferences.getInstance().then((sp) {
        final n = sp.getString('role.$_role.name') ?? '';
        final a = sp.getString('role.$_role.avatar') ?? '';
        if (mounted && (n != _roleName || a != _roleAvatar)) {
          setState(() {
            _roleName = n;
            _roleAvatar = a;
          });
        }
      });
    }
    _sub = app.brainOrApi?.events.listen(_onEvent);
    _sc.addListener(() {
      if (!_sc.hasClients) return;
      final atBottom = _sc.position.pixels >= _sc.position.maxScrollExtent - 80;
      if (atBottom != _atBottom) _atBottom = atBottom;
      if (_sc.position.pixels <= 40 && _hasMore && !_loading) _load(more: true);
    });
    _audio.onPlayerComplete.listen((_) => setState(() => _playingUrl = null));
    // ★一开始打字就把表情/功能面板收起来（不然面板+键盘叠在一起，屏幕只剩一条缝）
    _focus.addListener(() {
      if (_focus.hasFocus && (_emojiPanel || _funPanel)) {
        setState(() {
          _emojiPanel = false;
          _funPanel = false;
        });
      }
      // ★2026-09-29：键盘弹起来会把列表顶上去（看着像"跳到上面去"）→ 等键盘动画走完再钉到底
      if (_focus.hasFocus) {
        Future.delayed(const Duration(milliseconds: 340), () {
          if (mounted) _toBottom();
        });
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _focus.dispose();
    _inp.dispose();
    _sc.dispose();
    _audio.dispose();
    super.dispose();
  }

  Future<void> _load({bool more = false}) async {
    final a = app.api;
    // ★2026-09-30 本地缓存：打开先读本地秒开 —— 断网也能看历史
    if (!more && _msgs.isEmpty) {
      final cached = await MsgsLocal.load(_cacheKey);
      if (cached.isNotEmpty && mounted) {
        setState(() {
          _msgs
            ..clear()
            ..addAll(cached);
          _loading = false;
          _hasMore = false; // 离线时先不显示"加载更多"
        });
        _toBottom();
      }
    }
    if (a == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    // ★2026-09-30 加载更多：记下"当前第一条"和"当前滚动位置"，
    //   回来后在头部插新消息，并把位置补偿回原位（以前 clear+addAll → 列表整个重建 → 乱跳）
    final oldFirstKey = _msgs.isNotEmpty ? (_msgs.first.cid ?? 'i${_msgs.first.idx}') : null;
    final oldOffset = _sc.hasClients ? _sc.position.pixels : 0.0;
    final oldCount = _msgs.length;
    if (more) _limit += 30;
    Map<String, dynamic>? j;
    try {
      final dynamic a = app.brainOrApi;
      // ★独立角色：走独立历史接口（人设/上下文/记忆和包娜完全隔离）
      j = a == null
          ? null
          : (_role.isNotEmpty ? await a.roleHistory(_role, limit: _limit) : await a.history(limit: _limit));
    } catch (_) {
      // 断网：本地缓存已经显示了，安静地停在这里（不弹错、不打断）
      if (mounted) setState(() => _loading = false);
      return;
    }
    if (!mounted) return;
    final list = ((_role.isNotEmpty ? (j?['history'] as List?) : (j?['messages'] as List?)) ?? [])
        .map((e) => Msg.fromJson(Map.from(e)))
        .toList();
    setState(() {
      _msgs
        ..clear()
        ..addAll(MsgsLocal.merge(list, _msgs));
      _hasMore = j?['hasMore'] == true;
      _loading = false;
    });
    // ★同步成功 → 落盘，下次打开/断网直接看本地
    MsgsLocal.save(_cacheKey, _msgs);
    if (more && _sc.hasClients) {
      // 新消息插在头部 → 旧列表第一条下移了 → 按"新增条数 × 平均行高"把位置补回去
      final added = _msgs.length - oldCount;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_sc.hasClients) return;
        final target = (oldOffset + added * 46).clamp(0.0, _sc.position.maxScrollExtent);
        try { _sc.jumpTo(target); } catch (e) { /* ignore */ }
      });
    } else if (!more) {
      _toBottom();
    }
  }

  void _onEvent(Map<String, dynamic> e) {
    final t = '${e['type']}';
    if (t == 'msg') {
      // ★2026-09-29 老公报"只出现头像框、过一会儿才加载出文字"的真凶：
      //   电脑端发的形状是 {type:'msg', msg:{role,content,...}}，这里以前直接把最外层丢给
      //   Msg.fromJson → content 拿到的是空字符串 → 先画一个只有头像的空泡泡，等下次刷新才有字。
      //   现在先拆信封。
      final raw = e['msg'];
      final body = raw is Map ? Map<String, dynamic>.from(raw) : e;
      // ★独立角色分流：角色消息带 roleId —— 包娜会话不收角色消息，角色会话只收自己的
      final rid = '${body['roleId'] ?? ''}';
      if (rid != _role) return;
      final m = Msg.fromJson(body);
      if (m.role == 'user' || m.role == 'me') m.role = 'me';
      // 防御：正文/表情/语音/图全空的，一律不画（宁可少一条，也不出空泡泡）
      final hasSomething = m.content.isNotEmpty || (m.sticker?.isNotEmpty ?? false) || (m.voice?.isNotEmpty ?? false);
      if (!hasSomething) return;
      // 自己发的（乐观显示过）就就地升级，不重复
      // ★2026-09-30 发一条出两条的真凶修法：先按编号认（最准），认不着再退回"内容 + pending"
      final ecid = '${body['cid'] ?? e['cid'] ?? ''}';
      final i = findEchoTarget(_msgs, m, ecid);
      // ★26.2.20 回复已由 brain 落盘（会话关着也在本地），打开时 _load 已读入 →
      //   广播再回来要就地更新，别重复画一条
      final i2 = (m.role == 'assistant' && ecid.isNotEmpty)
          ? _msgs.indexWhere((x) => x.role == 'assistant' && x.cid == ecid)
          : -1;
      setState(() {
        if (m.role == 'me' && i >= 0) {
          _msgs[i] = m..st = 'ok';
        } else if (i2 >= 0) {
          _msgs[i2] = m;
        } else {
          _msgs.add(m);
        }
        _typing = false;
      });
      _toBottom();
      // ★本地缓存跟上（不然缓存停在旧位置，下次打开少几条）
      MsgsLocal.save(_cacheKey, _msgs);
    } else if (t == 'msg-patch') {
      // ★角色会话暂不支持语音条补推（角色回复是纯文本），直接忽略
      if (_role.isNotEmpty) return;
      // ★电脑端这条的形状是 {type:'msg-patch', cid, patch:{voice:...}}，以前按 idx 找 → 永远找不到
      final cid = e['cid']?.toString();
      final patch = e['patch'];
      final v = patch is Map ? patch['voice']?.toString() : e['voice']?.toString();
      if (v != null && v.isNotEmpty) {
        var i = -1;
        if (cid != null && cid.isNotEmpty) i = _msgs.indexWhere((x) => x.cid == cid);
        if (i < 0) {
          final idx = Msg.toInt(e['idx']);
          if (idx != null) i = _msgs.indexWhere((x) => x.idx == idx);
        }
        if (i >= 0) setState(() => _msgs[i].voice = v);
      }
    } else if (t == 'voice') {
      // ★电脑端语音条是"文字先到、语音合成好了再补推"：{type:'voice', cid, url}
      //   以前手机端完全不认这条 → 她的语音条要等下次刷新才出现
      final cid = e['cid']?.toString();
      final u = e['url']?.toString();
      if (cid != null && cid.isNotEmpty && u != null && u.isNotEmpty) {
        final i = _msgs.indexWhere((x) => x.cid == cid);
        if (i >= 0) {
          setState(() {
            _msgs[i].voice = u;
            _msgs[i].content = '';
          });
        }
      }
    } else if (t == 'typing') {
      // ★角色会话：桌宠端角色不推打字状态，忽略
      if (_role.isNotEmpty) return;
      setState(() => _typing = e['on'] != false);
      if (_typing) _toBottom();
    } else if (t == 'cleared') {
      // ★角色会话：清空消息广播只对包娜主对话生效，别误清角色历史
      if (_role.isNotEmpty) return;
      setState(() => _msgs.clear());
      MsgsLocal.clear(_cacheKey);
    }
  }

  void _toBottom({bool force = false}) {
    // ★2026-09-30：不在底部就别把列表拉走（翻看历史/看旧消息时绝不打扰）；
    //   自己发的消息 force=true 总是钉底。
    if (!force && !_atBottom) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_sc.hasClients) return;
      final target = _sc.position.maxScrollExtent;
      // ★2026-09-29 老公报"发完消息列表弹到上面去"：animateTo 会被紧接着的下一条消息 /
      //   键盘弹起 / 面板收起打断，停在半路 —— 所以动画走完再钉一次底。
      _sc.animateTo(target, duration: const Duration(milliseconds: 200), curve: Curves.easeOut).then((_) {
        if (mounted && _sc.hasClients) {
          try { _sc.jumpTo(_sc.position.maxScrollExtent); } catch (e) { /* ignore */ }
        }
      }).catchError((_) {});
    });
  }

  Future<void> _send(Map<String, dynamic> payload, {String? show}) async {
    final dynamic a = app.brainOrApi;
    if (a == null) return;
    try { HapticFeedback.lightImpact(); } catch (e) { /* 桌面/web 上没有 */ } // ★发出去手感跟一下
    final text = '${payload['text'] ?? ''}';
    // ★2026-09-30 修"发一条出两条"：本地先画的这条以前不带编号，服务端把它广播回来时认不出是自己的
    //   → 又画了一条一模一样的。现在这条自己带编号，发出去也带同一个。
    final cid = '${payload['cid'] ?? 'c${DateTime.now().millisecondsSinceEpoch}-${++_cidSeq}'}';
    payload['cid'] = cid;
    final m = Msg(role: 'me', content: show ?? text, st: 'pending', time: DateTime.now().millisecondsSinceEpoch, sticker: payload['sticker']?.toString(), cid: cid);
    setState(() {
      _msgs.add(m);
      _emojiPanel = false;
      _funPanel = false;
    });
    MsgsLocal.save(_cacheKey, _msgs); // ★本地先存，万一没发出去/断网也留着
    _toBottom(force: true);
    // ★独立角色：走独立发送接口（只发文字）；包娜走原来的 send（表情/骰子/红包等 payload）
    final r = _role.isNotEmpty ? await a.roleSend(_role, text) : await a.send(payload);
    if (!mounted) return;
    setState(() => m.st = r['ok'] == true ? 'ok' : 'failed');
  }

  void _sendText() {
    final t = _inp.text.trim();
    if (t.isEmpty) return;
    _inp.clear();
    HapticFeedback.lightImpact();
    _send({'text': t});
  }

  /// ★角色设置：点头像/名字 → 改备注 / 改头像（只影响这个角色，和包娜互不相干）
  Future<void> _openRoleSettings() async {
    if (_role.isEmpty) return;
    final sp = await SharedPreferences.getInstance();
    final act = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF232329),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Padding(
            padding: EdgeInsets.only(top: 14, bottom: 10),
            child: Text('角色设置', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
          ListTile(
            leading: const Icon(Icons.badge_outlined),
            title: const Text('改备注'),
            subtitle: const Text('列表和聊天页显示的名字'),
            onTap: () => Navigator.pop(c, 'name'),
          ),
          ListTile(
            leading: const Icon(Icons.face_retouching_natural),
            title: const Text('改头像'),
            subtitle: const Text('从相册选一张，只存在手机本地'),
            onTap: () => Navigator.pop(c, 'avatar'),
          ),
          // ★26.2.20 清除对话 / 清除记忆（角色会话独立，和包娜主对话互不相干）
          ListTile(
            leading: const Icon(Icons.delete_sweep_outlined),
            title: const Text('清除对话'),
            subtitle: const Text('删掉这个角色的聊天记录，人设和记忆保留'),
            onTap: () => Navigator.pop(c, 'clrChat'),
          ),
          ListTile(
            leading: const Icon(Icons.psychology_alt_outlined),
            title: const Text('清除记忆'),
            subtitle: const Text('忘掉它记得的事，对话保留'),
            onTap: () => Navigator.pop(c, 'clrMem'),
          ),
          const SizedBox(height: 6),
        ]),
      ),
    );
    if (act == null || !mounted) return;
    if (act == 'name') {
      final ctl = TextEditingController(text: _roleName.isEmpty ? roleNameOf(_role) : _roleName);
      final v = await showDialog<String>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('改备注'),
          content: TextField(controller: ctl, maxLength: 12, autofocus: true, decoration: const InputDecoration(hintText: '输入想显示的名字')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('算了')),
            FilledButton(
                onPressed: () => Navigator.pop(c, ctl.text.trim()),
                child: const Text('保存')),
          ],
        ),
      );
      if (v != null && v.isNotEmpty && mounted) {
        await sp.setString('role.$_role.name', v);
        setState(() => _roleName = v);
        toast(context, '备注已改 ✓');
        // ★26.2.17 自建角色同步到本地大脑（她回复时的名字跟着变）
        await app.brain?.roleSave({'id': _role, 'name': v});
      }
    } else if (act == 'avatar') {
      try {
        final f = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 720, imageQuality: 82);
        if (f == null) return;
        final bytes = await f.readAsBytes();
        final data = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        await sp.setString('role.$_role.avatar', data);
        await app.brain?.roleSave({'id': _role, 'letter': '图'});
        if (mounted) {
          setState(() => _roleAvatar = data);
          toast(context, '头像已换 ✓');
        }
      } catch (e) {
        if (mounted) toast(context, '选图失败：$e');
      }
    } else if (act == 'clrChat' || act == 'clrMem') {
      final what = act == 'clrChat' ? '对话记录' : '记忆';
      final sure = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text('清除${what}？'),
          content: Text('${_roleName.isEmpty ? roleNameOf(_role) : _roleName} 的$what会被清空，${act == 'clrChat' ? '人设和记忆不受影响' : '对话不受影响'}。'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('算了')),
            FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('清除', style: TextStyle(color: Colors.white))),
          ],
        ),
      );
      if (sure != true || !mounted) return;
      final dynamic a = app.brainOrApi;
      if (a == null) return;
      Map<String, dynamic> r;
      if (act == 'clrChat') {
        r = await a.roleClear(_role);
      } else if (app.brain != null) {
        r = await a.roleClearMem(_role);
      } else {
        r = {'ok': false, 'error': '清除记忆要本地模式'};
      }
      if (mounted) toast(context, r['ok'] == true ? '已清除 ✓' : '没清掉：${r['error'] ?? ''}');
    }
  }

  /// ★2026-09-29：用手机摄像头给她看一眼 —— 拍一张传上去，电脑端会让她真看到（她的眼睛）
  Future<void> _eyeFromCamera() async {
    final a = app.api;
    if (a == null) return;
    try {
      final f = await ImagePicker().pickImage(source: ImageSource.camera, maxWidth: 1280, imageQuality: 78);
      if (f == null) return;
      final bytes = await f.readAsBytes();
      toast(context, '让她看着呢…');
      final r = await a.eyePush('data:image/jpeg;base64,${base64Encode(bytes)}');
      if (!mounted) return;
      toast(context, r['ok'] == true ? '她看到了 ✓ 等她说' : '没送过去：${r['error'] ?? '连不上'}');
    } catch (e) {
      if (mounted) toast(context, '打不开相机：$e');
    }
  }

  Future<void> _sendPhoto() async {
    final a = app.api;
    if (a == null) return;
    try {
      final f = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1400, imageQuality: 82);
      if (f == null) return;
      final bytes = await f.readAsBytes();
      final data = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      toast(context, '正在发照片…');
      final up = await a.chatImg(data);
      if (up['ok'] != true) {
        if (mounted) toast(context, '传不上去：${up['error'] ?? ''}');
        return;
      }
      await _send({'text': '[图片]', 'img': '${up['img'] ?? ''}'}, show: '[照片]');
    } catch (e) {
      if (mounted) toast(context, '发图失败：$e');
    }
  }

  Future<void> _rollDice() async {
    final n = 1 + (DateTime.now().microsecond % 6);
    await _send({'text': '🎲 我掷了 $n 点', 'roll': n});
  }

  Future<void> _sendPacket() async {
    final amt = TextEditingController();
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('发红包'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: amt, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: '金额（元）')),
          const SizedBox(height: 10),
          TextField(controller: note, decoration: const InputDecoration(hintText: '祝福语（不填：恭喜发财，大吉大利）')),
          const SizedBox(height: 12),
          Wrap(spacing: 8, children: [
            for (final v in ['5.2', '13.14', '52', '520'])
              Chip2('¥$v', on: () => amt.text = v),
          ]),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('算了')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('发给她')),
        ],
      ),
    );
    if (ok != true) return;
    final a = double.tryParse(amt.text.trim()) ?? 0;
    if (a <= 0) return;
    final n = note.text.trim().isEmpty ? '恭喜发财，大吉大利' : note.text.trim();
    await _send({'text': '🧧 $n', 'packet': a, 'note': n});
  }

  Future<void> _play(String url) async {
    if (_playingUrl == url) {
      await _audio.stop();
      setState(() => _playingUrl = null);
      return;
    }
    setState(() => _playingUrl = url);
    await _audio.stop();
    await _audio.play(UrlSource(url));
  }

  @override
  Widget build(BuildContext context) {
    final dynamic a = app.brainOrApi;
    if (a == null) return const Center(child: CircularProgressIndicator());
    // ★自检：URL 带 ?dbg=1 时，把这页的真实布局数字打到控制台（手机上没有这个参数，不受影响）
    if (Uri.base.queryParameters['dbg'] == '1') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          final box = context.findRenderObject() as RenderBox?;
          final dy = box == null ? -1 : box.localToGlobal(Offset(0, box.size.height)).dy;
          final m = MediaQuery.of(context);
          // ignore: avoid_print
          print('[dbg] screen=${m.size.height} padB=${m.padding.bottom} kb=${m.viewInsets.bottom} '
              'navSpace=${navSpace(context)} pageBottomY=${dy.toStringAsFixed(1)}');
        } catch (_) {}
      });
    }
    // ★2026-09-30 微信式改造：这是点进会话后的全屏对话页 —— 没有底栏，只有返回+消息+输入框
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Wall(
        url: app.bg,
        blur: app.bgBlur,
        opacity: app.bgOpacity,
        child: Column(children: [
      _ConvHeader(
        onBack: () => Navigator.of(context).maybePop(),
        onSearch: () => openSearch(context),
        onSet: () => openSettings(context),
        onCtrl: () => openCtrl(context),
        // ★独立角色：标题/头像显示角色自己的，不显示包娜的；点头像/名字可改备注和头像
        title: _role.isNotEmpty ? (_roleName.isNotEmpty ? _roleName : roleNameOf(_role)) : app.nick,
        avatar: _role.isNotEmpty ? _roleAvatar : '${app.herSet['herAvatar'] ?? ''}',
        letter: _role.isNotEmpty ? roleLetterOf(_role) : '娜',
        onRoleTap: _role.isNotEmpty ? _openRoleSettings : null,
      ),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : GestureDetector(
                // ★点空白处把键盘收回去（iOS 上滑列表也能收：keyboardDismissBehavior）
                onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
                behavior: HitTestBehavior.opaque,
                child: ListView.builder(
                controller: _sc,
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(14, 8, 14, kbUp(context) ? 16 : MediaQuery.of(context).padding.bottom + 16),
                itemCount: _msgs.length + (_typing ? 1 : 0) + (_hasMore ? 1 : 0),
                itemBuilder: (c, i) {
                  if (_hasMore && i == 0) {
                    return const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Center(child: Text('往上滑看更早的', style: TextStyle(fontSize: 11.5, color: kSub))));
                  }
                  final k = i - (_hasMore ? 1 : 0);
                  if (k >= _msgs.length) return const _TypingBubble();
                  final m = _msgs[k];
                  final prev = k > 0 ? _msgs[k - 1] : null;
                  // ★2026-09-29：隔得久（>30 分钟）或跨天时插一行时间，翻记录一眼知道"这是啥时候说的"
                  final gap = prev == null || (m.time != null && prev.time != null && (m.time! - prev.time!) > 30 * 60 * 1000);
                  // ★26.2.22 苹果官网动效：刚来的新消息（5 秒内）淡入上浮；历史消息不逐个动画
                  final fresh = m.time != null && (DateTime.now().millisecondsSinceEpoch - m.time!) < 5000;
                  final bubble = _Bubble(m: m, fresh: fresh, onResend: () => _send({'text': m.content}), onPlay: _play, playing: _playingUrl, urlOf: a,
                      roleSrc: _role.isNotEmpty ? _roleAvatar : '', roleLetter: _role.isNotEmpty ? roleLetterOf(_role) : '');
                  if (!gap) return bubble;
                  return Column(children: [
                    if (m.time != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 10, bottom: 2),
                        child: Text(fmtDay(m.time!), style: const TextStyle(fontSize: 11, color: kSub)),
                      ),
                    bubble,
                  ]);
                },
                ),
              ),
      ),
      // ★底栏是悬浮玻璃 → 聊天这半截整块往上抬，输入栏跟底栏保持同一条线（老公 2026-09-29）
      Padding(
        padding: EdgeInsets.only(bottom: kbUp(context) ? 6 : MediaQuery.of(context).padding.bottom + 10),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
      if (_emojiPanel && _role.isEmpty) EmojiPanel(onPick: (n) => _send({'text': '[表情]', 'sticker': n}), onClose: () => setState(() => _emojiPanel = false)),
      _Composer(
        ctl: _inp,
        focus: _focus,
        onSend: _sendText,
        // ★独立角色：不显示表情/加号（角色接口只认文字），点按无反应
        onPlus: _role.isEmpty ? () => setState(() {
          _funPanel = !_funPanel;
          _emojiPanel = false;
        }) : () {},
        onSticker: _role.isEmpty ? () => setState(() {
          _emojiPanel = !_emojiPanel;
          _funPanel = false;
        }) : () {},
        simple: _role.isNotEmpty,
      ),
      if (_funPanel && _role.isEmpty)
        _FunPanel(
          onPhoto: _sendPhoto,
          onSticker: () => setState(() {
            _emojiPanel = true;
            _funPanel = false;
          }),
          onDice: () => setState(() {
            _funPanel = false;
            _rollDice();
          }),
          onPacket: () => setState(() {
            _funPanel = false;
            _sendPacket();
          }),
          onGame: () => setState(() => _funPanel = false),
          onShop: () => setState(() => _funPanel = false),
          // 让她用眼睛看一眼（手机上也能使唤她的眼睛了）
          onLook: (q) => setState(() {
            _funPanel = false;
            _send({'text': q});
          }),
          // 用这台手机自己的摄像头拍一张给她看
          onEye: () => setState(() {
            _funPanel = false;
            _eyeFromCamera();
          }),
        ),
        ]),
      ),
        ]),
      ),
    );
  }
}

/* ------------------------------- 一条消息 ------------------------------- */
class _Bubble extends StatefulWidget {
  _Bubble({required this.m, required this.onResend, required this.onPlay, required this.playing, required this.urlOf, this.roleSrc = '', this.roleLetter = '', this.fresh = false});
  final Msg m;
  final VoidCallback onResend;
  final void Function(String) onPlay;
  final String? playing;
  final dynamic urlOf; // ★26.2.17 本地模式也是它（LocalBrain 同名方法）
  final String roleSrc;    // ★2026-10-02 角色会话：她消息行的头像
  final String roleLetter; // ★角色字
  final bool fresh;        // ★26.2.22 苹果官网动效：新消息才淡入上浮，历史不逐个动画

  @override
  State<_Bubble> createState() => _BubbleState();
}

class _BubbleState extends State<_Bubble> with SingleTickerProviderStateMixin {
  // ★2026-10-01：她的【细节】（动作/表情/心里）默认展开显示，点箭头收起
  bool _detailOn = true;
  // ★26.2.22：新消息 380ms 淡入上浮（easeOutCubic，跟手不晃）；历史消息直接 1.0 不动画
  late final AnimationController _in;

  static final RegExp _imgRe = RegExp(r'!\[[^\]]*\]\(([^)]+)\)');

  @override
  void initState() {
    super.initState();
    _in = AnimationController(
      vsync: this,
      duration: widget.fresh ? const Duration(milliseconds: 380) : Duration.zero,
      value: widget.fresh ? 0 : 1,
    );
    if (widget.fresh) _in.forward();
  }

  @override
  void dispose() {
    _in.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.m;
    final me = m.role == 'me' || m.role == 'user';
    final fs = app.fontSize;

    // 正文里的图片（她/他发的照片，服务端存成 ![](/api/chatimg/xxx)）
    String text = m.content;
    final imgs = <String>[];
    if (text.contains('/api/chatimg/')) {
      for (final mm in _imgRe.allMatches(text)) {
        imgs.add(mm.group(1)!);
      }
      text = text.replaceAll(_imgRe, '').trim();
    }

    final Widget body = Column(
      crossAxisAlignment: me ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        if (app.cfg['showTime'] == true && m.time != null)
          Padding(padding: const EdgeInsets.only(bottom: 3), child: Text(fmtClock(m.time!), style: const TextStyle(fontSize: 10.5, color: kSub))),
        if (m.sticker != null && m.sticker!.isNotEmpty && !m.content.contains('![表情]'))
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: CacheImg(widget.urlOf.emojiUrl(m.sticker!), width: 132, fit: BoxFit.cover),
          ),
        for (final u in imgs)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: CacheImg(widget.urlOf.imgUrl(u), width: 210, fit: BoxFit.cover),
            ),
          ),
        if (m.voice != null && m.voice!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: GlassSurface(
              radius: kRCapsule,
              blur: 12,
              tint: me ? app.myColor : app.herColor,
              onTap: () => widget.onPlay(widget.urlOf.voiceUrl(m.voice!)),
              pad: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(widget.playing == widget.urlOf.voiceUrl(m.voice!) ? Icons.graphic_eq : Icons.play_arrow, size: 16),
                const SizedBox(width: 6),
                const Text('语音条 · 点开听', style: TextStyle(fontSize: 12.5)),
              ]),
            ),
          ),
        if (text.isNotEmpty)
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.76),
            child: GlassSurface(
              radius: 20,
              blur: 14,
              tint: me ? app.myColor : app.herColor,
              pad: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: SelectableText(text, style: TextStyle(fontSize: fs, height: 1.45)),
            ),
          ),
        // ★2026-10-01：她的【细节】（动作/表情/心里）—— 默认展开显示，点箭头收起
        if (!me && m.detail != null && m.detail!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _detailOn = !_detailOn),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(_detailOn ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                      size: 15, color: kSub),
                  if (_detailOn)
                    Flexible(
                      child: Text(m.detail!,
                          style: TextStyle(fontSize: fs - 2.5, height: 1.35, color: kSub, fontStyle: FontStyle.italic)),
                    ),
                ],
              ),
            ),
          ),
        if (m.st == 'failed')
          TextButton(onPressed: widget.onResend, child: const Text('没发出去 · 点我重发', style: TextStyle(fontSize: 11.5, color: Color(0xFFFF9A9A)))),
      ],
    );

    // ★2026-09-29：正在发的那条淡一点（一眼看出"还没发出去"），发出去就恢复
    // ★26.2.22：新消息外面再包一层淡入上浮（苹果官网感）；历史消息直接显示
    Widget row = Opacity(
      opacity: m.st == 'pending' ? 0.6 : 1,
      child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: me ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!me) ...[
            _MiniAvatar(me: false, src: widget.roleSrc, letter: widget.roleLetter),
            const SizedBox(width: 7),
          ],
          Flexible(child: body),
          // ★b37 我的消息右侧也有头像（微信式左右各一个）
          if (me) ...[
            const SizedBox(width: 7),
            const _MiniAvatar(me: true),
          ],
        ],
      ),
      ),
    );
    if (widget.fresh) {
      row = AnimatedBuilder(
        animation: _in,
        child: row,
        builder: (context, child) => Opacity(
          opacity: CurvedAnimation(parent: _in, curve: Curves.easeOutCubic).value,
          child: Transform.translate(
            offset: Offset(0, 16 * (1 - _in.value)),
            child: child,
          ),
        ),
      );
    }
    return row;
  }
}

class _MiniAvatar extends StatefulWidget {
  const _MiniAvatar({super.key, this.me = false, this.src = '', this.letter = ''});
  final bool me;
  final String src;    // ★2026-10-02 角色会话：她的消息头像用角色自定义头像（列表换了，消息行也要跟着换）
  final String letter; // ★角色字（没头像时显示，不再错显示成"娜"）

  @override
  State<_MiniAvatar> createState() => _MiniAvatarState();
}

class _MiniAvatarState extends State<_MiniAvatar> {
  // ★2026-10-02 闪屏修复：future 只在 initState / me 变化时取一次 ——
  //   之前每次 build 都新建 Future，FutureBuilder 重置 → 消息头像闪回占位再显示
  late Future<ImageProvider> _f = ImgCache.provider(_av());

  String _av() {
    if (widget.me) return '${app.herSet['myAvatar'] ?? ''}';
    if (widget.src.isNotEmpty) return widget.src;   // ★角色自定义头像优先
    return '${app.herSet['herAvatar'] ?? ''}';
  }

  @override
  void didUpdateWidget(_MiniAvatar old) {
    super.didUpdateWidget(old);
    if (old.me != widget.me || old.src != widget.src) _f = ImgCache.provider(_av());
  }

  @override
  Widget build(BuildContext context) {
    final av = _av();
    if (av.isEmpty) {
      return Container(
        width: 30,
        height: 30,
        decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [kAccent, kAccent2])),
        child: Center(
            child: Text(widget.me ? '我' : (widget.letter.isNotEmpty ? widget.letter : '娜'),
                style: const TextStyle(fontSize: 13))),
      );
    }
    // ★b21 头像磁盘缓存：不再每次打开对话都重新下载
    return FutureBuilder<ImageProvider>(
      future: _f,
      builder: (c, s) => Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(colors: [kAccent, kAccent2]),
          image: s.data == null ? null : DecorationImage(image: s.data!, fit: BoxFit.cover),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatefulWidget {
  const _TypingBubble();
  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble> with SingleTickerProviderStateMixin {
  // ★2026-09-29：她说"正在打字"的时候点会跳 —— 一眼知道对面在动，不是在卡
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1050))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          const _MiniAvatar(),
          const SizedBox(width: 7),
          GlassSurface(
            radius: 20,
            blur: 14,
            tint: app.herColor,
            pad: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Text('她正在打字', style: TextStyle(fontSize: 12.5, color: kSub)),
              const SizedBox(width: 6),
              AnimatedBuilder(
                animation: _c,
                builder: (c, _) {
                  final n = (_c.value * 3).floor().clamp(0, 2) + 1;
                  return Text('.' * n, style: const TextStyle(fontSize: 13, height: 1.0, color: kSub, letterSpacing: 1.5));
                },
              ),
            ]),
          ),
        ]),
      );
}

/* ------------------------------- 输入区 ------------------------------- */
class _Composer extends StatelessWidget {
  _Composer({required this.ctl, required this.focus, required this.onSend, required this.onPlus, required this.onSticker, this.simple = false});
  final TextEditingController ctl;
  final FocusNode focus;
  final VoidCallback onSend, onPlus, onSticker;
  final bool simple;   // ★独立角色：只留输入框+发送

  @override
  Widget build(BuildContext context) => Padding(
        // ★跟底栏配成一套：一样的左右留白(14)、一样的胶囊圆角、一样的玻璃
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
        child: GlassSurface(
          radius: kRCapsule,
          blur: kBlur,
          pad: const EdgeInsets.fromLTRB(6, 5, 6, 5),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            if (!simple) _RoundBtn(icon: Icons.add, on: onPlus),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: TextField(
                  controller: ctl,
                  focusNode: focus,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                  style: const TextStyle(fontSize: 15.5, height: 1.35),
                  decoration: InputDecoration(
                    hintText: simple ? '跟刘紫灵说点什么…' : '跟她说点什么…',
                    filled: false,
                    isDense: true,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 9),
                  ),
                ),
              ),
            ),
            if (!simple) _RoundBtn(icon: Icons.emoji_emotions_outlined, on: onSticker),
            const SizedBox(width: 2),
            PressScale(
              onTap: onSend,
              radius: kRCapsule,
              scale: 0.92,
              child: Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [kAccent, kAccent2])),
                child: const Icon(Icons.send_rounded, size: 18),
              ),
            ),
          ]),
        ),
      );
}

class _RoundBtn extends StatelessWidget {
  const _RoundBtn({required this.icon, required this.on});
  final IconData icon;
  final VoidCallback on;

  @override
  Widget build(BuildContext context) => PressScale(
        onTap: on,
        radius: kRCapsule,
        scale: 0.9,
        child: SizedBox(width: 38, height: 38, child: Center(child: Icon(icon, size: 21, color: kText.withValues(alpha: 0.9)))),
      );
}

class _FunPanel extends StatelessWidget {
  const _FunPanel({required this.onPhoto, required this.onSticker, required this.onDice, required this.onPacket, required this.onGame, required this.onShop, required this.onLook, required this.onEye});
  final VoidCallback onPhoto, onSticker, onDice, onPacket, onGame, onShop, onEye;
  final void Function(String) onLook; // ★「让她看看」= 用她的眼睛（我 / 床上 / 桌上）

  @override
  Widget build(BuildContext context) {
    const cells = [
      [Icons.photo_outlined, '照片'],
      [Icons.emoji_emotions_outlined, '表情包'],
      [Icons.casino_outlined, '骰子'],
      [Icons.redeem_outlined, '红包'],
      [Icons.sports_esports_outlined, '飞行棋'],
      [Icons.shopping_bag_outlined, '商城'],
    ];
    final ons = [onPhoto, onSticker, onDice, onPacket, onGame, onShop];
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 2, 14, 8),
      child: GlassSurface(
        radius: 26,
        blur: kBlur,
        pad: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Column(children: [
          // ★2026-09-29：她的眼睛也能从手机上用（以前只有电脑端能让她看）
          Row(children: [
            const Text('让她看看', style: TextStyle(fontSize: 12, color: kSub)),
            const SizedBox(width: 10),
            Chip2('你', ico: Icons.remove_red_eye_outlined, on: () => onLook('看看我')),
            const SizedBox(width: 8),
            Chip2('床上', ico: Icons.bed_outlined, on: () => onLook('看看床上')),
            const SizedBox(width: 8),
            Chip2('桌上', ico: Icons.desk_outlined, on: () => onLook('看看桌上')),
            const SizedBox(width: 8),
            // ★用这台手机自己的摄像头（她那两只眼睛看不到的角度，随手拍给她看）
            Chip2('用手机拍', ico: Icons.photo_camera_outlined, on: onEye),
          ]),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          for (var i = 0; i < cells.length; i++)
            PressScale(
              onTap: ons[i],
              radius: kRCapsule,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(color: const Color(0x1FFFFFFF), shape: BoxShape.circle, border: Border.all(color: kHair)),
                  child: Icon(cells[i][0] as IconData, size: 21),
                ),
                const SizedBox(height: 5),
                Text('${cells[i][1]}', style: const TextStyle(fontSize: 11, color: kSub)),
              ]),
            ),
          ]),
        ]),
      ),
    );
  }
}


/* ------------------- 对话页头部（微信式：返回 + 头像 + 在线 + 快捷按钮） ------------------- */
class _ConvHeader extends StatelessWidget {
  const _ConvHeader(
      {required this.onBack,
      required this.onSearch,
      required this.onSet,
      required this.onCtrl,
      this.title = '',
      this.avatar = '',
      this.letter = '娜',
      this.simple = false,
      this.onRoleTap});
  final VoidCallback onBack, onSearch, onSet, onCtrl;
  final String title, avatar, letter;
  final bool simple;   // ★独立角色：只留返回+标题，不显示包娜专属按钮
  final VoidCallback? onRoleTap;   // ★角色模式：点头像/名字改备注和头像

  @override
  Widget build(BuildContext context) {
    final av = avatar;
    return GlassBar(
      top: true,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 8, 8, 8),
          child: Row(children: [
            IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19), tooltip: '返回'),
            GestureDetector(
              onTap: onRoleTap ?? onSet,
              // ★2026-10-02 闪屏修复：dataURL 头像改走 avatarOf 的 provider 缓存 ——
              //   之前每次 build 都重新 base64Decode 新建 MemoryImage → 缓存 miss → 头像闪
              child: (() {
                final p = av.startsWith('data:image/') ? avatarOf(av) : null;
                if (p != null) {
                  return Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      image: DecorationImage(image: p, fit: BoxFit.cover),
                    ),
                  );
                }
                if (av.isNotEmpty && !simple) {
                  return FutureBuilder<ImageProvider>(
                      future: ImgCache.provider(av),
                      builder: (c, s) => Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(colors: [kAccent, kAccent2]),
                              image: s.data == null ? null : DecorationImage(image: s.data!, fit: BoxFit.cover),
                            ),
                          ));
                }
                return Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [kAccent, kAccent2])),
                    child: Center(child: Text(letter, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))));
              })(),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title.isEmpty ? app.nick : title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Row(children: [
                    Container(width: 6, height: 6, decoration: BoxDecoration(color: app.online ? const Color(0xFF57D9A3) : kSub, shape: BoxShape.circle)),
                    const SizedBox(width: 5),
                    Flexible(child: Text(simple ? '独立角色 · 和包娜完全隔离' : app.status, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: kSub))),
                  ]),
                ],
              ),
            ),
            if (!simple) IconButton(onPressed: onSearch, icon: const Icon(Icons.search, size: 20), tooltip: '搜聊天'),
            if (!simple) IconButton(onPressed: onCtrl, icon: const Icon(Icons.tune, size: 20), tooltip: '控制器'),
            if (!simple) IconButton(onPressed: onSet, icon: const Icon(Icons.settings_outlined, size: 20), tooltip: '设置'),
          ]),
        ),
      ),
    );
  }
}

/* ------------------------- ★独立角色辅助（和主对话完全隔离） ------------------------- */
/// 全部角色 id（新增角色在这里补一行，桌宠端建好目录后手机端自动出现）
/// ★26.2.17 全本地化：内置角色 + 手机本地自建角色（对话列表里自己加的）
List<String> roleIds() {
  final out = <String>[
    'liuziling', 'nvwa', 'houtu', 'xiwangmu', 'medusa',
    'yunyun', 'xiaoxuaner', 'bibidong', 'qianrenxue', 'xiaowu',
    'guyuena', 'henrendadi', 'anmiaoyi', 'jiziyue', 'yanrudan', 'huolinger',
  ];
  try {
    final l = jsonDecode(Store.localRoles);
    if (l is List) {
      for (final r in l) {
        if (r is Map) out.add('${r['id']}');
      }
    }
  } catch (_) {/* 没自建角色就内置 */}
  return out;
}

String _customRoleField(String role, String key) {
  try {
    final l = jsonDecode(Store.localRoles);
    if (l is List) {
      for (final r in l) {
        if (r is Map && '${r['id']}' == role) return '${r[key] ?? ''}';
      }
    }
  } catch (_) {}
  return '';
}

/// 角色 id → 显示名（自定义备注优先，没备注用这个默认名）
String roleNameOf(String role) {
  final custom = _customRoleField(role, 'name');
  if (custom.isNotEmpty) return custom;
  switch (role) {
    case 'liuziling':
      return '刘紫灵';
    case 'nvwa':
      return '女娲';
    case 'houtu':
      return '后土';
    case 'xiwangmu':
      return '西王母';
    case 'medusa':
      return '美杜莎';
    case 'yunyun':
      return '云韵';
    case 'xiaoxuaner':
      return '萧薰儿';
    case 'bibidong':
      return '比比东';
    case 'qianrenxue':
      return '千仞雪';
    case 'xiaowu':
      return '小舞';
    case 'guyuena':
      return '古月娜';
    case 'henrendadi':
      return '狠人大帝';
    case 'anmiaoyi':
      return '安妙依';
    case 'jiziyue':
      return '姬紫月';
    case 'yanrudan':
      return '颜如玉';
    case 'huolinger':
      return '火灵儿';
    default:
      return '角色';
  }
}

/// 角色 id → 默认头像字
String roleLetterOf(String role) {
  final custom = _customRoleField(role, 'letter');
  if (custom.isNotEmpty) return custom;
  switch (role) {
    case 'liuziling':
      return '灵';
    case 'nvwa':
      return '娲';
    case 'houtu':
      return '后';
    case 'xiwangmu':
      return '母';
    case 'medusa':
      return '美';
    case 'yunyun':
      return '韵';
    case 'xiaoxuaner':
      return '薰';
    case 'bibidong':
      return '比';
    case 'qianrenxue':
      return '雪';
    case 'xiaowu':
      return '舞';
    case 'guyuena':
      return '娜';
    case 'henrendadi':
      return '狠';
    case 'anmiaoyi':
      return '安';
    case 'jiziyue':
      return '紫';
    case 'yanrudan':
      return '颜';
    case 'huolinger':
      return '火';
    default:
      return '角';
  }
}
