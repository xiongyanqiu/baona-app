// 包娜 App · 抽屉：设置 / 控制器 / 搜索聊天
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'api.dart';
import 'main.dart';
import 'theme.dart';
import 'us.dart';

/* ================================ 设置 ================================ */
Future<void> openSettings(BuildContext context) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x8A000000),
    builder: (c) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      maxChildSize: 0.96,
      builder: (c, scroll) => GlassSheet(child: _Settings(scroll: scroll)),
    ),
  );
}

class _Settings extends StatefulWidget {
  const _Settings({required this.scroll});
  final ScrollController scroll;

  @override
  State<_Settings> createState() => _SettingsState();
}

class _SettingsState extends State<_Settings> {
  Map<String, dynamic> hs = {};
  bool _saving = false;
  // ★2026-09-29 加：抽屉自己顶上的提示条。以前只有 toast，而 toast 弹在抽屉【下面】被盖住，
  //   看不见 = 手机上像「点了没反应」（老公报的：设置里基本所有功能点了没反应）
  String _msg = '';
  bool _bad = false;

  @override
  void initState() {
    super.initState();
    hs = Map<String, dynamic>.from(app.herSet);
    _load();
  }

  Future<void> _load() async {
    final j = await app.brainOrApi?.herSettings();
    if (!mounted) return;
    if (j != null && j['ok'] == true && j['s'] is Map) {
      setState(() {
        hs = Map<String, dynamic>.from(j['s'] as Map);
        app.herSet = hs;
      });
    }
  }

  void _note(String t, [bool bad = false]) {
    if (!mounted) return;
    setState(() {
      _msg = t;
      _bad = bad;
    });
  }

  Future<void> _patch(Map<String, dynamic> p) async {
    setState(() {
      _saving = true;
      hs.addAll(p);
    });
    // ★2026-09-29：以前只在这页 setState，顶栏头像和聊天背景不跟着变 —— 他改完看着就像"没改上"。
    //   这里直接通知全局（app 是 ChangeNotifier，主界面挂着 AnimatedBuilder 听）
    app.herSet = Map<String, dynamic>.from(hs);
    app.notifyListeners();
    final r = await app.brainOrApi?.patchSettings(p);
    if (r == null) {
      _note('手机没连上电脑端（同一个 WiFi？桌宠开着？）', true);
    } else if (r['ok'] == true) {
      _note('存好了 ✓');
    } else {
      _note('没设上：${r['error'] ?? '电脑端没接住'}', true);
    }
    if (!mounted) return;
    setState(() => _saving = false);
  }

