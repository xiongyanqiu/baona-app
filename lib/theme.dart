// 包娜 App · 外观层：Apple HIG + Liquid Glass（iOS 26 官方设计语言）
//
// 设计语言要点（照着官方手册来的）：
//  1) 玻璃是「一层材料」不是一张贴图——半透明 + 背景实时模糊（BackdropFilter）
//  2) 玻璃有「高光边」：上缘受光偏亮、下缘收暗，看起来像一块有厚度的玻璃
//  3) 层次靠层叠不靠描边：内容在玻璃下面滚，玻璃浮在上面（导航栏/输入栏）
//  4) 形状统一用胶囊与大圆角（continuous corner 观感）
//  5) 动效短而稳：按下去轻微缩放（spring 手感），不做花哨弹跳
//  6) 文字用系统字重分层：大标题 w700 / 正文 w400 / 说明 kSub
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';

/* ------------------------------- 基础色板 ------------------------------- */
const Color kBg = Color(0xFF0B0B0F);
const Color kBg2 = Color(0xFF16121F);
const Color kAccent = Color(0xFF7C6BF5);
const Color kAccent2 = Color(0xFFB98CFF);
const Color kText = Color(0xFFF2F1F7);
const Color kSub = Color(0xFF9A98A6);
const Color kLine = Color(0x1AFFFFFF);
const Color kGlass = Color(0x14FFFFFF);
const Color kGlass2 = Color(0x22FFFFFF);

/* --------------------------- Liquid Glass 材质 --------------------------- */
const double kBlur = 28; // 主玻璃模糊（导航/输入栏）
const double kBlurSoft = 16; // 卡片玻璃模糊（轻一点，省电）
const double kRSheet = 30; // 抽屉大圆角
const double kRCard = 22; // 卡片圆角
const double kRCell = 14; // 列表格子
const double kRCapsule = 999; // 胶囊（按钮/导航）
const String kAppVer = '1.1.7'; // App 版本（跟 pubspec 对齐，装上能一眼看出是不是新的）
/// 底栏悬浮时给内容留的高度（各页滚动到底部要多留这么多，不然最后一条被玻璃压住看不见）
/// ★别再按"底栏 75pt + 安全区"自己算：Scaffold 已经把「底栏高度（含安全区）」放进 body 的
///   padding.bottom 里了（实测 iPhone 上 = 113）。之前自己又加了一遍，等于算了两次，
///   输入栏被顶到老高 —— 2026-09-29 老公报的"输入栏和底栏之间空一条"就是这个。
const double kNavSpace = 84;
const double kNavGap = 10; // 输入栏跟底栏之间留的呼吸位

/// 悬浮底栏实际占的高度（Scaffold 报多少就用多少）+ 呼吸位
double navSpace(BuildContext c) {
  final p = MediaQuery.of(c).padding.bottom;
  return (p > 0 ? p : kNavSpace) + kNavGap;
}

/// 键盘是不是弹着？两个信号取其一（都能在实测里对上）：
///   ① 原始 view 的 viewInsets（真机上就是键盘高度；Scaffold 会把 body 的 MediaQuery 版抹成 0，所以不能用 MediaQuery.viewInsets）
///   ② Scaffold 把 body 的 padding.bottom 抹成 0 —— 只有键盘弹着时才会这样（底栏高度那会儿是 113）
bool kbUp(BuildContext c) {
  if (View.of(c).viewInsets.bottom > 0) return true;
  return MediaQuery.of(c).padding.bottom == 0;
}

/// 头像/背景可能是两种东西：https 地址，或者手机上传后的 data:image/...（电脑端存的就是 dataURL）
/// ★iOS 上 NetworkImage 读 data URL 会直接报错 → 必须走 MemoryImage，头像才显示得出来
ImageProvider? avatarOf(String s) {
  if (s.isEmpty) return null;
  if (s.startsWith('data:')) {
    final i = s.indexOf(',');
    try {
      return MemoryImage(base64Decode(i >= 0 ? s.substring(i + 1) : s));
    } catch (_) {
      return null;
    }
  }
  return NetworkImage(s);
}
const Color kHair = Color(0x1FFFFFFF); // 发丝分隔线
const Color kSpecTop = Color(0x5CFFFFFF); // 上缘高光
const Color kSpecBottom = Color(0x0FFFFFFF); // 下缘收暗
const Color kFillA = Color(0x17FFFFFF); // 玻璃填充（亮）
const Color kFillB = Color(0x0AFFFFFF); // 玻璃填充（暗）
const Color kOk = Color(0xFF57D9A3);
const Color kBad = Color(0xFFFF9A9A);

