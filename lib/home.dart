// 包娜 App · 包娜主页（v27.0.13 启动主界面）
// 中间是她的大头像（点她就开始聊天）+ 名字/在线，底部一条玻璃统计
// （聊过的消息 / 记得的事 / 陪你的天数）。iOS 27 Liquid Glass 风格。
// ★v27.0.13：删掉 2x2 快捷卡片 —— 功能统一走底栏（照片/视频/音频/我的），
//   主页只负责"她"，点她的大头像 = 开始聊天，画面和点击逻辑都简洁。
import 'package:flutter/material.dart';

import 'agent_chat.dart'; // ★v27.0.29 电脑 Agent 独立会话
import 'api.dart';
import 'main.dart';
import 'novel.dart'; // ★27.0.16.8 番茄小说
import 'theme.dart';

/// 启动主页面：包娜主页。
/// onOpenChat：点她的大头像进入对话（HomePage 负责 push 全屏 MsgPage）
class BaonaHome extends StatefulWidget {
  const BaonaHome({super.key, required this.onOpenChat, required this.onGoTab});
  final VoidCallback onOpenChat;
  final ValueChanged<int> onGoTab;

  @override
  State<BaonaHome> createState() => _BaonaHomeState();
}

class _BaonaHomeState extends State<BaonaHome> {
  int _msgCount = 0;
  int _memCount = 0;
  int _dayCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final b = app.brain; // 统计走本地大脑；纯电脑模式没数据就显示 0
    if (b == null) return;
    final s = await b.stats();
    if (!mounted) return;
    final ok = s['ok'] == true;
    setState(() {      _msgCount = ok ? ((s['msgCount'] as num?)?.toInt() ?? 0) : _msgCount;      _memCount = ok ? ((s['memCount'] as num?)?.toInt() ?? 0) : _memCount;
      _dayCount = ok ? ((s['dayCount'] as num?)?.toInt() ?? 0) : _dayCount;
    });
  }

  String get _dateLine {
    final n = DateTime.now();
    const wd = ['一', '二', '三', '四', '五', '六', '日'];
    return '${n.month}月${n.day}日 · 星期${wd[n.weekday - 1]}';
  }

  // ★27.0.16.8 番茄小说：push 全屏网页阅读页
  void _openNovel() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NovelPage()));
  }

  // ★v27.0.29 电脑 Agent：独立会话（纯 agent，非包娜），在「开始聊天」旁边
  void _openPcAgent() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AgentChatPage()));
  }

  // ★27.0.16.2 万物互联：外圈卫星 = 设置里配置过的可连接设备（电脑/安卓），在线亮青绿、离线灰
  List<Map<String, dynamic>> _satellites() {
    final d = Store.devices;
    final out = <Map<String, dynamic>>[];
    final pc = d['pc'];
    if (pc is Map) {
      out.add({'id': 'pc', 'label': '电脑', 'online': pc['online'] == true, 'onTap': () {}});
    }
    final ad = d['android'];
    if (ad is Map) {
      out.add({'id': 'android', 'label': '安卓', 'online': ad['online'] == true, 'onTap': () {}});
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final herAv = '${app.herSet['herAvatar'] ?? ''}';
    final herName = '${app.herSet['nickName'] ?? ''}'.trim().isEmpty
        ? '包娜'
        : '${app.herSet['nickName'] ?? ''}';
    final herImg = avatarOf(herAv); // 可空：没头像/解码失败就显示占位字
    final avatarWidget = herImg == null
        ? Container(
            color: kBg2,
            child: const Center(
                child: Text('包',
                    style: TextStyle(
                        fontSize: 72, fontWeight: FontWeight.w700, color: kText))),
          )
        : Image(
            image: herImg,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => Container(
              color: kBg2,
              child: const Center(
                  child: Text('包',
                      style: TextStyle(
                          fontSize: 72, fontWeight: FontWeight.w700, color: kText))),
            ),
          );
    // ★v27.0.14.6 宇宙元素：背景星尘（缓慢漂移闪烁 + 偶发流星），垫在内容下面
    return Stack(children: [
      const Positioned.fill(
          child: IgnorePointer(child: StarField(count: 55, shooting: true))),
      SafeArea(
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
          child: Row(children: [
            Text(_dateLine,
                style: const TextStyle(fontSize: 13.5, color: kSub)),
            const Spacer(),
            GestureDetector(
              onTap: () => widget.onGoTab(4),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: kBg2,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0x26FFFFFF), width: 0.8),
                ),
                child: const Icon(Icons.settings_outlined, size: 19, color: kSub),
              ),
            ),
          ]),
        ),
        const Spacer(flex: 2),
        // 她：大头像（点她就开始聊天）+ 名字 + 在线
        // ★v27.0.14.7 万物互联主视觉：中间主星 = 她，外面一圈小星辰设备 = 聊天/照片/视频/音频/我的，
        //   轨道缓慢公转 + 发光连接线；点小星辰 = 进对应功能，点她 = 开始聊天
        Appear3D(
          fromAngle: 0.16,
          child: UniverseHub(
            size: 340,
            coreSize: 176,
            orbitR: 128,
            core: Tilt3D(
              max: 0.12,
              child: GestureDetector(
                onTap: widget.onOpenChat,
                child: Container(
                  width: 176,
                  height: 176,
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [kAccent.withValues(alpha: 0.55), kAccent.withValues(alpha: 0.15)],
                    ),
                    boxShadow: [
                      BoxShadow(
                          color: kAccent.withValues(alpha: 0.30),
                          blurRadius: 32,
                          offset: const Offset(0, 10)),
                    ],
                  ),
                  child: Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: const BoxDecoration(shape: BoxShape.circle),
                    child: avatarWidget,
                  ),
                ),
              ),
            ),
            nodes: [
              {'icon': Icons.chat_bubble_outline, 'label': '聊天', 'onTap': widget.onOpenChat},
              {'icon': Icons.photo_outlined, 'label': '照片', 'onTap': () => widget.onGoTab(1)},
              {'icon': Icons.videocam_outlined, 'label': '视频', 'onTap': () => widget.onGoTab(2)},
              {'icon': Icons.audiotrack_outlined, 'label': '音频', 'onTap': () => widget.onGoTab(3)},
              {'icon': Icons.menu_book_outlined, 'label': '小说', 'onTap': _openNovel}, // ★27.0.16.8 番茄小说
              {'icon': Icons.person_outline, 'label': '我的', 'onTap': () => widget.onGoTab(4)},
            ],
            // ★27.0.16.2 万物互联：外圈卫星 = 已配置的可连接设备（贝锐蒲公英组网，设置里配）
            satellites: _satellites(),
          ),
        ),
        const SizedBox(height: 22),
        Appear3D(
          delay: 90,
          dy: 10,
          fromAngle: 0.10,
          child: Text(herName,
              style: const TextStyle(
                  fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
        ),
        const SizedBox(height: 8),
        Appear3D(
          delay: 160,
          dy: 8,
          fromAngle: 0.08,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                  color: Color(0xFF34C759), shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            const Text('在线',
                style: TextStyle(fontSize: 13, color: kSub, fontWeight: FontWeight.w500)),
          ]),
        ),
        const SizedBox(height: 10),
        // 轻提示：点她 / 点下方按钮都能开聊
        Appear3D(
          delay: 230,
          dy: 8,
          fromAngle: 0.08,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            GestureDetector(
              onTap: widget.onOpenChat,
              child: GlassSurface(
                radius: 16,
                blur: kBlur,
                elevated: true,
                pad: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.chat_bubble_outline, size: 15, color: kAccent),
                  SizedBox(width: 6),
                  Text('开始聊天',
                      style: TextStyle(fontSize: 13.5, color: kText, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
            const SizedBox(width: 10),
            // ★v27.0.29 电脑 Agent 入口（独立对话，非包娜）
            GestureDetector(
              onTap: _openPcAgent,
              child: GlassSurface(
                radius: 16,
                blur: kBlur,
                elevated: true,
                pad: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.computer_outlined, size: 15, color: Color(0xFF34C759)),
                  SizedBox(width: 6),
                  Text('电脑 Agent',
                      style: TextStyle(fontSize: 13.5, color: kText, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ]),
        ),
        const Spacer(flex: 3),
        // 底部统计 Bento 卡 ★v27.0.14.9：从一行均分改成便当盒——中间主卡（聊过的消息）更大更高带强调色，
        //   两侧小卡（记得的事/陪你的天数）错落排列；玻璃 2.0 锐化 + 浮起投影（空间分层）
        Appear3D(
          delay: 300,
          dy: 10,
          fromAngle: 0.10,
          child: Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, navSpace(context) + 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: 5,
                  child: _BentoStat(
                      v: '$_memCount',
                      t: '记得的事',
                      icon: Icons.auto_awesome_outlined),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 7,
                  child: _BentoStat(
                      v: '$_msgCount',
                      t: '聊过的消息',
                      icon: Icons.chat_bubble_outline,
                      primary: true),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 5,
                  child: _BentoStat(
                      v: '$_dayCount',
                      t: '陪你的天数',
                      icon: Icons.favorite_outline),
                ),
              ],
            ),
          ),
        ),
      ]),
      ),
    ]);
  }
}