  Future<void> _pickAvatar(String which) async {
    final f = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 512, imageQuality: 80);
    if (f == null) return;
    final b = await f.readAsBytes();
    await _patch({which: 'data:image/jpeg;base64,${base64Encode(b)}'});
  }

  bool _b(String k, [bool d = false]) => hs[k] == true || (hs[k] == null && d);

  @override
  Widget build(BuildContext context) {
    final nick = TextEditingController(text: '${hs['nickName'] ?? '包娜'}');
    return ListView(
      controller: widget.scroll,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
      children: [
        Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: kLine, borderRadius: BorderRadius.circular(4)))),
        const SizedBox(height: 12),
        Row(children: [
          const Text('设置', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(width: 10),
          if (_saving)
            const Text('存着呢…', style: TextStyle(fontSize: 12, color: kSub))
          else if (_msg.isNotEmpty)
            Expanded(
              child: Text(_msg,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _bad ? const Color(0xFFFF9A9A) : const Color(0xFF57D9A3))),
            )
          else
            const Spacer(),
          IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, size: 20)),
        ]),

        const SizedBox(height: 10),
        const _Probe(),

        const Sec('她的脑子（模型）'),
        const _ModelBox(),
        const Padding(
          padding: EdgeInsets.only(left: 4, top: 6, bottom: 2),
          child: Text('点了立刻生效（她下一句就用新的）。「本地」那个要你先在电脑上把模型开关打开；走网络的那几个你电脑关着也能用。',
              style: TextStyle(fontSize: 11.5, color: kSub, height: 1.4)),
        ),

        const Sec('连接（在外头也能连）'),
        RowTile(
          label: '现在连的是',
          sub: '家里 ${kHosts[0]['url']!.replaceFirst('http://', '')} · 外头（蒲公英）${kHosts[1]['url']!.replaceFirst('http://', '')}',
          hair: false,
          trail: Chip2('换个地址', ico: Icons.wifi_tethering, on: () {
            final nav = Navigator.of(context);
            nav.pop();
            nav.pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => ConnectPage(host: Store.baseUrl.isEmpty ? kHosts[0]['url']! : Store.baseUrl)),
              (r) => false,
            );
          }),
        ),

        const Sec('她叫什么（你看到她叫这个）'),
        Row(children: [
          Expanded(child: TextField(controller: nick, decoration: const InputDecoration(hintText: '包娜'))),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () async {
              final v = nick.text.trim();
              if (v.isEmpty) return;
              await _patch({'nickName': v});
              if (hs['nickName'] == v) {
                app.nick = v; // ★2026-09-29 改名立刻在这 App 里生效（以前改完这页一点动静都没有）
                app.notifyListeners();
                _note('以后她就叫「$v」✓');
              }
            },
            child: const Text('存'),
          ),
        ]),

        const Sec('头像'),
        Row(children: [
          _AvBox(title: '我的', data: '${hs['myAvatar'] ?? ''}', onTap: () => _pickAvatar('myAvatar')),
          const SizedBox(width: 12),
          _AvBox(title: '她的', data: '${hs['herAvatar'] ?? ''}', onTap: () => _pickAvatar('herAvatar')),
        ]),

        const Sec('她的外观（穿什么）'),
        RowTile(
          label: '穿不穿',
          sub: '你在这儿改，她桌面上跟着换',
          hair: false,
          trail: SegCtl(
            options: const [
              {'v': 'default', 't': '白T'},
              {'v': 'hoodie', 't': '卫衣'},
              {'v': 'dress', 't': '裙子'},
              {'v': 'nude', 't': '裸着'},
            ],
            value: '${hs['outfit'] ?? 'default'}',
            onPick: (v) => _patch({'outfit': v}),
          ),
        ),

        const Sec('气泡颜色'),
        const Padding(padding: EdgeInsets.only(left: 2, bottom: 6), child: Text('我的话', style: TextStyle(fontSize: 12, color: kSub))),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final c in ['#7C6BF5', '#F55B8C', '#4CC9F0', '#FFB86B', '#57D9A3', '#B98CFF'])
            GestureDetector(
              onTap: () {
                app.put('myColor', c);
                setState(() {});
              },
              child: Container(width: 30, height: 30, decoration: BoxDecoration(color: hexColor(c), shape: BoxShape.circle, border: Border.all(color: app.myColor == hexColor(c) ? Colors.white : kLine, width: 2))),
            ),
        ]),
        const SizedBox(height: 12),
        const Padding(padding: EdgeInsets.only(left: 2, bottom: 6), child: Text('她的话', style: TextStyle(fontSize: 12, color: kSub))),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final c in ['#2A2A35', '#4A2E52', '#2E4A52', '#52362E', '#3B4A36', '#3A3550'])
            GestureDetector(
              onTap: () {
                app.put('herColor', c);
                setState(() {});
              },
              child: Container(width: 30, height: 30, decoration: BoxDecoration(color: hexColor(c), shape: BoxShape.circle, border: Border.all(color: app.herColor == hexColor(c) ? Colors.white : kLine, width: 2))),
            ),
        ]),

        Sec('聊天背景'),
        Row(children: [
          Chip2('默认深色', on2: app.bg.isEmpty, on: () { app.put('bg', ''); setState(() {}); }),
          const SizedBox(width: 8),
          Chip2('从相册选一张', on: () async {
            final url = await pickAlbumImage(context);
            if (url.isNotEmpty) {
              app.put('bg', url);
              setState(() {});
              _note('背景换好了 ✓ 下面能调透明度和模糊');
            } else {
              _note('没选到照片（相册要能打开才行）', true);
            }
          }),
          const SizedBox(width: 8),
          if (app.bg.isNotEmpty) Chip2('清掉', ico: Icons.close, on: () { app.put('bg', ''); setState(() {}); }),
        ]),
        // ★2026-09-29 老公要的：设了照片之后能调透明度和模糊（默认照片 100% + 模糊 8）
        if (app.bg.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('照片透明度 ${(app.bgOpacity * 100).round()}%', style: const TextStyle(fontSize: 12, color: kSub)),
          Slider(
            value: app.bgOpacity,
            min: 0.05,
            max: 1,
            divisions: 19,
            activeColor: kAccent,
            onChanged: (v) { app.cfg['bgOpacity'] = v; app.save(); setState(() {}); },
          ),
          Text('模糊度 ${app.bgBlur.round()}', style: const TextStyle(fontSize: 12, color: kSub)),
          Slider(
            value: app.bgBlur,
            min: 0,
            max: 24,
            divisions: 24,
            activeColor: kAccent,
            onChanged: (v) { app.cfg['bgBlur'] = v; app.save(); setState(() {}); },
          ),
        ],

        Sec('字号 ${app.fontSize.toStringAsFixed(0)}'),
        Slider(
          value: app.fontSize,
          min: 13,
          max: 22,
          divisions: 9,
          activeColor: kAccent,
          onChanged: (v) {
            app.cfg['fontSize'] = v;
            setState(() {});
          },
          onChangeEnd: (_) => app.save(),
        ),

        const Sec('聊天显示'),
        SwitchRow('显示时间戳（每条消息几点）', app.cfg['showTime'] == true, (v) { app.put('showTime', v); setState(() {}); }),
        SwitchRow('提示音', app.cfg['sound'] != false, (v) { app.put('sound', v); setState(() {}); }),
        SwitchRow('震动', app.cfg['vibrate'] != false, (v) { app.put('vibrate', v); setState(() {}); }),
        SwitchRow('通知（她发消息弹出来）', app.cfg['notify'] != false, (v) { app.put('notify', v); setState(() {}); }),
        SwitchRow('你说话时她自动看一眼', app.cfg['liveWatch'] == true, (v) { app.put('liveWatch', v); setState(() {}); }, sub: '每轮都看一眼更真，但费点算力'),

        const Sec('语音'),
        SwitchRow('语音模式（她的话能直接念出来）', _b('voiceMode'), (v) => _patch({'voiceMode': v}),
            sub: '开着：她按口语写（带喘声、拖音、语气词），手机上能收到语音条；关掉：恢复普通文字'),
        SwitchRow('让她发语音条', app.voiceEnabled, (v) async {
          final r = await app.api?.voiceOn(v);
          if (!mounted) return;
          if (r != null && r['ok'] == true) {
            setState(() {
              app.voiceEnabled = r['enabled'] == true;
            });
            toast(context, v ? '她会发语音条了' : '她只打字了');
          } else {
            toast(context, '没设上');
          }
        }),

        const Sec('她主动找你'),
        SwitchRow('允许她主动发消息', _b('autoChatEnabled'), (v) => _patch({'autoChatEnabled': v})),
        SwitchRow('用你们的长记忆', _b('useMemories', true), (v) => _patch({'useMemories': v})),
        SwitchRow('她会发表情', _b('emoteEnabled', true), (v) => _patch({'emoteEnabled': v})),
        const Sec('作息（她这个点会犯困）'),
        Row(children: [
          Expanded(child: _SmallField(label: '睡', value: '${hs['sleepStart'] ?? '23:30'}', onDone: (v) => _patch({'sleepStart': v}))),
          const SizedBox(width: 10),
          Expanded(child: _SmallField(label: '醒', value: '${hs['sleepEnd'] ?? '07:30'}', onDone: (v) => _patch({'sleepEnd': v}))),
        ]),

        const Sec('她会做的动作'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final a in [
            ['actPetHead', '摸头'],
            ['actTickle', '挠痒'],
            ['actWave', '招手'],
            ['actEat', '吃东西'],
            ['actSleep', '睡觉'],
            ['actSit', '坐下'],
            ['actDance', '跳舞'],
            ['actStretch', '伸懒腰'],
            ['actHappy', '开心'],
            ['actWalk', '走动'],
          ])
            Chip2('${a[1]}', on2: _b(a[0], true), on: () => _patch({a[0]: !_b(a[0], true)})),
        ]),

        const Sec('她的人设（她的脑子）'),
        _PersonaBox(init: '${hs['persona'] ?? ''}', onSave: (v) => _patch({'persona': v})),

        const Sec('她的展示（她在桌面上什么样）'),
        RowTile(
          label: '看她在电脑桌面上的样子',
          sub: '聊天页：手指从屏幕【左边缘往右滑】就出来了（实时画面，点一下能摸她）',
          hair: false,
          trail: Chip2('看一眼', ico: Icons.visibility_outlined, on: () {
            Navigator.pop(context);
            homeKey.currentState?.openDrawer();
          }),
        ),

        const Sec('记忆与数据'),
        Row(children: [
          Chip2('她的长期记忆', ico: Icons.psychology_outlined, on: () => openMemories(context)),
          const SizedBox(width: 8),
          Chip2('她的本事（技能）', ico: Icons.auto_awesome, on: () => openSkills(context)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Chip2('清空聊天记录', ico: Icons.delete_outline, on: () async {
            final ok = await _confirm(context, '清空你们俩的全部聊天记录？电脑那边也清');
            if (ok) {
              await app.brainOrApi?.clearChat();
              if (mounted) toast(context, '清空了');
            }
          }),
          const SizedBox(width: 8),
          Chip2('改手机端口令', ico: Icons.lock_outline, on: () async {
            final np = await _ask(context, '新口令（至少 4 位）', '');
            if (np.length < 4) return;
            final r = await app.api?.setPassword(np);
            if (mounted) toast(context, r?['ok'] == true ? '改好了，要用新口令重新登录' : '${r?['error'] ?? '没改成'}');
          }),
        ]),
        const SizedBox(height: 10),
        Chip2('退出登录', ico: Icons.logout, on: () async {
          await Store.wipe();
          app.api?.dispose();
          if (mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => ConnectPage(host: Store.baseUrl.isEmpty ? kHosts[0]['url']! : Store.baseUrl)),
              (r) => false,
            );
          }
        }),
        const SizedBox(height: 20),
        Center(child: Text('包娜 App v$kAppVer · Liquid Glass 版', style: const TextStyle(fontSize: 11.5, color: kSub))),
      ],
    );
  }
}