Color hexColor(String h, [Color dflt = kAccent]) {
  try {
    var s = h.trim().replaceFirst('#', '');
    if (s.length == 6) s = 'FF$s';
    return Color(int.parse(s, radix: 16));
  } catch (_) {
    return dflt;
  }
}

/* -------------------------------- 主题 -------------------------------- */
ThemeData buildTheme() {
  final t = ThemeData(brightness: Brightness.dark, useMaterial3: true);
  return t.copyWith(
    scaffoldBackgroundColor: kBg,
    colorScheme: const ColorScheme.dark(primary: kAccent, secondary: kAccent2, surface: kBg),
    appBarTheme: const AppBarTheme(backgroundColor: Colors.transparent, elevation: 0, foregroundColor: kText),
    textTheme: t.textTheme.apply(bodyColor: kText, displayColor: kText),
    dividerColor: kHair,
    splashColor: Colors.transparent,
    highlightColor: Colors.transparent,
    hoverColor: Colors.transparent,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kFillB,
      hintStyle: const TextStyle(color: kSub),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(kRCapsule), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(kRCapsule), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(kRCapsule), borderSide: BorderSide(color: kAccent.withValues(alpha: 0.8))),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : const Color(0xFFE9E7F2)),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? kAccent : const Color(0x33FFFFFF)),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: kAccent,
      inactiveTrackColor: const Color(0x33FFFFFF),
      thumbColor: Colors.white,
      overlayColor: kAccent.withValues(alpha: 0.16),
    ),
    bottomSheetTheme: const BottomSheetThemeData(backgroundColor: Colors.transparent, elevation: 0, modalBackgroundColor: Colors.transparent),
    dialogTheme: DialogThemeData(
      backgroundColor: const Color(0xF21B1726),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRCard)),
    ),
    snackBarTheme: const SnackBarThemeData(backgroundColor: Color(0xF02A2438), contentTextStyle: TextStyle(color: kText)),
  );
}

/* ============================ 玻璃：核心材质 ============================ */
/// 一块 Liquid Glass。全 App 的容器都该长这样：
/// 背景实时模糊 + 上亮下暗的高光边 + 一层很淡的填充。
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.radius = kRCard,
    this.pad = EdgeInsets.zero,
    this.blur = kBlurSoft,
    this.tint, // 染色玻璃（主按钮/选中态用）
    this.strong = false, // 更实的底（抽屉/弹窗）
    this.onTap,
    this.margin,
  });

  final Widget child;
  final double radius;
  final EdgeInsets pad;
  final double blur;
  final Color? tint;
  final bool strong;
  final VoidCallback? onTap;
  final EdgeInsets? margin;

  @override
  Widget build(BuildContext context) {
    final br = BorderRadius.circular(radius);
    final fill = tint != null
        ? LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [tint!.withValues(alpha: 0.34), tint!.withValues(alpha: 0.20)],
          )
        : LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: strong
                ? const [Color(0x2BFFFFFF), Color(0x14FFFFFF)]
                : const [kFillA, kFillB],
          );

    Widget core = Container(
      padding: pad,
      decoration: BoxDecoration(gradient: fill, borderRadius: BorderRadius.circular(radius - 1)),
      child: child,
    );

    // 内容下面是「真模糊」——这才是玻璃，不是半透明贴纸
    core = ClipRRect(
      borderRadius: BorderRadius.circular(radius - 1),
      child: BackdropFilter(filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur), child: core),
    );

    // 1px 高光描边：外层渐变 + 内层留 1px
    Widget glass = Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: br,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [kSpecTop, Color(0x1FFFFFFF), kSpecBottom],
        ),
      ),
      child: Padding(padding: const EdgeInsets.all(1), child: core),
    );

    if (onTap == null) return glass;
    return PressScale(onTap: onTap, radius: radius, child: glass);
  }
}

/// 兼容老代码的玻璃卡片（签名保持不变）
class Glass extends StatelessWidget {
  const Glass({super.key, required this.child, this.pad = const EdgeInsets.all(12), this.radius = kRCard, this.color});

  final Widget child;
  final EdgeInsets pad;
  final double radius;
  final Color? color;

  @override
  Widget build(BuildContext context) => GlassSurface(
        radius: radius,
        pad: pad,
        blur: kBlurSoft,
        tint: color,
        child: child,
      );
}

