// 包娜 App · 「她」的展示：聊天页从左边缘往右滑 → 看她
//
// ★26.2.20 全本地：手机不连电脑时，她不再是死立绘——直接播放电脑端同款
//   「裸体视频」（站立循环）。点她她会回应（醒一下），还能切换动作：
//   睡觉 / 坐下 / 走动 / 醒来，都是电脑端裸体动作视频。
//   连电脑模式保持原实时抓屏（/api/petshot）。
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'api.dart';
import 'main.dart';
import 'sheets.dart';
import 'theme.dart';

/// ★26.2.20 裸体动作视频（打包进 App）：动作 → 资源路径
const Map<String, String> kActVideo = {
  'stand': 'assets/video/stand-nude.mp4', // 站立（默认循环）
  'idle': 'assets/video/idle-nude.mp4',
  'sleep': 'assets/video/sleep-nude.mp4',
  'sit': 'assets/video/sit-nude.mp4',
  'walk': 'assets/video/walk-nude.mp4',
  'wake': 'assets/video/wake-nude.mp4',
};

const Map<String, String> kActLabel = {
  'stand': '她站着看你',
  'idle': '她发呆了一小会儿',
  'sleep': '她睡着了，呼吸轻轻的',
  'sit': '她坐了下来',
  'walk': '她朝你走了两步',
  'wake': '她醒过来，揉揉眼睛',
};

class PetDrawer extends StatefulWidget {
  const PetDrawer({super.key});

  @override
  State<PetDrawer> createState() => _PetDrawerState();
}

class _PetDrawerState extends State<PetDrawer> {
  Timer? _t;
  String _img = ''; // 连电脑模式的实时画面 data:image/png;base64,...
  String _msg = ''; // 动作气泡
  bool _touch = false;

  bool get _local => app.brain != null; // ★26.2.18 全本地：不连电脑时用打包动画

  // ★26.2.20 本地裸体视频
  VideoPlayerController? _vc;
  String _act = 'stand';

  @override
  void initState() {
    super.initState();
    if (_local) {
      _play('stand');
    } else {
      _refresh();
      _t = Timer.periodic(const Duration(milliseconds: 1600), (_) => _refresh());
    }
  }

  @override
  void dispose() {
    _t?.cancel();
    _vc?.dispose();
    super.dispose();
  }

  /// 播指定动作的裸体视频（自动循环）
  void _play(String act) {
    if (!kActVideo.containsKey(act)) act = 'stand';
    final old = _vc;
    _vc = null;
    old?.dispose();
    final c = VideoPlayerController.asset(kActVideo[act]!);
    _vc = c;
    setState(() => _act = act);
    c.initialize().then((_) {
      if (!mounted || _vc != c) {
        c.dispose();
        return;
      }
      c.setLooping(true);
      c.play();
      setState(() {});
    }).catchError((_) {});
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
      // 摸她：醒一下回应，然后回到站立
      setState(() => _touch = true);
      _play('wake');
      await Future.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      setState(() => _touch = false);
      toast(context, '你摸了她一下，她醒了');
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

  /// 切动作视频（一次性动作播完不自动回 stand——睡觉就让她睡着，点她再醒）
  void _actBtn(String act, String tip) {
    if (_act == act) {
      toast(context, '她已经在${kActLabel[act] ?? act}了');
      return;
    }
    _play(act);
    toast(context, tip);
  }

  @override
  Widget build(BuildContext context) {
    final av = '${app.herSet['herAvatar'] ?? ''}';
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
                    Text('${app.status} · 视频里的是她', style: const TextStyle(fontSize: 11.5, color: kSub)),
                  ]),
                ]),
              ),
              PressScale(
                onTap: () => Navigator.of(context).pop(),
                radius: kRCapsule,
                child: const SizedBox(width: 34, height: 34, child: Center(child: Icon(Icons.close, size: 19))),
              ),
            ]),

            // ★26.2.20 她在你面前动（裸体视频循环）
            Sec(_local ? '她在你面前（裸体视频，会动）' : '她在桌面上（实时）'),
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
                          child: _vc == null || !_vc!.value.isInitialized
                              ? const Center(child: Text('她在穿衣服…', style: TextStyle(fontSize: 12, color: kSub)))
                              : FittedBox(
                                  fit: BoxFit.contain,
                                  child: SizedBox(
                                    width: _vc!.value.size.width,
                                    height: _vc!.value.size.height,
                                    child: VideoPlayer(_vc!),
                                  ),
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
              Expanded(child: Text(_local ? (_touch ? '摸着呢…' : '点一下她 = 摸摸她 · ${kActLabel[_act] ?? ''}') : (_touch ? '摸着呢…' : '点一下画面 = 摸摸她 · 每 2 秒自动刷新'), style: const TextStyle(fontSize: 11.5, color: kSub))),
            ]),
            const SizedBox(height: 10),

            // ★26.2.20 动作按钮（本地裸体视频）
            if (_local) ...[
              Row(children: [
                Expanded(child: Chip2('睡觉', ico: Icons.bedtime_outlined, on: () => _actBtn('sleep', '她躺下睡了')),),
                const SizedBox(width: 8),
                Expanded(child: Chip2('坐下', ico: Icons.airline_seat_recline_extra_outlined, on: () => _actBtn('sit', '她坐下了')),),
                const SizedBox(width: 8),
                Expanded(child: Chip2('走动', ico: Icons.directions_walk_outlined, on: () => _actBtn('walk', '她朝你走两步')),),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: Chip2('叫她', ico: Icons.waving_hand_outlined, on: () => _actBtn('wake', '她醒过来看你')),),
                const SizedBox(width: 8),
                Expanded(child: Chip2('站好', ico: Icons.accessibility_new_outlined, on: () => _actBtn('stand', '她站好看着你')),),
                const SizedBox(width: 8),
                Expanded(child: Chip2('摸她', ico: Icons.favorite_outline, on: _pet),),
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
