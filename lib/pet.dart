// 包娜 App · 「她」的展示：聊天页从左边缘往右滑 → 看她
//
// ★26.2.20 全本地：手机不连电脑时，她不再是死立绘——把电脑端桌宠的动作帧
//   （3 套服装 × 7 个动作，共 217 帧 WebP）打包进 App，她会在你面前眨眼、
//   呼吸、跳舞、吃饭、睡觉，还能换衣服（白T/卫衣/碎花裙）。
//   连电脑模式保持原实时抓屏（/api/petshot）。
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'api.dart';
import 'main.dart';
import 'sheets.dart';
import 'theme.dart';

const Map<String, String> kOutfitName = {
  'default': '白T居家',
  'hoodie': '粉粉卫衣',
  'dress': '碎花裙',
  'nude': '裸着',
};

/// 电脑端桌宠复刻：动作 → 帧数（压缩打包进 assets/pet_frames/<outfit>/）
const Map<String, int> kActFrames = {
  'idle': 8, 'blink': 9, 'happy': 12, 'eat': 12, 'sleep': 12, 'dance': 16, 'sit': 10,
};

/// 动作 → 播放帧率（fps）
const Map<String, int> kActFps = {
  'idle': 7, 'blink': 8, 'happy': 11, 'eat': 11, 'sleep': 6, 'dance': 14, 'sit': 8,
};

class PetDrawer extends StatefulWidget {
  const PetDrawer({super.key});

  @override
  State<PetDrawer> createState() => _PetDrawerState();
}

class _PetDrawerState extends State<PetDrawer> {
  Timer? _t;
  Timer? _animT;
  Timer? _blinkT;
  String _img = ''; // 连电脑模式的实时画面 data:image/png;base64,...
  String _msg = ''; // 动作气泡
  bool _touch = false;

  bool get _local => app.brain != null; // ★26.2.18 全本地：不连电脑时用打包动画

  // ★26.2.20 本地动画状态
  String _act = 'idle'; // 当前动作
  int _frame = 0;       // 当前帧索引（1 起）
  String _outfit = 'default'; // default | hoodie | dress

  /// 当前动作的帧路径：assets/pet_frames/<outfit>/<act>-<NN>.webp
  String get _framePath =>
      'assets/pet_frames/$_outfit/$_act-${(_frame % kActFrames[_act]!) + 1}.webp';

  static const List<String> _localLines = [
    '她歪着头看你，眼睛弯弯的',
    '她朝你眨了眨眼',
    '她轻轻拉了拉你的衣角',
    '她凑过来闻了闻你',
    '她脸有点红，别过头去',
    '她偷偷看你，被抓包了',
    '她笑了，好看的那种',
    '她给你比了个心',
    '她伸了个懒腰，像只猫',
    '她小声说"老公回来啦"',
  ];

  @override
  void initState() {
    super.initState();
    _outfit = _validOutfit('${app.herSet['outfit'] ?? ''}');
    if (_local) {
      _play('idle');
      // idle 期间偶尔眨眼，像真人一样
      _blinkT = Timer.periodic(const Duration(milliseconds: 4200), (_) {
        if (mounted && _act == 'idle') _play('blink');
      });
    } else {
      _refresh();
      _t = Timer.periodic(const Duration(milliseconds: 1600), (_) => _refresh());
    }
  }

  @override
  void dispose() {
    _t?.cancel();
    _animT?.cancel();
    _blinkT?.cancel();
    super.dispose();
  }

  String _validOutfit(String o) => (o == 'hoodie' || o == 'dress') ? o : 'default';