/// ★2026-09-29 加：她的人设编辑框（电脑端网页有、手机端以前没有）
class _PersonaBox extends StatefulWidget {
  const _PersonaBox({required this.init, required this.onSave});
  final String init;
  final ValueChanged<String> onSave;

  @override
  State<_PersonaBox> createState() => _PersonaBoxState();
}

class _PersonaBoxState extends State<_PersonaBox> {
  late final TextEditingController c = TextEditingController(text: widget.init);

  @override
  void didUpdateWidget(covariant _PersonaBox old) {
    super.didUpdateWidget(old);
    // 从电脑端拉回来的人设（第一次打开时是空的）
    if (widget.init.isNotEmpty && c.text.isEmpty) c.text = widget.init;
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        GlassSurface(
          radius: kRCard,
          blur: 12,
          pad: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: TextField(
            controller: c,
            maxLines: 8,
            minLines: 6,
            maxLength: 40000,
            style: const TextStyle(fontSize: 13.5, height: 1.5),
            decoration: const InputDecoration(
              hintText: '她是谁、什么性格、怎么说话…',
              counterText: '',
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: Chip2('保存人设', ico: Icons.check, on2: true, on: () => widget.onSave(c.text)),
          ),
        ]),
      ]);
}

/// ★2026-09-29：她的脑子（模型）——手机端直接看她现在用哪个、想换就换
class _ModelBox extends StatefulWidget {
  const _ModelBox();

