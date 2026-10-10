// 包娜 · 手机端 App 主入口：连电脑 → 登录 → 主界面（聊天/商城/游戏/我们）
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'api.dart';
import 'alib.dart';
import 'brain.dart';
import 'embd.dart';
import 'home.dart';
import 'msg.dart';
import 'my.dart';
import 'notify.dart';
import 'photos.dart';
import 'theme.dart';
import 'vlib.dart';

/// 全局状态（一个 App 就一个连接、一份设置）
class AppCtl extends ChangeNotifier {
  AppCtl._();
  static final AppCtl i = AppCtl._();

  Api? api;
  LocalBrain? brain; // ★26.2.17 全本地化：本地大脑（人设/对话/记忆/愿望/角色/群聊 不依赖电脑）

  /// ★26.2.17：聊天/记忆/人设/愿望/角色/群聊统一走它 —— 有电脑用电脑，没电脑用本地大脑
  dynamic get brainOrApi => brain ?? api;
  String nick = '包娜';
  String status = '包娜在线';
  bool online = false;
  bool voiceEnabled = false;
  bool coupleEnabled = false;
  List<Map> emoji = [];
  Set<String> emojiMine = {}; // ★哪些是「我加的」（可以长按删）
  int unread = 0;              // ★她来消息时底栏聊天图标上的小红点
  bool chatVisible = false;    // 他现在是不是就待在聊天页（不在就攒小红点）★v27.0.10 启动不在对话页
  // ★2026-10-02 角色/群聊消息的会话级未读与最后一条（不进主对话红点、不弹主对话通知）
  final Map<String, int> _sideUnread = {};
  final Map<String, String> _sideLast = {};
  int sideUnreadOf(String id) => _sideUnread[id] ?? 0;
  String sideLastOf(String id) => _sideLast[id] ?? '';
  void sideBump(String id, String content, int t) {
    _sideUnread[id] = (_sideUnread[id] ?? 0) + 1;
    if (content.trim().isNotEmpty) _sideLast[id] = content;
    notifyListeners();
  }
  void sideClear(String id) {
    if ((_sideUnread[id] ?? 0) != 0) {
      _sideUnread[id] = 0;
      notifyListeners();
    }
  }
  Map<String, dynamic> herSet = {};
  Map<String, dynamic> cfg = Map<String, dynamic>.from(kDefCfg);