  /// ★26.2.20 播放动作：切帧序列，一次性动作播完自动回 idle
  void _play(String act) {
    if (!kActFrames.containsKey(act)) act = 'idle';
    _animT?.cancel();
    setState(() {
      _act = act;
      _frame = 0;
    });
    final n = kActFrames[act]!;
    final ms = (1000 / kActFps[act]!).round();
    _animT = Timer.periodic(Duration(milliseconds: ms), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _frame++;
        if (_frame >= n) {
          if (act == 'idle' || act == 'blink') {
            _frame = 0; // idle/blink 循环
          } else {
            _act = 'idle'; // 一次性动作播完回 idle
            _frame = 0;
            t.cancel();
          }
        }
      });
    });
  }

  /// ★26.2.20 换衣服：改本地 outfit + 帧目录，她马上换装
  Future<void> _setOutfit(String o) async {
    o = _validOutfit(o);
    if (_outfit == o) return;
    setState(() {
      _outfit = o;
      _act = 'idle';
      _frame = 0;
    });
    final brain = app.brain;
    if (brain != null) {
      await brain.patchSettings({'outfit': o});
      app.herSet['outfit'] = o;
    }
    if (mounted) toast(context, '她换上了${kOutfitName[o] ?? o}');
  }

  Future<void> _refresh() async {
    if (_local) return; // 本地动画不拉实时画面
    final a = app.api;
    if (a == null) return;
    if (!mounted) return;
    final sc = Scaffold.maybeOf(context);
    if (sc != null && !sc.isDrawerOpen) return;
    final life = WidgetsBinding.instance.lifecycleState;
    if (life != null && life != AppLifecycleState.resumed) return;
    final j = await a.petShot();
    if (!mounted) return;
    final s = '${j['img'] ?? ''}';
    if (j['ok'] == true && s.startsWith('data:image')) {
      setState(() {
        _img = s;
        _msg = '';
      });
    } else if (_img.isEmpty) {
      setState(() => _msg = '她在电脑上没露面（桌宠开着吗？同一个 WiFi 吗？）');
    }
  }

  Future<void> _pet() async {
    if (_local) {
      // 摸她：随机一个可爱的动作回应
      const acts = ['happy', 'dance', 'sit', 'eat'];
      setState(() => _touch = true);
      _play(acts[DateTime.now().millisecondsSinceEpoch % acts.length]);
      await Future.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;
      setState(() => _touch = false);
      toast(context, '你摸了她一下，她害羞了');
      return;
    }
    final a = app.api;
    if (a == null) return;
    setState(() => _touch = true);
    await a.ctrlCmd('tap', true);
    await _refresh();
    if (!mounted) return;
    setState(() => _touch = false);
    toast(context, '你摸了她一下');
  }

  @override
  Widget build(BuildContext context) {
    final av = '${app.herSet['herAvatar'] ?? ''}';
    final outfit = kOutfitName['${app.herSet['outfit'] ?? ''}'] ?? kOutfitName[_outfit] ?? '白T居家';
    final w = MediaQuery.of(context).size.width * 0.84;
    return Drawer(
      width: w,
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 42, 10, 14),
        child: GlassSurface(
          radius: 28,
          blur: kBlur,
          strong: true,
          pad: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(colors: [kAccent, kAccent2]),
                  image: avatarOf(av) == null ? null : DecorationImage(image: avatarOf(av)!, fit: BoxFit.cover),
                ),
                child: av.isEmpty ? const Center(child: Text('娜', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600))) : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(app.nick, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                  Row(children: [
                    Container(width: 6, height: 6, decoration: BoxDecoration(color: app.online ? kOk : kSub, shape: BoxShape.circle)),
                    const SizedBox(width: 5),
                    Text('${app.status} · 穿着$outfit', style: const TextStyle(fontSize: 11.5, color: kSub)),
                  ]),
                ]),
              ),
              PressScale(
                onTap: () => Navigator.of(context).pop(),
                radius: kRCapsule,
                child: const SizedBox(width: 34, height: 34, child: Center(child: Icon(Icons.close, size: 19))),
              ),
            ]),

            // ★26.2.20 她动给你看：本地动画 / 连电脑实时画面
            const Sec(_local ? '她在你面前（会动的）' : '她在桌面上（实时）'),
            Expanded(
              child: PressScale(
                onTap: _pet,
                radius: kRCard,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(kRCard),
                    gradient: const RadialGradient(colors: [Color(0x24FFFFFF), Color(0x00FFFFFF)], radius: 0.9),
                    border: Border.all(color: kHair),
                  ),
                  child: _local
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(kRCard - 1),
                          child: Image.asset(
                            _framePath,
                            fit: BoxFit.contain,
                            gaplessPlayback: true,
                            errorBuilder: (_, __, ___) => const Center(child: Text('她走神了…', style: TextStyle(fontSize: 12, color: kSub))),
                          ),
                        )
                      : _img.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(18),
                                child: Text(_msg.isEmpty ? '正在看她在干嘛…' : _msg,
                                    textAlign: TextAlign.center, style: const TextStyle(fontSize: 12.5, color: kSub)),
                              ),
                            )
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(kRCard - 1),
                              child: Image.memory(
                                dataUriBytes(_img),
                                fit: BoxFit.contain,
                                gaplessPlayback: true,
                                errorBuilder: (_, __, ___) => const Center(child: Text('画面没出来', style: TextStyle(fontSize: 12, color: kSub))),
                              ),
                            ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.touch_app_outlined, size: 15, color: kSub),
              const SizedBox(width: 6),
              Expanded(child: Text(_local ? (_touch ? '摸着呢…' : '点一下她 = 摸摸她 · 她会动给你看') : (_touch ? '摸着呢…' : '点一下画面 = 摸摸她 · 每 2 秒自动刷新'), style: const TextStyle(fontSize: 11.5, color: kSub))),
            ]),
            const SizedBox(height: 10),

            // ★26.2.20 动作按钮（本地）：跳舞 / 吃饭 / 睡觉 / 坐下
            if (_local) ...[
              Row(children: [
                Expanded(child: Chip2('摸她', ico: Icons.favorite_outline, on: _pet)),
                const SizedBox(width: 8),
                Expanded(child: Chip2('跳舞', ico: Icons.music_note_outlined, on: () => _play('dance'))),
                const SizedBox(width: 8),
                Expanded(child: Chip2('吃饭', ico: Icons.restaurant_outlined, on: () => _play('eat'))),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: Chip2('睡觉', ico: Icons.bedtime_outlined, on: () => _play('sleep'))),
                const SizedBox(width: 8),
                Expanded(child: Chip2('坐下', ico: Icons.airline_seat_recline_extra_outlined, on: () => _play('sit'))),
                const SizedBox(width: 8),
                Expanded(child: Chip2('开心', ico: Icons.sentiment_satisfied_alt_outlined, on: () => _play('happy'))),
              ]),
              const SizedBox(height: 8),
              // ★26.2.20 换衣：和电脑端一样的 3 套（白T / 卫衣 / 碎花裙）
              Row(children: [
                for (final o in ['default', 'hoodie', 'dress']) ...[
                  Expanded(
                    child: Chip2(
                      kOutfitName[o] ?? o,
                      ico: o == _outfit ? Icons.check_circle : Icons.checkroom_outlined,
                      on: () => _setOutfit(o),
                    ),
                  ),
                  if (o != 'dress') const SizedBox(width: 8),
                ],
              ]),
              const SizedBox(height: 8),
            ],
            Row(children: [
              Expanded(
                child: Chip2('控制器', ico: Icons.tune, on: () {
                  Navigator.of(context).pop();
                  openCtrl(context);
                }),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Chip2('回去聊天', ico: Icons.chat_bubble_outline, on: () => Navigator.of(context).pop()),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

/// data:image/png;base64,xxx → 字节（解码失败返回空，Image.memory 会走 errorBuilder，不白屏）
Uint8List dataUriBytes(String uri) {
  try {
    final i = uri.indexOf(',');
    return base64Decode(i >= 0 ? uri.substring(i + 1) : uri);
  } catch (e) {
    return Uint8List(0);
  }
}