  @override
  State<_ModelBox> createState() => _ModelBoxState();
}

class _ModelBoxState extends State<_ModelBox> {
  List<Map<String, dynamic>> ps = [];
  String active = '';
  bool busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final dynamic a = app.brainOrApi;
    if (a == null) return;
    final j = await a.llm();
    if (!mounted) return;
    if (j['ok'] == true) {
      setState(() {
        active = '${j['activeId'] ?? ''}';
        ps = ((j['providers'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      });
    }
  }

  Future<void> _use(String id) async {
    final dynamic a = app.brainOrApi;
    if (a == null) return;
    if (id == active) return;
    setState(() => busy = true);
    final r = await a.llmUse(id);
    if (!mounted) return;
    setState(() {
      busy = false;
      if (r['ok'] == true) active = id;
    });
    toast(context, r['ok'] == true ? '换好了：${r['name'] ?? id}' : '${r['error'] ?? '没换成'}');
  }

  /// ★26.2.17 全本地化：模型配置开放给你 —— 自己加/改/删模型（API 地址/Key/模型名），不用再等我改代码
  Future<void> _edit() async {
    // 编辑副本，保存时一次性写回
    final draft = ps.map((e) => {
          'id': '${e['id']}',
          'name': '${e['name'] ?? ''}',
          'baseUrl': '${e['baseUrl'] ?? ''}',
          'model': '${e['model'] ?? ''}',
          'apiKey': '${e['apiKey'] ?? ''}',
        }).toList();
    final nameCtl = <String, TextEditingController>{};
    final baseCtl = <String, TextEditingController>{};
    final modelCtl = <String, TextEditingController>{};
    final keyCtl = <String, TextEditingController>{};
    final newName = TextEditingController();
    final newBase = TextEditingController();
    final newModel = TextEditingController();
    final newKey = TextEditingController();
    String curActive = active;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1D1D23),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (c) => StatefulBuilder(
        builder: (c, setSheet) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('模型配置', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                const Text('API 地址 / Key / 模型名 自己填；点名字切换当前用的模型', style: TextStyle(fontSize: 12, color: kSub)),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final p in draft)
                        Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: curActive == '${p['id']}' ? const Color(0x147B2FFF) : kGlass,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: curActive == '${p['id']}' ? const Color(0xFF7B2FFF) : kLine),
                          ),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Expanded(
                                child: TextField(
                                  controller: (nameCtl['${p['id']}'] ??= TextEditingController(text: '${p['name']}')),
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                  decoration: const InputDecoration(isDense: true, hintText: '名字（比如：DeepSeek 官方）', border: InputBorder.none),
                                ),
                              ),
                              if (curActive == '${p['id']}')
                                const Chip2('在用', on2: true)
                              else
                                InkWell(
                                  onTap: () => setSheet(() => curActive = '${p['id']}'),
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    child: Text('设为当前', style: TextStyle(fontSize: 12, color: Color(0xFF7B2FFF))),
                                  ),
                                ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                onPressed: () => setSheet(() => draft.removeWhere((x) => x['id'] == p['id'])),
                                icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFFF9A9A)),
                              ),
                            ]),
                            TextField(
                              controller: (baseCtl['${p['id']}'] ??= TextEditingController(text: '${p['baseUrl']}')),
                              style: const TextStyle(fontSize: 12.5),
                              decoration: const InputDecoration(isDense: true, labelText: 'API 地址', hintText: 'https://api.deepseek.com/v1', border: InputBorder.none),
                            ),
                            TextField(
                              controller: (modelCtl['${p['id']}'] ??= TextEditingController(text: '${p['model']}')),
                              style: const TextStyle(fontSize: 12.5),
                              decoration: const InputDecoration(isDense: true, labelText: '模型名', hintText: 'deepseek-chat', border: InputBorder.none),
                            ),
                            TextField(
                              controller: (keyCtl['${p['id']}'] ??= TextEditingController(text: '${p['apiKey']}')),
                              obscureText: true,
                              style: const TextStyle(fontSize: 12.5),
                              decoration: const InputDecoration(isDense: true, labelText: 'API Key', border: InputBorder.none),
                            ),
                          ]),
                        ),
                      // 新增一个
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: kGlass, borderRadius: BorderRadius.circular(14), border: Border.all(color: kLine, style: BorderStyle.solid)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('＋ 新模型', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                          TextField(controller: newName, style: const TextStyle(fontSize: 12.5), decoration: const InputDecoration(isDense: true, labelText: '名字', border: InputBorder.none)),
                          TextField(controller: newBase, style: const TextStyle(fontSize: 12.5), decoration: const InputDecoration(isDense: true, labelText: 'API 地址', hintText: 'https://api.deepseek.com/v1', border: InputBorder.none)),
                          TextField(controller: newModel, style: const TextStyle(fontSize: 12.5), decoration: const InputDecoration(isDense: true, labelText: '模型名', hintText: 'deepseek-chat', border: InputBorder.none)),
                          TextField(controller: newKey, obscureText: true, style: const TextStyle(fontSize: 12.5), decoration: const InputDecoration(isDense: true, labelText: 'API Key', border: InputBorder.none)),
                          const SizedBox(height: 4),
                          Chip2('添加', on2: true, on: () => setSheet(() {
                            final nb = newBase.text.trim();
                            final nm = newModel.text.trim();
                            final nk = newKey.text.trim();
                            if (nb.isEmpty || nm.isEmpty || nk.isEmpty) return;
                            final id = 'p${DateTime.now().millisecondsSinceEpoch}';
                            draft.add({'id': id, 'name': newName.text.trim().isEmpty ? nm : newName.text.trim(), 'baseUrl': nb, 'model': nm, 'apiKey': nk});
                            curActive = id;
                            newName.clear();
                            newBase.clear();
                            newModel.clear();
                            newKey.clear();
                          })),
                        ]),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(c, false), child: const Text('取消'))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('保存'),
                    ),
                  ),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
    if (ok != true || !mounted) return;
    // 把编辑内容写回
    final finalList = draft.map((p) {
      final id = '${p['id']}';
      return <String, dynamic>{
        'id': id,
        'name': (nameCtl[id]?.text ?? '').trim().isNotEmpty ? (nameCtl[id]?.text ?? '').trim() : '${p['name']}',
        'baseUrl': (baseCtl[id]?.text ?? '').trim().isNotEmpty ? (baseCtl[id]?.text ?? '').trim() : '${p['baseUrl']}',
        'model': (modelCtl[id]?.text ?? '').trim().isNotEmpty ? (modelCtl[id]?.text ?? '').trim() : '${p['model']}',
        'apiKey': (keyCtl[id]?.text ?? '').trim().isNotEmpty ? (keyCtl[id]?.text ?? '').trim() : '${p['apiKey']}',
      };
    }).toList();
    if (finalList.isEmpty) {
      toast(context, '至少留一个模型');
      return;
    }
    final dynamic a = app.brainOrApi;
    if (a == null) return;
    setState(() => busy = true);
    final r = await a.llmSave(finalList, curActive);
    setState(() => busy = false);
    if (r['ok'] == true) {
      toast(context, '模型配置已保存 ✓');
      await _load();
    } else {
      toast(context, '保存失败：${r['error'] ?? ''}');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (ps.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          const Expanded(child: Text('还没有模型，点右边添加', style: TextStyle(fontSize: 12, color: kSub))),
          Chip2('添加模型', ico: Icons.settings, on: busy ? null : _edit),
        ]),
      );
    }
    return Column(children: [
      for (final p in ps)
        PressScale(
          onTap: busy ? null : () => _use('${p['id']}'),
          radius: kRCard,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(children: [
              Icon('${p['id']}' == active ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  size: 18, color: '${p['id']}' == active ? kAccent2 : kSub),
              const SizedBox(width: 10),
              Expanded(
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${p['name']}', style: const TextStyle(fontSize: 14)),
                  Text('模型 ${p['model']}${p['local'] == true ? ' · 跑在你电脑上' : ' · 走网络'}',
                      style: const TextStyle(fontSize: 11, color: kSub)),
                ]),
              ),
              if ('${p['id']}' == active)
                const Text('在用', style: TextStyle(fontSize: 11.5, color: kOk, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      const SizedBox(height: 8),
      // ★26.2.17：编辑/新增/删除模型 —— 全部自己配，不用再等我
      Align(
        alignment: Alignment.centerLeft,
        child: Chip2('＋ 编辑模型配置', ico: Icons.tune, on: busy ? null : _edit),
      ),
    ]);
  }
}

class _AvBox extends StatelessWidget {
  const _AvBox({required this.title, required this.data, required this.onTap});
  final String title, data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Column(children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: kGlass,
              border: Border.all(color: kLine),
              image: avatarOf(data) == null ? null : DecorationImage(image: avatarOf(data)!, fit: BoxFit.cover),
            ),
            child: data.isEmpty ? const Icon(Icons.add_a_photo_outlined, size: 20) : null,
          ),
          const SizedBox(height: 5),
          Text(title, style: const TextStyle(fontSize: 11.5, color: kSub)),
        ]),
      );
}