/// Bento 便当盒统计卡（v27.0.14.9）：中间主卡更大更高带强调色，两侧小卡错落。
/// 玻璃 2.0：更实的填充 + 锐利高光描边 + 浮起软投影（空间分层）。
class _BentoStat extends StatelessWidget {
  const _BentoStat(
      {required this.v, required this.t, required this.icon, this.primary = false});
  final String v;
  final String t;
  final IconData icon;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: primary ? 106 : 88,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(primary ? 24 : 20),
        gradient: primary
            ? LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [kAccent.withValues(alpha: 0.48), kAccent.withValues(alpha: 0.24)])
            : const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [kFillA, kFillB]),
        border: Border.all(color: const Color(0x33FFFFFF), width: 0.8),
        boxShadow: primary
            ? [
                BoxShadow(
                    color: kAccent.withValues(alpha: 0.28),
                    blurRadius: 22,
                    offset: const Offset(0, 8)),
              ]
            : [
                BoxShadow(
                    color: const Color(0x42000000),
                    blurRadius: 14,
                    offset: const Offset(0, 6)),
              ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: primary ? 20 : 16, color: primary ? kText : kSub),
        const SizedBox(height: 6),
        Text(v,
            style: TextStyle(
                fontSize: primary ? 24 : 17,
                fontWeight: FontWeight.w800,
                color: kText)),
        const SizedBox(height: 3),
        Text(t, style: const TextStyle(fontSize: 10.5, color: kSub)),
      ]),
    );
  }
}