  String get bg => '${cfg['bg'] ?? ''}';
  // ★背景照片的透明度和模糊（老公 2026-09-29 要的：设了照片得能调透明，不然字看不清）
  double get bgOpacity => ((cfg['bgOpacity'] as num?)?.toDouble() ?? 1).clamp(0.05, 1.0);
  double get bgBlur => ((cfg['bgBlur'] as num?)?.toDouble() ?? 0).clamp(0, 24); // ★默认 0：照片先给清晰的，想要朦胧自己往上拖
  double get fontSize => (cfg['fontSize'] as num?)?.toDouble() ?? 16;
  int get bubbleMax => (cfg['bubbleMax'] as num?)?.toInt() ?? 4;
  Color get myColor => hexColor('${cfg['myColor'] ?? '#0A84FF'}'); // ★27.0 systemBlue
  Color get herColor => hexColor('${cfg['herColor'] ?? '#1C1C1E'}'); // ★27.0 secondarySystemBackground

  void save() {
    Store.setCfg(cfg);
    notifyListeners();
  }

  void put(String k, dynamic v) {
    cfg[k] = v;
    save();
  }

  /// ★电脑端有变化时会推一条 {type:'state'}（不带内容，就是"你来拿一次"）
  ///   以前直接读 e['status']/e['online'] → 永远是旧值 → 顶栏状态/在线一直不更新
  Future<void> refreshState() async {
    final a = api;
    if (a == null) return;
    final j = await a.state();
    if (j['ok'] == true) {
      nick = '${j['nick'] ?? nick}';
      status = '${j['status'] ?? status}';
      online = j['online'] == true;
      notifyListeners();
    }
  }

  Future<void> loadBootstrap() async {
    final dynamic a = app.api ?? app.brain;
    if (a == null) return;
    // ★b21 启动秒开：先把上次的缓存立刻渲染出来（名字/状态/头像/表情），网络回来再覆盖
    try {
      final raw = Store.bootCache;
      if (raw.isNotEmpty) {
        final c = jsonDecode(raw);
        if (c is Map && (c['t'] is int) && (DateTime.now().millisecondsSinceEpoch - (c['t'] as int)) < 86400000) {
          nick = '${c['nick'] ?? nick}';
          status = '${c['status'] ?? status}';
          voiceEnabled = c['voice'] == true;
          coupleEnabled = c['couple'] == true;
          if (c['set'] is Map) herSet = Map<String, dynamic>.from(c['set'] as Map);
          if (c['emoji'] is List) emoji = (c['emoji'] as List).map((x) => {'name': '$x'}).toList();
          if (c['mine'] is List) emojiMine = (c['mine'] as List).map((x) => '$x').toSet();
          notifyListeners();
        }
      }
    } catch (_) {/* 缓存坏了就正常走网络 */}
    // ★2026-09-29：以前这三件事是排队等的（bootstrap → herSettings → emoji），启动慢一截；
    //   现在一起发出去，谁先回来谁先用。
    final rs = await Future.wait<Map<String, dynamic>>([a.bootstrap(), a.herSettings(), a.emojiList()]);
    final j = rs[0];
    if (j['ok'] == true) {
      nick = '${j['nick'] ?? nick}';
      status = app.brain != null ? '包娜在线' : '${j['status'] ?? status}';
      voiceEnabled = j['voiceEnabled'] == true;
      coupleEnabled = j['coupleEnabled'] == true;
      herSet = Map<String, dynamic>.from((j['settings'] as Map?) ?? {});
      notifyListeners();
      Notify.i.ask();          // 连上了就问一次通知权限
    }
    final s = rs[1];
    if (s['ok'] == true && s['s'] is Map) {
      herSet = Map<String, dynamic>.from(s['s'] as Map);
      notifyListeners();
    }
    final e = rs[2];
    if (e['ok'] == true) {
      emoji = ((e['list'] as List?) ?? []).map((x) => {'name': '$x'}).toList();
      emojiMine = ((e['mine'] as List?) ?? []).map((x) => '$x').toSet();
      notifyListeners();
    }
    // ★b21 网络回来了 → 把最新数据存成缓存，下次启动秒开
    try {
      await Store.setBootCache(jsonEncode({
        't': DateTime.now().millisecondsSinceEpoch,
        'nick': nick,
        'status': status,
        'voice': voiceEnabled,
        'couple': coupleEnabled,
        'set': herSet,
        'emoji': emoji.map((x) => x['name']).toList(),
        'mine': emojiMine.toList(),
      }));
    } catch (_) {/* ignore */}
  }

  /// 连上以后的统一初始化
  void attach(Api a) {
    api = a;
    a.wsOpen();
    loadBootstrap();
    _watchSrc(a.events);
  }

  /// ★全本地化：手机自己当"电脑端"（聊天/记忆/人设/模型全本地）
  void attachBrain(LocalBrain b) {
    brain = b;
    api = null;
    loadBootstrap();
    _watchSrc(b.events);
  }

  void _watchSrc(Stream<Map<String, dynamic>> ev) {
    final a = api;
    ev.listen((e) {
      final t = '${e['type']}';
      if (t == 'state') {
        refreshState(); // ★去取一次（这条事件本身不带内容）
      } else if (t == 'hello') {
        online = true;
        notifyListeners();
      } else if (t == 'msg') {
        // 她在后台的时候才弹通知（你在里面聊着就不叮了）
        // ★2026-09-29：通知一直不弹就是这个 —— 正文包在 e['msg'] 里，以前读最外层永远是空
        final raw = e['msg'];
        final body = raw is Map ? Map<String, dynamic>.from(raw) : e;
        final role = '${body['role'] ?? ''}';
        final mine = (role == 'me' || role == 'user');
        // ★2026-10-02 角色/群聊消息分流：不进主对话红点、不弹主对话通知，
        //   只更新对应会话（chatlist）的未读和最后一条 —— 之前全部当主对话消息，群聊/角色话全混进包娜主对话
        final gid = '${body['groupId'] ?? ''}';
        final rid = '${body['roleId'] ?? ''}';
        final sideId = gid.isNotEmpty ? 'group.$gid' : (rid.isNotEmpty ? rid : '');
        final sideMsg = !mine && sideId.isNotEmpty;
        if (sideMsg) {
          sideBump(sideId, '${body['content'] ?? ''}', (body['time'] as num?)?.toInt() ?? 0);
        } else {
          // ★2026-09-29：她的消息 + 他没待在聊天页 → 底栏聊天图标上冒小红点（顺手震一下）
          if (!mine && !chatVisible) {
            unread += 1;
            notifyListeners();
          }
          if (!mine) {
            try { HapticFeedback.lightImpact(); } catch (e) { /* 桌面/web 上没有，忽略 */ }
          }
          if (!mine && !Notify.i.foreground && cfg['notify'] != false) {
            final txt = '${body['content'] ?? ''}';
            if (txt.trim().isNotEmpty) {
              Notify.i.show(nick, txt, vibrate: cfg['vibrate'] != false);
            }
          }
        }
      }
    });
  }
}

final app = AppCtl.i;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Store.init();
  await Notify.i.init();
  app.cfg = Store.cfg;
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
  ));
  // ★自检用：URL 带 ?safe=34&kb=300 就能当成「iPhone 底部安全区 / 键盘弹起」来看布局
  //   （手机上不会有这两个参数 → 完全不受影响）
  final _q = Uri.base.queryParameters;
  final _safe = double.tryParse(_q['safe'] ?? '') ?? 0;
  final _kb = double.tryParse(_q['kb'] ?? '') ?? 0;
  runApp(_InsetsProbe(safe: _safe, kb: _kb, child: const BaonaApp()));
}

