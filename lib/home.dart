// 包娜 App · 包娜主页（v27.0.13 启动主界面）
// 中间是她的大头像（点她就开始聊天）+ 名字/在线，底部一条玻璃统计
// （聊过的消息 / 记得的事 / 陪你的天数）。iOS 27 Liquid Glass 风格。
// ★v27.0.13：删掉 2x2 快捷卡片 —— 功能统一走底栏（照片/视频/音频/我的），
//   主页只负责"她"，点她的大头像 = 开始聊天，画面和点击逻辑都简洁。
import 'package:flutter/material.dart';

import 'main.dart';
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
        // 她：大头像（点她就开始聊天）+ 名字 + 在线
        GestureDetector(
          onTap: widget.onOpenChat,
          child: Container(
            width: 196,
            height: 196,
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
        const SizedBox(height: 22),
        Text(herName,
            style: const TextStyle(
                fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
        const SizedBox(height: 8),
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
        const SizedBox(height: 10),
        // 轻提示：点她 / 点下方按钮都能开聊
        GestureDetector(
          onTap: widget.onOpenChat,
          child: GlassSurface(
            radius: 16,
            blur: kBlur,
            pad: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.chat_bubble_outline, size: 15, color: kAccent),
              SizedBox(width: 6),
              Text('开始聊天',
                  style: TextStyle(fontSize: 13.5, color: kText, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
        const Spacer(flex: 3),
        // 底部统计条 ★v27.0.14 底部留 navSpace 让位 —— 之前少这一层，统计条被玻璃底栏盖住
        Padding(
          padding: EdgeInsets.fromLTRB(30, 0, 30, navSpace(context) + 10),
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
