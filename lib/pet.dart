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

  @override
  void initState() {
    super.initState();
    _refresh();
    _t = Timer.periodic(const Duration(milliseconds: 1600), (_) => _refresh());
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final a = app.api;
    if (a == null) return;
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

            const Sec('她在桌面上（实时）'),
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
                  child: _img.isEmpty
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
              Expanded(child: Text(_touch ? '摸着呢…' : '点一下画面 = 摸摸她 · 每 2 秒自动刷新', style: const TextStyle(fontSize: 11.5, color: kSub))),
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

/// data:image/png;base64,xxx → 字节
Uint8List dataUriBytes(String uri) {
  final i = uri.indexOf(',');
  return base64Decode(i >= 0 ? uri.substring(i + 1) : uri);
}