/// 只在自检时才包一层（把安全区/键盘高度灌进去），平时什么都不过手
class _InsetsProbe extends StatelessWidget {
  const _InsetsProbe({required this.safe, required this.kb, required this.child});

  final double safe;
  final double kb;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (safe == 0 && kb == 0) return child;
    final m = MediaQuery.of(context);
    return MediaQuery(
      data: m.copyWith(padding: m.padding.copyWith(bottom: safe), viewInsets: EdgeInsets.only(bottom: kb)),
      child: child,
    );
  }
}

class BaonaApp extends StatefulWidget {
  const BaonaApp({super.key});

  @override
  State<BaonaApp> createState() => _BaonaAppState();
}

class _BaonaAppState extends State<BaonaApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// 切后台就开始播静音保活（不然 iOS 冻住 App，她的消息就收不到了）
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    Notify.i.background(s != AppLifecycleState.resumed);
    // ★2026-10-02 修"切后台再回来就断、要手动重连"：iOS 后台挂起会杀掉 WebSocket 且冻结定时器，
    //   回前台必须主动重建连接（onDone 的延迟重连在后台不跑，所以以前回来就是断的）。
    if (s == AppLifecycleState.resumed) {
      final a = app.api;
      if (a != null) a.reconnect();
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: '包娜',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: const Boot(),
      );
}

/// 一进来：本地大脑直接可用（不依赖电脑）；有电脑地址才额外连电脑（商城/游戏/相册用）
class Boot extends StatelessWidget {
  const Boot({super.key});

  @override
  Widget build(BuildContext context) {
    final brain = LocalBrain();
    app.attachBrain(brain);
    // ★27.0.16.13 后台预热本地记忆模型（解压+建会话，不阻塞 UI；首次对话秒用）
    if (Store.embEnabled) Embd.warmup();
    // ★27.0.16.14 主动消息：开了就启动她"隔段时间主动找你"的调度
    brain.startProactiveIfEnabled();
    // 有电脑地址/令牌 → 再连电脑（娱乐功能用；聊天/记忆/人设已经走本地大脑了）
    final base = Store.baseUrl;
    if (base.isNotEmpty && Store.token.isNotEmpty) {
      try {
        final a = Api(base)..token = Store.token;
        app.attach(a);
      } catch (_) {/* 连不上电脑不影响本地聊天 */}
    }
    return const HomePage();
  }
}

/* ------------------------------ 连电脑端 ------------------------------ */
class ConnectPage extends StatefulWidget {
  const ConnectPage({super.key, required this.host});
  final String host;

  @override
  State<ConnectPage> createState() => _ConnectPageState();
}