/// 按下去轻微缩一下（真机手感，别做花哨动效）
class PressScale extends StatefulWidget {
  const PressScale({super.key, required this.child, this.onTap, this.onLong, this.radius = kRCapsule, this.scale = 0.96});

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLong;
  final double radius;
  final double scale;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: widget.onTap,
        onLongPress: widget.onLong,
        child: AnimatedScale(
          scale: _down ? widget.scale : 1,
          duration: const Duration(milliseconds: 130),
          curve: Curves.easeOutCubic,
          child: widget.child,
        ),
      );
}

/* ============================== 小组件库 ============================== */
/// 胶囊玻璃按钮（页面顶部那排 chip 都是它）
class Chip2 extends StatelessWidget {
  const Chip2(this.text, {super.key, this.on, this.on2 = false, this.ico});

  final String text;
  final VoidCallback? on;
  final bool on2;
  final IconData? ico;

  @override
  Widget build(BuildContext context) => GlassSurface(
        radius: kRCapsule,
        blur: 12,
        tint: on2 ? kAccent : null,
        onTap: on,
        pad: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (ico != null) ...[Icon(ico, size: 15, color: on2 ? Colors.white : kSub), const SizedBox(width: 6)],
          Text(text,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: on2 ? FontWeight.w600 : FontWeight.w400,
                  color: on2 ? Colors.white : kText.withValues(alpha: 0.9))),
        ]),
      );
}

/// 小结标题（设置/抽屉里分组用）
class Sec extends StatelessWidget {
  const Sec(this.text, {super.key, this.trail});

  final String text;
  final Widget? trail;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(6, 20, 6, 8),
        child: Row(children: [
          Text(text.toUpperCase(),
              style: const TextStyle(fontSize: 11.5, color: kSub, letterSpacing: 0.9, fontWeight: FontWeight.w600)),
          const Spacer(),
          if (trail != null) trail!,
        ]),
      );
}

/// 发丝分隔线
class Hair extends StatelessWidget {
  const Hair({super.key, this.indent = 0});
  final double indent;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(left: indent),
        child: const Divider(height: 1, thickness: 0.6, color: kHair),
      );
}

/// 开关行（iOS 设置那种：左边标题，右边开关）
class SwitchRow extends StatelessWidget {
  const SwitchRow(this.title, this.value, this.onChanged, {super.key, this.sub});

  final String title;
  final String? sub;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 14.5)),
              if (sub != null)
                Text(sub!, style: const TextStyle(fontSize: 11.5, color: kSub, height: 1.35)),
            ]),
          ),
          Switch(value: value, onChanged: onChanged, activeColor: kAccent, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
        ]),
      );
}

/// 设置里的一行（左标签 + 右控件），自带发丝线
class RowTile extends StatelessWidget {
  const RowTile({super.key, required this.label, this.trail, this.sub, this.hair = true});

  final String label;
  final Widget? trail;
  final String? sub;
  final bool hair;

  @override
  Widget build(BuildContext context) => Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(children: [
            Expanded(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: const TextStyle(fontSize: 14.5)),
                if (sub != null) Text(sub!, style: const TextStyle(fontSize: 11.5, color: kSub, height: 1.35)),
              ]),
            ),
            if (trail != null) trail!,
          ]),
        ),
        if (hair) const Hair(),
      ]);
}

/// iOS 分段控件（穿不穿、语音模式这种多选一）
class SegCtl extends StatelessWidget {
  const SegCtl({super.key, required this.options, required this.value, required this.onPick});

  final List<Map<String, String>> options; // [{'v': 'default', 't': '白T'}]
  final String value;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: const Color(0x1F000000),
          borderRadius: BorderRadius.circular(kRCapsule),
          border: Border.all(color: kLine),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final o in options)
              PressScale(
                onTap: () => onPick(o['v']!),
                radius: kRCapsule,
                scale: 0.94,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                  decoration: BoxDecoration(
                    color: value == o['v'] ? kAccent : Colors.transparent,
                    borderRadius: BorderRadius.circular(kRCapsule),
                  ),
                  child: Text(o['t']!,
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: value == o['v'] ? FontWeight.w600 : FontWeight.w400,
                          color: value == o['v'] ? Colors.white : kSub)),
                ),
              ),
          ],
        ),
      );
}

/// 大标题（iOS large title）
class BigTitle extends StatelessWidget {
  const BigTitle(this.text, {super.key, this.sub});

  final String text;
  final String? sub;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(text, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: -0.6)),
        if (sub != null) Text(sub!, style: const TextStyle(fontSize: 12.5, color: kSub)),
      ]);
}

/// 浮在上面的玻璃条（导航栏/头部）：内容从它下面滚过去
class GlassBar extends StatelessWidget {
  const GlassBar({super.key, required this.child, this.top = false});

  final Widget child;
  final bool top;