class _SmallField extends StatefulWidget {
  const _SmallField({required this.label, required this.value, required this.onDone});
  final String label, value;
  final ValueChanged<String> onDone;

  @override
  State<_SmallField> createState() => _SmallFieldState();
}

class _SmallFieldState extends State<_SmallField> {
  late final TextEditingController c = TextEditingController(text: widget.value);
  @override
  void dispose() { c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => TextField(
        controller: c,
        decoration: InputDecoration(hintText: widget.label),
        onSubmitted: widget.onDone,
        onTapOutside: (_) => widget.onDone(c.text.trim()),
      );
}

Future<bool> _confirm(BuildContext c, String text) async =>
    (await showDialog<bool>(context: c, builder: (x) => AlertDialog(content: Text(text), actions: [
      TextButton(onPressed: () => Navigator.pop(x, false), child: const Text('算了')),
      FilledButton(onPressed: () => Navigator.pop(x, true), child: const Text('确定')),
    ]))) == true;

Future<String> _ask(BuildContext c, String title, String init) async {
  final t = TextEditingController(text: init);
  final r = await showDialog<String>(
    context: c,
    builder: (x) => AlertDialog(title: Text(title), content: TextField(controller: t, autofocus: true), actions: [
      TextButton(onPressed: () => Navigator.pop(x, ''), child: const Text('算了')),
      FilledButton(onPressed: () => Navigator.pop(x, t.text.trim()), child: const Text('好')),
    ]),
  );
  return r ?? '';
}

/* =============================== 控制器 =============================== */
Future<void> openCtrl(BuildContext context) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x8A000000),
    builder: (c) => DraggableScrollableSheet(expand: false, initialChildSize: 0.9, maxChildSize: 0.96, builder: (c, s) => GlassSheet(child: _Ctrl(scroll: s))),
  );
}