class _ConnectPageState extends State<ConnectPage> {
  late final TextEditingController _c = TextEditingController(text: widget.host);
  String _msg = '';
  bool _busy = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _test() async {
    setState(() {
      _busy = true;
      _msg = '正在敲电脑的门…';
    });
    final a = Api(_c.text.trim());
    final m = await a.ping();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _msg = m;
    });
  }

  void _go() {
    final u = _c.text.trim();
    if (!u.startsWith('http')) {
      toast(context, '地址要 http:// 开头');
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => LoginPage(host: u)));
  }

  @override
  Widget build(BuildContext context) => Wall(
        url: '',
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(22),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Text('包娜', textAlign: TextAlign.center, style: TextStyle(fontSize: 34, fontWeight: FontWeight.w600, letterSpacing: 6)),
                  const SizedBox(height: 8),
                  const Text('她住在你电脑里 · 这个 App 是去敲她门的那双手',
                      textAlign: TextAlign.center, style: TextStyle(color: kSub, fontSize: 12.5)),
                  const SizedBox(height: 26),
                  const Text('电脑端地址', style: TextStyle(fontSize: 13, color: kSub)),
                  const SizedBox(height: 8),
                  TextField(controller: _c, keyboardType: TextInputType.url, decoration: const InputDecoration(hintText: 'http://192.168.31.120:9000')),
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, children: [
                    for (final h in kHosts) Chip2('${h['name']} · ${h['url']!.replaceFirst('http://', '')}', on: () => setState(() => _c.text = h['url']!)),
                  ]),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(child: OutlinedButton(onPressed: _busy ? null : _test, child: const Text('测试连接'))),
                    const SizedBox(width: 10),
                    Expanded(child: FilledButton(onPressed: _go, child: const Text('下一步：登录'))),
                  ]),
                  if (_msg.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 14), child: Text(_msg, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12.5, color: kAccent2))),
                  const SizedBox(height: 24),
                  const Text('在外面也能连：电脑端开着蒲公英，用上面那个蒲公英地址',
                      textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, color: kSub)),
                ]),
              ),
            ),
          ),
        ),
      );
}

/* -------------------------------- 登录 -------------------------------- */
class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.host});
  final String host;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late final TextEditingController _p = TextEditingController(text: Store.pwd);
  bool _remember = true;
  bool _busy = false;
  String _err = '';

  @override
  void dispose() {
    _p.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final pwd = _p.text;
    if (pwd.isEmpty) {
      setState(() => _err = '口令是空的');
      return;
    }
    setState(() {
      _busy = true;
      _err = '';
    });
    final a = Api(widget.host);
    final j = await a.login(pwd);
    if (!mounted) return;
    if (j['ok'] != true) {
      setState(() {
        _busy = false;
        _err = '${j['error'] ?? '登录失败'}';
      });
      return;
    }
    await Store.setBaseUrl(widget.host);
    await Store.setToken('${j['token']}');
    if (_remember) await Store.setPwd(pwd);
    app.nick = '${j['nick'] ?? '包娜'}';
    app.status = '${j['status'] ?? '在线'}';
    app.attach(a);
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const HomePage()), (r) => false);
  }

  @override
  Widget build(BuildContext context) => Wall(
        url: '',
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Icon(Icons.lock_outline, size: 40, color: kAccent2),
                  const SizedBox(height: 14),
                  Text('连上 ${widget.host.replaceFirst('http://', '')}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, color: kSub)),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _p,
                    obscureText: true,
                    onSubmitted: (_) => _login(),
                    enableSuggestions: false, // ★v27.0.13 关掉 iOS 拼写检查（双黄下划线）
                    autocorrect: false,
                    decoration: const InputDecoration(hintText: '手机端口令'),
                  ),
                  const SizedBox(height: 10),
                  CheckboxListTile(
                    value: _remember,
                    onChanged: (v) => setState(() => _remember = v ?? true),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    dense: true,
                    title: const Text('记住我（下次不用再输）', style: TextStyle(fontSize: 13.5)),
                  ),
                  if (_err.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(_err, style: const TextStyle(color: Color(0xFFFF8A8A), fontSize: 13))),
                  FilledButton(onPressed: _busy ? null : _login, child: Text(_busy ? '正在进…' : '进去')),
                  TextButton(
                    onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => ConnectPage(host: widget.host))),
                    child: const Text('换个地址'),
                  ),
                ]),
              ),
            ),
          ),
        ),
      );
}

