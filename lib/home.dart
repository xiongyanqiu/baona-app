// 包娜 App · 包娜主页（v27.0.11 启动主界面）
// 中间是她的大头像 + 名字/在线，下面 2x2 快捷卡片（聊天/照片/视频/音频），
// 底部一条玻璃统计（聊过的消息 / 记得的事 / 陪你的天数）。iOS 27 Liquid Glass 风格。
import 'package:flutter/material.dart';

import 'main.dart';
import 'theme.dart';

/// 启动主页面：包娜主页。
/// onOpenChat：点"聊天"卡片进入对话（HomePage 负责 push 全屏 MsgPage）
/// onGoTab：切到照片/视频/音频/我的等底栏区（HomePage 的 _switchTab）
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
    setState(() {
      _msgCount = ok ? ((s['msgCount'] as num?)?.toInt() ?? 0) : _msgCount;
      _memCount = ok ? ((s['memCount'] as num?)?.toInt() ?? 0) : _memCount;
      _dayCount = ok ? ((s['dayCount'] as num?)?.toInt() ?? 0) : _dayCount;
    });
  }

  String get _dateLine {
    final n = DateTime.now();
    const wd = ['一', '二', '三', '四', '五', '六', '日'];
    return '${n.month}月${n.day}日 · 星期${wd[n.weekday - 1]}';
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
                        fontSize: 52, fontWeight: FontWeight.w700, color: kText))),
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
                          fontSize: 52, fontWeight: FontWeight.w700, color: kText))),
            ),
          );
    return SafeArea(
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
        // 她：大头像 + 名字 + 在线
        Container(
          width: 132,
          height: 132,
          padding: const EdgeInsets.all(4),
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
                  blurRadius: 28,
                  offset: const Offset(0, 8)),
            ],
          ),
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: const BoxDecoration(shape: BoxShape.circle),
            child: avatarWidget,
          ),
        ),
        const SizedBox(height: 18),
        Text(herName,
            style: const TextStyle(
                fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
        const SizedBox(height: 7),
        Row(mainAxisSize: MainAxisSize.min, children: [
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
        const Spacer(flex: 3),
        // 快捷卡片：聊天 / 照片 / 视频 / 音频
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Row(children: [
            _QuickCard(
              icon: Icons.chat_bubble_outline,
              label: '聊天',
              accent: true,
              onTap: () => widget.onOpenChat(),
            ),
            const SizedBox(width: 14),
            _QuickCard(
              icon: Icons.photo_library_outlined,
              label: '照片',
              onTap: () => widget.onGoTab(1),
            ),
            const SizedBox(width: 14),
            _QuickCard(
              icon: Icons.videocam_outlined,
              label: '视频',
              onTap: () => widget.onGoTab(2),
            ),
            const SizedBox(width: 14),
            _QuickCard(
              icon: Icons.audiotrack_outlined,
              label: '音频',
              onTap: () => widget.onGoTab(3),
            ),
          ]),
        ),
        const Spacer(flex: 2),
        // 底部统计条
        Padding(
          padding: const EdgeInsets.fromLTRB(30, 0, 30, 22),
          child: GlassSurface(
            radius: 22,
            blur: kBlur,
            pad: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
            child: Row(children: [
              _StatCell(v: '$_msgCount', t: '聊过的消息'),
              const _StatDivider(),
              _StatCell(v: '$_memCount', t: '记得的事'),
              const _StatDivider(),
              _StatCell(v: '$_dayCount', t: '陪你的天数'),
            ]),
          ),
        ),
      ]),
    );
  }
}

/// 2x2 快捷卡片（玻璃圆角）
class _QuickCard extends StatelessWidget {
  const _QuickCard({required this.icon, required this.label, required this.onTap, this.accent = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: GlassSurface(
          radius: 18,
          blur: kBlur,
          pad: const EdgeInsets.symmetric(vertical: 14),
          child: Column(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accent
                    ? kAccent.withValues(alpha: 0.22)
                    : kBg2,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0x1FFFFFFF), width: 0.8),
              ),
              child: Icon(icon, size: 21, color: accent ? kAccent : kText),
            ),
            const SizedBox(height: 8),
            Text(label,
                style: const TextStyle(fontSize: 12.5, color: kText, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.v, required this.t});
  final String v;
  final String t;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(children: [
        Text(v,
            style: const TextStyle(
                fontSize: 19, fontWeight: FontWeight.w700, color: kText)),
        const SizedBox(height: 3),
        Text(t, style: const TextStyle(fontSize: 11.5, color: kSub)),
      ]),
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 0.8, height: 30, color: const Color(0x22FFFFFF));
  }
}