class _Ctrl extends StatefulWidget {
  const _Ctrl({required this.scroll});
  final ScrollController scroll;

  @override
  State<_Ctrl> createState() => _CtrlState();
}

class _CtrlState extends State<_Ctrl> {
  Map<String, dynamic> ct = {};
  String cat = 'normal';
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _load();
    _t = Timer.periodic(const Duration(seconds: 6), (_) => _load());
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    // ★26.2.26 全本地模式走本地大脑的简化控制器；连电脑模式走桌宠 ctrl API
    final dynamic a = app.brainOrApi;
    final j = a == null ? null : await a.ctrl();
    if (!mounted) return;
    if (j != null && j['ctrl'] is Map) setState(() => ct = Map<String, dynamic>.from(j['ctrl'] as Map));
  }

  Future<void> _cmd(String cmd, [dynamic val]) async {
    final dynamic a = app.brainOrApi;
    final r = a == null ? null : await a.ctrlCmd(cmd, val);
    if (!mounted) return;
    if (r != null && r['ctrl'] is Map) setState(() => ct = Map<String, dynamic>.from(r['ctrl'] as Map));
  }

  @override
  Widget build(BuildContext context) {
    final arousal = (ct['arousal'] as num?)?.toInt() ?? 0;
    final tier = '${ct['tier'] ?? 'idle'}';
    final book = (ct['playbook'] as Map?) ?? {};
    final finishOpts = ((ct['finishOpts'] as List?) ?? []).map((e) => '$e').toList();
    final plays = ((book.entries).where((e) => '${(e.value as Map)['cat']}' == cat)).toList();

    return ListView(
      controller: widget.scroll,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
      children: [
        Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: kLine, borderRadius: BorderRadius.circular(4)))),
        Row(children: [
          const Text('控制器', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(width: 10),
          Text('$tier · 兴奋度 $arousal', style: const TextStyle(fontSize: 12.5, color: kAccent2)),
          const Spacer(),
          IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, size: 20)),
        ]),
        const Sec('她的兴奋度'),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(value: (arousal.clamp(0, 100)) / 100, minHeight: 12, backgroundColor: kGlass, color: kAccent2),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          Chip2('轻碰一下', ico: Icons.touch_app_outlined, on: () => _cmd('tap')),
          Chip2('兴奋 +10', on: () => _cmd('arousalAdd', 10)),
          Chip2('兴奋 −10', on: () => _cmd('arousalAdd', -10)),
          Chip2('清零', on: () => _cmd('arousalReset')),
        ]),
        const Sec('强度 / 节奏 / 模式'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final v in [0, 1, 2, 3, 4, 5])
            Chip2('档 $v', on2: ((ct['level'] as num?)?.toInt() ?? 0) == v, on: () => _cmd('level', v)),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final v in ['slow', 'fast', 'wave', 'pulse'])
            Chip2(v == 'slow' ? '慢' : (v == 'fast' ? '快' : (v == 'wave' ? '波浪' : '脉冲')), on2: '${ct['pattern']}' == v, on: () => _cmd('pattern', v)),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final v in ['idle', 'auto', 'manual', 'edge'])
            Chip2(v == 'idle' ? '待机' : (v == 'auto' ? '自动' : (v == 'manual' ? '手动' : '边缘')), on2: '${ct['mode']}' == v, on: () => _cmd('mode', v)),
        ]),
        if (finishOpts.isNotEmpty) ...[
          const Sec('结束方式'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final f in finishOpts) Chip2(f, on2: '${ct['finish']}' == f, on: () => _cmd('finish', f)),
          ]),
        ],
        const Sec('你完事了'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final v in ['none', 'inside', 'outside', 'mouth', 'face'])
            Chip2(v == 'none' ? '还没有' : (v == 'inside' ? '体内' : (v == 'outside' ? '体外' : (v == 'mouth' ? '嘴里' : '脸上'))), on2: '${ct['heDone']}' == v, on: () => _cmd('heDone', v)),
        ]),
        const Sec('亲密互动'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final c in [['normal', '日常'], ['adult', '床上'], ['devil', '狠一点'], ['self', '她自己']])
            Chip2('${c[1]}', on2: cat == c[0], on: () => setState(() => cat = c[0])),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final e in plays)
            Chip2('${(e.value as Map)['label'] ?? e.key}', on2: '${ct['play']}' == e.key, on: () => _cmd('play', e.key)),
        ]),
        if ('${ct['play']}' != 'null' && book['${ct['play']}'] is Map) ...[
          const Sec('这一招怎么来'),
          for (final p in (((book['${ct['play']}'] as Map)['params'] as List?) ?? []))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${(p as List)[0]}', style: const TextStyle(fontSize: 12, color: kSub)),
                const SizedBox(height: 5),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final o in (p[1] as List))
                    Chip2('$o', on2: '${((ct['params'] as Map?)?['${ct['play']}'] as Map?)?[p[0]]}' == '$o', on: () => _cmd('param', {'play': '${ct['play']}', 'key': '${p[0]}', 'val': '$o'})),
                ]),
              ]),
            ),
        ],
        const Sec('她的动作开关'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          Chip2('全都在动', on2: ct['movingAll'] == true, on: () => _cmd('movingAll', true)),
          Chip2('让她停下来', on2: ct['movingAll'] == false, on: () => _cmd('movingAll', false)),
        ]),
        const Sec('记录'),
        Text('高潮过 ${ct['edgeCount'] ?? 0} 次 · 今天这段 ${ct['sessEdge'] ?? 0} 次 · 羁绊 ${ct['bond'] ?? 0}',
            style: const TextStyle(fontSize: 12.5, color: kSub)),
      ],
    );
  }
}

