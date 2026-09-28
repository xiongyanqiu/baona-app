// 包娜 · 手机端 App 主入口：连电脑 → 登录 → 主界面（聊天/商城/游戏/我们）
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'api.dart';
import 'chat.dart';
import 'game.dart';
import 'notify.dart';
import 'sheets.dart';
import 'shop.dart';
import 'theme.dart';
import 'us.dart';

/// 全局状态（一个 App 就一个连接、一份设置）
class AppCtl extends ChangeNotifier {
  AppCtl._();
  static final AppCtl i = AppCtl._();

  Api? api;
  String nick = '包娜';
  String status = '在线';
  bool online = false;
  bool voiceEnabled = false;
  bool coupleEnabled = false;
  List<Map> emoji = [];
  Map<String, dynamic> herSet = {};
  Map<String, dynamic> cfg = Map<String, dynamic>.from(kDefCfg);

  String get bg => '${cfg['bg'] ?? ''}';
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

  Future<void> loadBootstrap() async {
    final a = app.api;
    if (a == null) return;
    final j = await a.bootstrap();
    if (j['ok'] == true) {
      nick = '${j['nick'] ?? nick}';
      status = '${j['status'] ?? status}';
      voiceEnabled = j['voiceEnabled'] == true;
      coupleEnabled = j['coupleEnabled'] == true;
      herSet = Map<String, dynamic>.from((j['settings'] as Map?) ?? {});
      notifyListeners();
      Notify.i.ask();          // 连上了就问一次通知权限
    }
    final s = await a.herSettings();
    if (s['ok'] == true && s['s'] is Map) {
      herSet = Map<String, dynamic>.from(s['s'] as Map);
      notifyListeners();
    }
    final e = await a.emojiList();
    if (e['ok'] == true) {
      emoji = ((e['list'] as List?) ?? []).map((x) => {'name': '$x'}).toList();
      notifyListeners();
    }
  }

  /// 连上以后的统一初始化
  void attach(Api a) {
    api = a;
    a.wsOpen();
    loadBootstrap();
    _watch();
  }

  void _watch() {
    final a = api;
    if (a == null) return;
    a.events.listen((e) {
      final t = '${e['type']}';
      if (t == 'state') {
        status = '${e['status'] ?? status}';
        online = e['online'] == true;
        notifyListeners();
      } else if (t == 'hello') {
        online = true;
        notifyListeners();
      } else if (t == 'msg') {
        // 她在后台的时候才弹通知（你在里面聊着就不叮了）
        final role = '${e['role'] ?? ''}';
        if (role != 'me' && role != 'user' && !Notify.i.foreground && cfg['notify'] != false) {
          final txt = '${e['content'] ?? ''}';
          if (txt.trim().isNotEmpty) {
            Notify.i.show(nick, txt, vibrate: cfg['vibrate'] != false);
          }
        }
      }
    });
  }
}

final app = AppCtl.i;

void main() async {
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
  runApp(const BaonaApp());
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
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: '包娜',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: const Boot(),
      );
}

/// 一进来先看本地有没有地址/令牌
class Boot extends StatelessWidget {
  const Boot({super.key});

  @override
  Widget build(BuildContext context) {
    final base = Store.baseUrl;
    if (base.isEmpty || Store.token.isEmpty) {
      return ConnectPage(host: base.isEmpty ? kHosts[0]['url']! : base);
    }
    final a = Api(base)..token = Store.token;
    app.attach(a);
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
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: app,
        builder: (context, _) => Wall(
          url: app.bg,
          blur: 8,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: Column(children: [
              _Header(onSearch: () => openSearch(context), onSet: () => openSettings(context), onCtrl: () => openCtrl(context), onUs: () => setState(() => _tab = 3)),
              Expanded(
                child: IndexedStack(index: _tab, children: const [
                  ChatPage(),
                  ShopPage(),
                  GamePage(),
                  UsPage(),
                ]),
              ),
            ]),
            bottomNavigationBar: _Nav(tab: _tab, onTap: (i) => setState(() => _tab = i)),
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
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 8, 4),
        child: Row(children: [
          GestureDetector(
            onTap: onUs,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(colors: [kAccent, kAccent2]),
                image: av.isEmpty ? null : DecorationImage(image: NetworkImage(av), fit: BoxFit.cover),
              ),
              child: av.isEmpty ? const Center(child: Text('娜', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600))) : null,
            ),
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
    );
  }
}

class _Nav extends StatelessWidget {
  const _Nav({required this.tab, required this.onTap});
  final int tab;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    const items = [
      [Icons.chat_bubble_outline, Icons.chat_bubble, '聊天'],
      [Icons.shopping_bag_outlined, Icons.shopping_bag, '商城'],
      [Icons.casino_outlined, Icons.casino, '游戏'],
      [Icons.favorite_border, Icons.favorite, '我们'],
    ];
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xCC0B0B0F),
        border: Border(top: BorderSide(color: kLine)),
      ),
      child: SafeArea(
        top: false,
        child: Row(children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: InkWell(
                onTap: () => onTap(i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(tab == i ? items[i][1] as IconData : items[i][0] as IconData, size: 21, color: tab == i ? kAccent2 : kSub),
                    const SizedBox(height: 3),
                    Text('${items[i][2]}', style: TextStyle(fontSize: 11, color: tab == i ? kAccent2 : kSub)),
                  ]),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}
