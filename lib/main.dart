// 包娜 · 手机端 App 主入口：连电脑 → 登录 → 主界面（聊天/商城/游戏/我们）
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'api.dart';
import 'brain.dart';
import 'chat.dart';
import 'chatlist.dart';
import 'eye.dart';
import 'game.dart';
import 'wishes.dart';
import 'notify.dart';
import 'pet.dart';
import 'sheets.dart';
import 'shop.dart';
import 'theme.dart';
import 'us.dart';

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
  bool chatVisible = true;     // 他现在是不是就待在聊天页（不在就攒小红点）
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
  bool eyeOn = false;          // ★她在用手机前置看你（拍的那一下，聊天里会显示"她在看你…"）
  Map<String, dynamic> herSet = {};
  Map<String, dynamic> cfg = Map<String, dynamic>.from(kDefCfg);

  String get bg => '${cfg['bg'] ?? ''}';
  // ★背景照片的透明度和模糊（老公 2026-09-29 要的：设了照片得能调透明，不然字看不清）
  double get bgOpacity => ((cfg['bgOpacity'] as num?)?.toDouble() ?? 1).clamp(0.05, 1.0);
  double get bgBlur => ((cfg['bgBlur'] as num?)?.toDouble() ?? 0).clamp(0, 24); // ★默认 0：照片先给清晰的，想要朦胧自己往上拖
  double get fontSize => (cfg['fontSize'] as num?)?.toDouble() ?? 16;
  int get bubbleMax => (cfg['bubbleMax'] as num?)?.toInt() ?? 4;
  Color get myColor => hexColor('${cfg['myColor'] ?? '#7C6BF5'}');
  Color get herColor => hexColor('${cfg['herColor'] ?? '#2A2A35'}');

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
      if (t == 'eye') {
        // ★2026-09-29 老公要的：她自己看你 —— 电脑端喊一嗓子，我们立刻用【前置】拍一张回过去。
        //   iOS 后台不给开摄像头 → 只在前台拍；不在前台就跳过，电脑端退回那两台固定摄像头。
        final life = WidgetsBinding.instance.lifecycleState;
        if (life == AppLifecycleState.resumed && !PhoneEye.busy && a != null) {
          eyeOn = true;
          notifyListeners();
          PhoneEye.shootAndSend(a, why: '${e['why'] ?? ''}').then((_) {
            eyeOn = false;
            notifyListeners();
          });
        }
      } else if (t == 'state') {
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
  int _tab = 0;
  bool _navHidden = false;
  double _lastPix = 0;
  // ★2.0 第四波：页面换成 PageView —— 手指左右滑页面跟手走（iOS 26 Liquid Glass 标签栏规范）
  final PageController _pageCtrl = PageController();
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
      if (i == 0) app.unread = 0; // 进了聊天就没有小红点了
      app.chatVisible = (i == 0);
    });
    _pageCtrl.animateToPage(i,
        duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
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
            // ★从屏幕左边缘往右滑 = 看她在桌面上什么样（老公 2026-09-29 要的）
            drawer: const PetDrawer(),
            drawerEdgeDragWidth: 32,
            drawerScrimColor: const Color(0x66000000),
            body: NotificationListener<ScrollNotification>(
              onNotification: _onScroll,
              // Scaffold(extendBody) 会往 body 里塞一份底栏高的底部 padding，各页 navSpace
              //   又自己加一层，输入框/按钮被双重抬到半空（2026-09-30 报修）。这里把 Scaffold
              //   塞的清掉，留白统一由各页 navSpace(基于 viewPadding) 自己算。
              child: MediaQuery.removePadding(
                context: context,
                removeBottom: true,
                child: Column(children: [
                  // ★26.2.23 布局整理：聊天页不再叠全局头部（它自己有"消息"大标题），
                  //   只有商城/游戏/愿望/我们才显示全局头像栏 —— 顶部不再两截、不挤
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _tab == 0
                        ? const SizedBox(key: ValueKey('nohead'))
                        : _Header(
                            key: const ValueKey('head'),
                            onSearch: () => openSearch(context),
                            onSet: () => openSettings(context),
                            onCtrl: () => openCtrl(context),
                            onUs: () => _switchTab(4)),
                  ),
                  Expanded(
                    // ★2.0 第四波：PageView 左右滑动切换 —— 页面跟手走，才是 iOS 26 的标签栏
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
                          app.chatVisible = (i == 0);
                        });
                      },
                      children: const [
                        KeepAliveWrapper(child: ChatListPage()),
                        KeepAliveWrapper(child: ShopPage()),
                        KeepAliveWrapper(child: GamePage()),
                        KeepAliveWrapper(child: WishesPage()),
                        KeepAliveWrapper(child: UsPage()),
                      ],
                    ),
                  ),
                ]),
              ),
            ),
            bottomNavigationBar: AnimatedSlide(
              offset: _navHidden ? const Offset(0, 1.3) : Offset.zero,
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              child: _Nav(
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

class _Header extends StatelessWidget {
  const _Header({required this.onSearch, required this.onSet, required this.onCtrl, required this.onUs});
  final VoidCallback onSearch, onSet, onCtrl, onUs;

  @override
  Widget build(BuildContext context) {
    final av = '${app.herSet['herAvatar'] ?? ''}';
    return GlassBar(
      top: true,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
        child: Row(children: [
          GestureDetector(
            onTap: onUs,
            child: _HeaderAvatar(av: av),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(app.nick, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              Row(children: [
                Container(width: 6, height: 6, decoration: BoxDecoration(color: app.online ? const Color(0xFF57D9A3) : kSub, shape: BoxShape.circle)),
                const SizedBox(width: 5),
                Flexible(child: Text(app.status, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: kSub))),
              ]),
            ]),
          ),
          IconButton(onPressed: onSearch, icon: const Icon(Icons.search, size: 20), tooltip: '搜聊天'),
          IconButton(onPressed: onCtrl, icon: const Icon(Icons.tune, size: 20), tooltip: '控制器'),
          IconButton(onPressed: onSet, icon: const Icon(Icons.settings_outlined, size: 20), tooltip: '设置'),
        ]),
        ),
      ),
    );
  }
}

/// ★2026-10-02 闪屏修复：左上角头像独立组件 —— 同 URL 复用缓存 provider + gaplessPlayback，
///   切页/全局 rebuild 时保留上一帧，不闪回"娜"字占位
class _HeaderAvatar extends StatelessWidget {
  const _HeaderAvatar({required this.av});
  final String av;

  @override
  Widget build(BuildContext context) {
    final p = av.isEmpty ? null : avatarOf(av);
    return Container(
      width: 38,
      height: 38,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(colors: [kAccent, kAccent2]),
      ),
      child: p == null
          ? const Center(child: Text('娜', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)))
          : Image(
              image: p,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) =>
                  const Center(child: Text('娜', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
            ),
    );
  }
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
          // ★她来消息时聊天那个图标上冒个小红点
          {'off': Icons.chat_bubble_outline, 'on': Icons.chat_bubble, 't': '聊天', 'badge': unread},
          {'off': Icons.shopping_bag_outlined, 'on': Icons.shopping_bag, 't': '商城'},
          {'off': Icons.casino_outlined, 'on': Icons.casino, 't': '游戏'},
          {'off': Icons.auto_awesome_outlined, 'on': Icons.auto_awesome, 't': '愿望'},
          {'off': Icons.favorite_border, 'on': Icons.favorite, 't': '我们'},
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