/* ================================ 搜索 ================================ */
/// ★2026-09-30 v3：不玩 showModalBottomSheet 了 —— 键盘弹起时 sheet 被整体顶到屏幕顶，
///   内容安全区在 sheet 里不可靠。改成正常路由 + 显式 Positioned 定位，
///   顶部永远从状态栏下方开始、底部停在键盘上方，布局 100% 可控。
Future<void> openSearch(BuildContext context) async {
  await Navigator.of(context).push(PageRouteBuilder(
    transitionDuration: const Duration(milliseconds: 260),
    reverseTransitionDuration: const Duration(milliseconds: 200),
    opaque: false,
    pageBuilder: (_, __, ___) => const _Search(),
    transitionsBuilder: (_, a, __, child) =>
        FadeTransition(opacity: a, child: child),
  ));
}

class _Search extends StatefulWidget {
  const _Search();
  @override
  State<_Search> createState() => _SearchState();
}

class _SearchState extends State<_Search> {
  List<Msg> _all = [];
  String q = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final j = await app.api?.history(limit: 500);
    if (!mounted) return;
    setState(() {
      _all = ((j?['messages'] as List?) ?? []).map((e) => Msg.fromJson(Map.from(e))).toList();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ql = q.trim().toLowerCase();
    final hits = ql.isEmpty ? <Msg>[] : _all.where((m) => m.content.toLowerCase().contains(ql)).toList().reversed.take(60).toList();
    // ★2026-09-30 v3：全屏路由 + 显式定位 —— 玻璃面板 top=状态栏下方，height 算好，
    //   键盘弹起时底部正好停在键盘上方，不再被 bottom sheet 顶飞
    final mq = MediaQuery.of(context);
    final kb = mq.viewInsets.bottom;
    final topPad = mq.padding.top;
    final sheetH = kb > 0 ? (mq.size.height - topPad - kb - 8) : mq.size.height * 0.8;
    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false, // 我们显式控制键盘，不用 Scaffold 自动缩
      body: Stack(children: [
        // 上半遮罩（点它关）
        Positioned.fill(
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const ColoredBox(color: Color(0x8A000000)),
          ),
        ),
        // 玻璃面板：顶部从状态栏下方开始，键盘弹起时底部停在键盘上方
        Positioned(
          top: topPad,
          left: 0,
          right: 0,
          height: sheetH,
          child: GlassSheet(
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 10, 6),
                child: Row(children: [
                  Expanded(child: TextField(autofocus: true, onChanged: (v) => setState(() => q = v), decoration: const InputDecoration(hintText: '搜你们的聊天记录…'))),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, size: 20)),
                ]),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView(padding: const EdgeInsets.fromLTRB(14, 4, 14, 20), children: [
                        if (ql.isEmpty) const Padding(padding: EdgeInsets.only(top: 30), child: Center(child: Text('输入关键词搜聊天记录', style: TextStyle(color: kSub)))),
                        if (ql.isNotEmpty && hits.isEmpty) const Padding(padding: EdgeInsets.only(top: 30), child: Center(child: Text('没搜到～', style: TextStyle(color: kSub)))),
                        for (final m in hits) _Hit(m: m, q: q.trim()),
                      ]),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _Hit extends StatelessWidget {
  const _Hit({required this.m, required this.q});
  final Msg m;
  final String q;

  @override
  Widget build(BuildContext context) {
    final raw = m.content;
    final pos = raw.toLowerCase().indexOf(q.toLowerCase());
    Widget txt;
    if (pos >= 0) {
      txt = RichText(
        text: TextSpan(style: const TextStyle(fontSize: 13.5, color: kText, height: 1.45), children: [
          TextSpan(text: raw.substring(0, pos)),
          TextSpan(text: raw.substring(pos, pos + q.length), style: const TextStyle(backgroundColor: Color(0x667C6BF5), fontWeight: FontWeight.w600)),
          TextSpan(text: raw.substring(pos + q.length)),
        ]),
      );
    } else {
      txt = Text(raw, style: const TextStyle(fontSize: 13.5, height: 1.45));
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(color: kGlass, borderRadius: BorderRadius.circular(12), border: Border.all(color: kLine)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${m.role == 'me' || m.role == 'user' ? '我' : app.nick} · ${fmtClock(m.time ?? 0)}', style: const TextStyle(fontSize: 11, color: kSub)),
        const SizedBox(height: 4),
        txt,
      ]),
    );
  }
}


/// ★2026-09-29 加：连接体检——手机跟电脑端到底通不通，一眼看见。
/// （老公报「点了没反应」；以后先点这个：通了=手机端问题，连不上=电脑/WiFi/桌宠问题）
class _Probe extends StatefulWidget {
  const _Probe();

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  String _r = '';
  bool _busy = false;

  Future<void> _test() async {
    setState(() {
      _busy = true;
      _r = '测着呢…';
    });
    final t = app.brain != null
        ? '本地模式：模型手机直连，不依赖电脑 ✓'
        : (await app.api?.ping() ?? '手机没连上（回登录页填电脑地址、输口令）');
    if (!mounted) return;
    setState(() {
      _busy = false;
      _r = t;
    });
  }

  @override
  Widget build(BuildContext context) {
    final on = app.online;
    return Glass(
      pad: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      radius: 12,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('跟电脑端连着吗', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Chip2('测一下', ico: Icons.wifi_tethering, on: _busy ? () {} : _test),
          const Spacer(),
          Text(on ? '在线' : '离线',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: on ? const Color(0xFF57D9A3) : const Color(0xFFFF9A9A))),
        ]),
        const SizedBox(height: 4),
        Text(_r.isEmpty ? '地址 ${app.api?.host ?? '没填'} · 她 ${app.nick} · ${app.status}' : _r,
            style: const TextStyle(fontSize: 11.5, color: kSub)),
      ]),
    );
  }
}