  @override
  Widget build(BuildContext context) => ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: kBlur, sigmaY: kBlur),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: top ? Alignment.topCenter : Alignment.bottomCenter,
                end: top ? Alignment.bottomCenter : Alignment.topCenter,
                colors: const [Color(0x3DFFFFFF), Color(0x0AFFFFFF)],
              ),
              border: Border(
                top: top ? BorderSide.none : const BorderSide(color: kHair, width: 0.6),
                bottom: top ? const BorderSide(color: kHair, width: 0.6) : BorderSide.none,
              ),
            ),
            child: child,
          ),
        ),
      );
}

/// iOS 26 那种悬浮胶囊标签栏
class GlassNav extends StatelessWidget {
  const GlassNav({super.key, required this.items, required this.index, required this.onTap});

  final List<Map<String, dynamic>> items; // [{'on': Icons.x, 'off': Icons.y, 't': '聊天'}]
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
          child: GlassSurface(
            radius: kRCapsule,
            blur: kBlur,
            pad: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Row(
              children: [
                for (var i = 0; i < items.length; i++)
                  Expanded(
                    child: PressScale(
                      onTap: () => onTap(i),
                      radius: kRCapsule,
                      scale: 0.95,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 170),
                        curve: Curves.easeOutCubic,
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        decoration: BoxDecoration(
                          color: index == i ? kAccent.withValues(alpha: 0.30) : Colors.transparent,
                          borderRadius: BorderRadius.circular(kRCapsule),
                        ),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(
                            (index == i ? items[i]['on'] : items[i]['off']) as IconData,
                            size: 20,
                            color: index == i ? Colors.white : kSub,
                          ),
                          const SizedBox(height: 2),
                          Text('${items[i]['t']}',
                              style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: index == i ? FontWeight.w600 : FontWeight.w400,
                                  color: index == i ? Colors.white : kSub)),
                        ]),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
}

/* --------------------------------- 背景 --------------------------------- */
/// 背景：有自定义壁纸就用壁纸，没有就默认深色渐变（可模糊）
class Wall extends StatelessWidget {
  const Wall({super.key, required this.url, this.blur = 0, this.opacity = 1, required this.child});

  final String url;
  final double blur;
  final double opacity; // ★照片的透明度（老公 2026-09-29：设了背景照片没法调透明，字看不清）
  final Widget child;

  @override
  Widget build(BuildContext context) {
    Widget base = const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [kBg, kBg2, Color(0xFF120E1B), kBg],
        ),
      ),
      child: SizedBox.expand(),
    );
    if (url.isNotEmpty) {
      final p = avatarOf(url);
      base = Stack(fit: StackFit.expand, children: [
        if (p != null)
          Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Image(image: p, fit: BoxFit.cover, errorBuilder: (_, __, ___) => base),
          ),
        // 透明的地方露出底下的深色底；再压一点点暗角（★2026-09-29 老公说照片看不清 → 从 0.30 降到 0.14）
        Opacity(opacity: (1 - opacity.clamp(0.0, 1.0)) * 0.9, child: base),
        Opacity(opacity: 0.14, child: const ColoredBox(color: Color(0xFF000000))),
      ]);
    }
    return Stack(children: [
      base,
      if (url.isNotEmpty && blur > 0)
        BackdropFilter(filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur), child: const SizedBox.expand()),
      child,
    ]);
  }
}

/// 抽屉/弹窗的玻璃底板（大圆角 + 模糊 + 顶部抓手）
class GlassSheet extends StatelessWidget {
  const GlassSheet({super.key, required this.child, this.pad = EdgeInsets.zero});

  final Widget child;
  final EdgeInsets pad;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(kRSheet)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 34, sigmaY: 34),
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x4DFFFFFF), Color(0x14FFFFFF), Color(0x0DFFFFFF)],
              ),
              border: Border(top: BorderSide(color: kSpecTop, width: 0.8)),
            ),
            child: Padding(padding: pad, child: child),
          ),
        ),
      );
}

/// 抓手
class Grabber extends StatelessWidget {
  const Grabber({super.key});

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          width: 38,
          height: 5,
          margin: const EdgeInsets.only(top: 8, bottom: 6),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.28), borderRadius: BorderRadius.circular(6)),
        ),
      );
}

/// 提示条（曾经的 snackbar 会被抽屉盖住 → 现在统一用抽屉自己的提示 + 这个胶囊）
void toast(BuildContext c, String t) {
  ScaffoldMessenger.of(c).showSnackBar(SnackBar(
    content: Text(t),
    duration: const Duration(seconds: 2),
    behavior: SnackBarBehavior.floating,
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 92),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRCapsule)),
  ));
}