/* ------------------------------- 主界面 ------------------------------- */
/// ★她的展示抽屉：从屏幕左边缘往右滑 / 设置里点「看一眼」都走这个
final GlobalKey<ScaffoldState> homeKey = GlobalKey<ScaffoldState>();

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // ★v27.0.13 启动先进包娜主页（tab0）；功能统一走底栏，主页只展示"她"
  int _tab = 0;
  int _photoTab = 0; // ★27.0.4 照片区内部子页（0 图库 1 相簿 2 搜索），底栏由 HomePage 统一接管
  bool _navHidden = false;
  double _lastPix = 0;
  // ★2.0 第四波：页面换成 PageView —— 手指左右滑页面跟手走（iOS 26 Liquid Glass 标签栏规范）
  final PageController _pageCtrl = PageController(initialPage: 0);
  bool _firstScroll = true; // ★切页后第一条滚动只校准位置，不误收起底栏（不然切回滚动中的页面底栏立刻消失）

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  /// 底栏点击 / 顶栏"我"：动画滑到目标页（页面滑动动画 + 底栏立即高亮）
  void _switchTab(int i) {
    if (i == _tab) return;
    setState(() {
      _tab = i;
      _navHidden = false; // ★切页先让底栏出来，他不想看时自己往上滑才收
      _firstScroll = true; // 下一条滚动只校准位置，不碰底栏
      if (i == 0) app.unread = 0; // 进了主页就没有小红点了
      app.chatVisible = false; // ★v27.0.11 对话是 push 的全屏页，tab 区都不是对话
    });
    _pageCtrl.animateToPage(i,
        duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
  }

  /// ★v27.0.15 从主页进对话：CupertinoPageRoute（iOS 右滑入 + 支持边缘侧滑返回），
  ///   在里面"返回主界面" = pop 回主页（也可边缘侧滑）；进去时置 chatVisible（来消息不攒红点）
  void _openChat() {
    HapticFeedback.selectionClick();
    app.chatVisible = true;
    Navigator.of(context)
        .push(CupertinoPageRoute(builder: (_) => const MsgPage()))
        .then((_) => app.chatVisible = false);
  }

  /// ★下滑收起底栏：**聊天页不参与**（聊天时底栏要一直钉在那儿），只有商城/游戏/我们才收
  bool _onScroll(ScrollNotification n) {
    if (_tab == 0) {
      // 回到聊天页 → 底栏一定是出来的
      if (_navHidden) setState(() => _navHidden = false);
      return false;
    }
    if (n is! ScrollUpdateNotification) return false;
    // ★PageView 横向滑动(切页)的通知不碰底栏逻辑，别把 _lastPix 污染了
    if (n.metrics.axis != Axis.vertical) return false;
    final p = n.metrics.pixels;
    // 切页后第一条纵向通知只校准位置：无论新页面滚到哪，底栏都保持呼出，等他自己滑
    if (_firstScroll) {
      _firstScroll = false;
      _lastPix = p;
      return false;
    }
    final d = p - _lastPix;
    _lastPix = p;
    if (d > 8 && p > 60 && !_navHidden) {
      setState(() => _navHidden = true);
    } else if ((d < -8 || p <= 2) && _navHidden) {
      setState(() => _navHidden = false);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: app,
        builder: (context, _) => Wall(
          url: app.bg,
          blur: app.bgBlur,
          opacity: app.bgOpacity,
          child: Scaffold(
            key: homeKey,
            backgroundColor: Colors.transparent,
            extendBody: true, // ★内容从玻璃底栏底下滚过去（玻璃才是"浮在上面"的）
            body: NotificationListener<ScrollNotification>(
              onNotification: _onScroll,
              // Scaffold(extendBody) 会往 body 里塞一份底栏高的底部 padding，各页 navSpace
              //   又自己加一层，输入框/按钮被双重抬到半空。这里把 Scaffold 塞的清掉，
              //   留白统一由各页 navSpace(基于 viewPadding) 自己算。
              child: MediaQuery.removePadding(
                context: context,
                removeBottom: true,
                child: Column(children: [
                  Expanded(
                    // ★27.0 全新版：5 区 —— 消息 / 照片 / 视频 / 音频 / 中间大按钮=我的
                    //   消息区 = 仅包娜单聊；其余 4 区先做入口占位，功能等用户想好
                    child: PageView(
                      controller: _pageCtrl,
                      physics: const BouncingScrollPhysics(),
                      onPageChanged: (i) {
                        if (i == _tab) return;
                        HapticFeedback.selectionClick(); // 翻页轻震
                        setState(() {
                          _tab = i;
                          _navHidden = false; // ★横滑切页底栏也是先出来
                          _firstScroll = true;
                          if (i == 0) app.unread = 0;
                          app.chatVisible = false; // ★v27.0.11 对话是 push 全屏页
                        });
                      },
                      children: [
                        // ★v27.0.11 启动主页面 = 包娜主页；对话从主页"聊天"卡片 push 全屏进入
                        // ★v27.0.14.5 每页包 Page3D：横滑切页 = 三维空间翻页（当前页立起、两侧转远）
                        Page3D(ctrl: _pageCtrl, index: 0, child: KeepAliveWrapper(child: BaonaHome(
                          onOpenChat: _openChat,
                          onGoTab: _switchTab,
                        ))),
                        Page3D(ctrl: _pageCtrl, index: 1, child: KeepAliveWrapper(child: PhotosPage(
                          photoTab: _photoTab,
                          onPhotoTab: (i) => setState(() => _photoTab = i),
                        ))),
                        Page3D(ctrl: _pageCtrl, index: 2, child: KeepAliveWrapper(child: VideoLibPage())),
                        Page3D(ctrl: _pageCtrl, index: 3, child: KeepAliveWrapper(child: AudioLibPage())),
                        Page3D(ctrl: _pageCtrl, index: 4, child: KeepAliveWrapper(child: MyPage())),
                      ],
                    ),
                  ),
                ]),
              ),
            ),
            bottomNavigationBar: AnimatedSlide( // ★v27.0.13 主页也有底栏（功能统一走底栏，主页不再放卡片入口）
              offset: _navHidden ? const Offset(0, 1.3) : Offset.zero,
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              // ★27.0.4：底栏只有一条 —— 在照片区时整条底栏换成照片的（返回+图库/相簿/搜索），
              //   其它区是功能区 5 项，不再出现两层底栏
              child: _tab == 1
                  ? _PhotoNav(
                      photoTab: _photoTab,
                      onTap: (i) {
                        HapticFeedback.selectionClick();
                        if (i == 0) {
                          // ★返回：退出照片区，回消息页，照片子页复位到图库
                          _switchTab(0);
                          setState(() => _photoTab = 0);
                        } else {
                          setState(() => _photoTab = i - 1);
                        }
                      },
                    )
                  : _Nav(
                      tab: _tab,
                      unread: app.unread > 0,
                      onTap: (i) {
                        HapticFeedback.selectionClick(); // ★点哪儿手感跟一下（iOS 上有效）
                        _switchTab(i);
                      },
                    ),
            ),
          ),
        ),
      );
}

class _Nav extends StatelessWidget {
  const _Nav({required this.tab, required this.onTap, this.unread = false});
  final int tab;
  final ValueChanged<int> onTap;
  final bool unread;

  @override
  Widget build(BuildContext context) => GlassNav(
        index: tab,
        onTap: onTap,
        items: [
          // ★v27.0.11 5 区：主页 / 照片 / 视频 / 音频 / 我的（启动进主页）
          // ★她来消息时主页图标上冒个小红点
          {'off': Icons.home_outlined, 'on': Icons.home, 't': '主页', 'badge': unread},
          {'off': Icons.photo_library_outlined, 'on': Icons.photo_library, 't': '照片'},
          {'off': Icons.videocam_outlined, 'on': Icons.videocam, 't': '视频'},
          {'off': Icons.audiotrack_outlined, 'on': Icons.audiotrack, 't': '音频'},
          {'off': Icons.person_outline, 'on': Icons.person, 't': '我的'},
        ],
      );
}

/// ★27.0.4 照片专用底栏：最左边返回（退出照片区回消息页），后面是图库/相簿/搜索
///   进照片区时整条底栏替换成这个，不再有两层底栏
class _PhotoNav extends StatelessWidget {
  const _PhotoNav({required this.photoTab, required this.onTap});
  final int photoTab; // 0 图库 1 相簿 2 搜索
  final ValueChanged<int> onTap; // 0=返回 1=图库 2=相簿 3=搜索

  @override
  Widget build(BuildContext context) => GlassNav(
        index: photoTab + 1,
        onTap: onTap,
        items: [
          {'off': Icons.arrow_back_ios_new, 'on': Icons.arrow_back_ios_new, 't': '返回'},
          {'off': Icons.photo_library_outlined, 'on': Icons.photo_library, 't': '图库'},
          {'off': Icons.photo_album_outlined, 'on': Icons.photo_album, 't': '相簿'},
          {'off': Icons.search, 'on': Icons.search, 't': '搜索'},
        ],
      );
}

/// ★2.0 第四波：PageView 里的页面保活（切走不销毁，回来还是原来的状态）
class KeepAliveWrapper extends StatefulWidget {
  const KeepAliveWrapper({super.key, required this.child});
  final Widget child;

  @override
  State<KeepAliveWrapper> createState() => _KeepAliveWrapperState();
}

class _KeepAliveWrapperState extends State<KeepAliveWrapper>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // ★2026-10-02 闪屏修复：RepaintBoundary 隔离每页绘制 —— 切页动画/一页刷新不会拖着别的页重绘
    return RepaintBoundary(child: widget.child);
  }
}
