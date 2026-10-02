// 包娜 App · 「她」的展示：聊天页从左边缘往右滑 → 看她在电脑桌面上什么样（实时画面）
//
// 数据来自电脑端 /api/petshot（Electron 抓的桌宠窗口，透明底，抓出来就是她本人）。
// 打开时每 1.6 秒自动刷一次（关掉抽屉就停，不浪费）。
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'api.dart';
import 'main.dart';
import 'sheets.dart';
import 'theme.dart';

const Map<String, String> kOutfitName = {
  'default': '白T',
  'hoodie': '卫衣',
  'dress': '裙子',
  'nude': '裸着',
};

class PetDrawer extends StatefulWidget {
  const PetDrawer({super.key});

  @override
  State<PetDrawer> createState() => _PetDrawerState();
}

class _PetDrawerState extends State<PetDrawer> {
  Timer? _t;
  String _img = ''; // data:image/png;base64,...
  String _msg = '';
  bool _touch = false;

  bool get _local => app.brain != null; // ★26.2.18 全本地：不连电脑时显示打包立绘

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
    if (_local) {
      _msg = _localLines[DateTime.now().millisecondsSinceEpoch % _localLines.length];
    } else {
      _refresh();
      _t = Timer.periodic(const Duration(milliseconds: 1600), (_) => _refresh());
    }
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_local) return; // 本地立绘不拉实时画面
    final a = app.api;
    if (a == null) return;
    // ★2026-09-29 老公说"这个软件太卡、非常吃网络"：以前不管抽屉开没开都每 1.6 秒拉一张
    //   （≈1.5MB/分钟），抽屉关着也在拉。现在只在真的看得见时才拉；App 退到后台也不拉。
    if (!mounted) return;
    final sc = Scaffold.maybeOf(context);
    // ★2026-09-30 左滑看不到她的修复：抽屉滑开就拉（打开时 initState 的立即拉可能还没就绪，
    //   由定时器 1.6 秒内补上；不在抽屉页时不浪费网络）
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
      // 本地互动：换一句动作气泡，像她真的在
      setState(() {
        _touch = true;
        _msg = _localLines[(DateTime.now().millisecondsSinceEpoch ~/ 700) % _localLines.length];
      });
      await Future.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;
      setState(() => _touch = false);
      toast(context, '你摸了她一下');
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
    final outfit = kOutfitName['${app.herSet['outfit'] ?? 'default'}'] ?? '白T';
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

            const Sec('她在你身边'),
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
                            'assets/pet.png',
                            fit: BoxFit.contain,
                            gaplessPlayback: true,
                            errorBuilder: (_, __, ___) => const Center(child: Text('立绘没加载出来', style: TextStyle(fontSize: 12, color: kSub))),
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
              Expanded(child: Text(_local ? (_touch ? '摸着呢…' : '点一下她 = 摸摸她 · 她会回应你') : (_touch ? '摸着呢…' : '点一下画面 = 摸摸她 · 每 2 秒自动刷新'), style: const TextStyle(fontSize: 11.5, color: kSub))),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: Chip2('摸头', ico: Icons.pan_tool_alt_outlined, on: _pet)),
              const SizedBox(width: 8),
              Expanded(
                child: Chip2('换衣服', ico: Icons.checkroom_outlined, on: () {
                  Navigator.of(context).pop();
                  openSettings(context);
                }),
              ),
            ]),
            const SizedBox(height: 8),
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
