// 包娜 App · 外观层：Apple HIG + Liquid Glass（iOS 26 官方设计语言）
//
// 设计语言要点（照着官方手册来的）：
//  1) 玻璃是「一层材料」不是一张贴图——半透明 + 背景实时模糊（BackdropFilter）
//  2) 玻璃有「高光边」：上缘受光偏亮、下缘收暗，看起来像一块有厚度的玻璃
//  3) 层次靠层叠不靠描边：内容在玻璃下面滚，玻璃浮在上面（导航栏/输入栏）
//  4) 形状统一用胶囊与大圆角（continuous corner 观感）
//  5) 动效短而稳：按下去轻微缩放（spring 手感），不做花哨弹跳
//  6) 文字用系统字重分层：大标题 w700 / 正文 w400 / 说明 kSub
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';

/* ------------------------------- 基础色板 ------------------------------- */
// ★27.0 全新版：全部改用 iOS 系统色（深色模式 UIColor 语义色），彻底去掉紫色
const Color kBg = Color(0xFF000000); // systemBackground
const Color kBg2 = Color(0xFF1C1C1E); // secondarySystemBackground
const Color kAccent = Color(0xFF0A84FF); // systemBlue
const Color kAccent2 = Color(0xFF409CFF); // systemBlue（渐变亮端）
const Color kText = Color(0xFFFFFFFF); // label
const Color kSub = Color(0x99EBEBF5); // secondaryLabel（60% 白）
const Color kLine = Color(0xFF38383A); // separator
const Color kGlass = Color(0x1FFFFFFF); // 玻璃填充（systemFill 观感）
const Color kGlass2 = Color(0x2EFFFFFF);

/* --------------------------- Liquid Glass 材质 --------------------------- */
const double kBlur = 28; // 主玻璃模糊（导航/输入栏）
const double kBlurSoft = 16; // 卡片玻璃模糊（轻一点，省电）
const double kRSheet = 30; // 抽屉大圆角
const double kRCard = 22; // 卡片圆角
const double kRCell = 14; // 列表格子
const double kRCapsule = 999; // 胶囊（按钮/导航）
const String kAppVer = '27.0.14.9'; // App 版本（跟 pubspec 对齐，装上能一眼看出是不是新的）
/// 底栏悬浮时给内容留的高度（各页滚动到底部要多留这么多，不然最后一条被玻璃压住看不见）
/// ★2026-09-30 彻底改成固定值：之前读 padding/viewPadding 都不可靠（Scaffold、键盘、不同机型
///   给的数不一样，输入框一会儿被盖住一会儿被顶到半空）。底栏玻璃是固定高度：
///   胶囊 47 + SafeArea 上下留白 14 + iPhone 底部安全区 34 + 呼吸位 10 = 105，直接钉死。
///   覆盖聊天/飞行棋/商城/我们 所有页面，任何环境都一样。
const double kNavInner = 47; // 玻璃胶囊内容高：pad6 + 图标20 + 2 + 文字≈13 + pad6
const double kNavMargin = 14; // GlassNav 里 SafeArea 的上下留白（上6 + 下8）
const double kNavSafe = 34; // iPhone 带 home 条底部安全区（固定值，不赌环境）
const double kNavGap = 10; // 输入栏跟底栏之间留的呼吸位

/// 悬浮底栏实际占的高度（胶囊 + 留白 + 底部安全区）+ 呼吸位 —— 恒为 105
double navSpace(BuildContext c) => kNavInner + kNavMargin + kNavSafe + kNavGap;

/// 键盘是不是弹着？只认 body 收到的键盘高度（MediaQuery.viewInsets）。
///   键盘弹起时 Scaffold 会把它写进 body 的 MediaQuery，最贴近布局实际。
bool kbUp(BuildContext c) => MediaQuery.of(c).viewInsets.bottom > 0;

/// 头像/背景可能是两种东西：https 地址，或者手机上传后的 data:image/...（电脑端存的就是 dataURL）
/// ★iOS 上 NetworkImage 读 data URL 会直接报错 → 必须走 MemoryImage，头像才显示得出来
/// ★★2026-09-30：加 provider 缓存 —— 同一个 URL 永远返回同一个 ImageProvider，
///   否则每次 rebuild 都会新建 provider → 图片重新解码 → 头像闪回"娜"字占位
final Map<String, ImageProvider> _avCache = {};
ImageProvider? avatarOf(String s) {
  if (s.isEmpty) return null;
  final hit = _avCache[s];
  if (hit != null) return hit;
  ImageProvider? p;
  if (s.startsWith('data:')) {
    final i = s.indexOf(',');
    try {
      p = MemoryImage(base64Decode(i >= 0 ? s.substring(i + 1) : s));
    } catch (_) {
      return null;
    }
  } else if (s.startsWith('file://')) {
    // ★26.2.26 本地文件路径（file:// 前缀）
    p = FileImage(File(s.substring(7)));
  } else if (s.startsWith('/') || (s.length >= 3 && s[1] == ':' && (s[2] == '\\' || s[2] == '/'))) {
    // ★26.2.26 本地绝对路径（iOS 沙盒 /var/mobile/…、Windows C:\…）→ 本地相册照片做壁纸
    p = FileImage(File(s));
  } else {
    p = NetworkImage(s);
  }
  _avCache[s] = p;
  return p;
}
const Color kHair = Color(0xFF38383A); // separator
const Color kSpecTop = Color(0x6EFFFFFF); // 上缘高光（v27.0.14.9 锐化：液态玻璃 2.0 更清晰的镜面高光）
const Color kSpecBottom = Color(0x14FFFFFF); // 下缘收暗（层次更分明）
const Color kFillA = Color(0x1CFFFFFF); // 玻璃填充（亮）v27.0.14.9：更实，漫射更有效（液态玻璃 2.0）
const Color kFillB = Color(0x0FFFFFFF); // 玻璃填充（暗）
/// 液态玻璃强度（0~1）。iOS 27「透明度滑块」的对应物：
/// 越高玻璃越清晰锐利，越低越接近透明。v27.0.14.9 先定常量，
/// 后续在"我的→外观"开放给用户调节（默认 0.75）。
const double kGlassStrength = 0.75;
const Color kOk = Color(0xFF30D158); // systemGreen
const Color kBad = Color(0xFFFF453A); // systemRed

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
    // ★26.2.22 苹果官网动效：所有 push 页面统一"淡入 + 轻微上浮"过渡
    // ★26.2.26 iOS 不覆盖：让系统用默认过渡（右滑入 + 屏幕左边缘侧滑返回）。
    //   之前 iOS 也用自定义过渡 → 系统侧滑返回手势被替换掉了，有些页面退不出去。
    //   注：本 Flutter 版本无 CupertinoPageTransitionsBuilder，不写 iOS = 系统默认 Cupertino
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: AppleTransitionsBuilder(),
      TargetPlatform.macOS: AppleTransitionsBuilder(),
      TargetPlatform.windows: AppleTransitionsBuilder(),
      TargetPlatform.linux: AppleTransitionsBuilder(),
      TargetPlatform.fuchsia: AppleTransitionsBuilder(),
    }),
  );
}

/// 苹果官网式页面过渡：淡入 + 轻微上浮（不重、不花，稳定跟手）
class AppleTransitionsBuilder extends PageTransitionsBuilder {
  const AppleTransitionsBuilder();

  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context,
      Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.018), end: Offset.zero).animate(curved),
        child: child,
      ),
    );
  }
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
    this.elevated = false, // v27.0.14.9：浮起投影（Bento 卡片/主按钮用，玻璃悬浮在内容上）
    this.onTap,
    this.margin,
  });

  final Widget child;
  final double radius;
  final EdgeInsets pad;
  final double blur;
  final Color? tint;
  final bool strong;
  final bool elevated;
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
    // ★26.2.22：blur<=0 跳过 BackdropFilter —— 列表卡片用纯渐变（实时模糊每行一个太耗电）
    if (blur > 0) {
      core = ClipRRect(
        borderRadius: BorderRadius.circular(radius - 1),
        child: BackdropFilter(filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur), child: core),
      );
    }

    // 1px 高光描边：外层渐变 + 内层留 1px
    // v27.0.14.9 elevated：加软投影，玻璃卡片像浮在内容上（空间分层，Bento 便当盒的深度）
    Widget glass = Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: br,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [kSpecTop, Color(0x1FFFFFFF), kSpecBottom],
        ),
        boxShadow: elevated
            ? [
                BoxShadow(
                    color: const Color(0x42000000),
                    blurRadius: 18,
                    offset: const Offset(0, 8)),
                BoxShadow(
                    color: kSpecTop.withValues(alpha: 0.10),
                    blurRadius: 2,
                    offset: const Offset(0, 1)),
              ]
            : null,
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
/// ★26.2.22 苹果官网动效：子项交错浮现 —— 淡入 + 上浮，兄弟之间错开 delay，
///   就是 apple.com 首页那些卡片逐个"浮起来"的感觉。
class Appear extends StatefulWidget {
  const Appear({super.key, required this.child, this.delay = 0, this.dy = 14, this.onDone});

  final Widget child;
  final int delay; // 毫秒，后面的兄弟错开一点
  final double dy; // 起点上浮距离（px）
  final VoidCallback? onDone; // ★26.2.24 动画播完回调（列表用它标记"首播已完成"，防止滚动重建重复播）

  @override
  State<Appear> createState() => _AppearState();
}

class _AppearState extends State<Appear> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 480));

  @override
  void initState() {
    super.initState();
    if (widget.delay > 0) {
      Future.delayed(Duration(milliseconds: widget.delay), () {
        if (mounted) _c.forward().whenComplete(() => widget.onDone?.call());
      });
    } else {
      _c.forward().whenComplete(() => widget.onDone?.call());
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        child: widget.child,
        builder: (context, child) => Opacity(
          opacity: CurvedAnimation(parent: _c, curve: Curves.easeOutCubic).value,
          child: Transform.translate(
            offset: Offset(0, widget.dy * (1 - _c.value)),
            child: child,
          ),
        ),
      );
}

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

/// iOS 26 Liquid Glass 悬浮胶囊标签栏
/// 手指在底栏上左右拖：液态玻璃高亮片跟手滑动，松手吸附到最近 tab（发布会那个特效）
class GlassNav extends StatefulWidget {
  const GlassNav({super.key, required this.items, required this.index, required this.onTap, this.big = -1});

  final List<Map<String, dynamic>> items; // [{'on': Icons.x, 'off': Icons.y, 't': '聊天'}]
  final int index;
  final ValueChanged<int> onTap;
  final int big; // ★27.0：中间大按钮下标（=我的），渲染成凸起圆形玻璃按钮

  @override
  State<GlassNav> createState() => _GlassNavState();
}

class _GlassNavState extends State<GlassNav> {
  double _drag = 0;       // 拖动累计位移（跟手）
  bool _dragging = false; // 拖动中 → 滑块零动画纯跟手；松手 → 260ms 吸附动画

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    final index = widget.index;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
        child: GlassSurface(
          radius: kRCapsule,
          blur: kBlur,
          pad: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: LayoutBuilder(builder: (ctx, cons) {
            final itemW = cons.maxWidth / items.length;
            final sliderX = index * itemW + (_dragging ? _drag : 0);
            return GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragStart: (_) => setState(() => _dragging = true),
              onHorizontalDragUpdate: (d) => setState(() => _drag += d.delta.dx),
              onHorizontalDragEnd: (d) {
                final v = d.primaryVelocity ?? 0;
                int target;
                if (v.abs() > 200) {
                  // 快速甩 → 直接下一格
                  target = v < 0 ? index + 1 : index - 1;
                } else {
                  // 慢拖 → 吸附到最近的格
                  target = (index + _drag / itemW).round();
                }
                target = target.clamp(0, items.length - 1);
                setState(() {
                  _dragging = false;
                  _drag = 0;
                });
                if (target != index) widget.onTap(target);
              },
              onHorizontalDragCancel: () => setState(() {
                _dragging = false;
                _drag = 0;
              }),
              child: Stack(children: [
                // ★液态玻璃高亮滑块：拖动时跟手实时移动，松手吸附动画滑到选中格
                AnimatedPositioned(
                  duration: _dragging
                      ? Duration.zero
                      : const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  left: sliderX,
                  top: 0,
                  bottom: 0,
                  width: itemW,
                  child: Container(
                    decoration: BoxDecoration(
                      // 玻璃感：上亮下透的半透明白 + 细高光描边 + 微投影
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x73FFFFFF), Color(0x38FFFFFF), Color(0x1FFFFFFF)],
                      ),
                      borderRadius: BorderRadius.circular(kRCapsule),
                      border: Border.all(color: const Color(0x33FFFFFF), width: 0.8),
                      boxShadow: [
                        BoxShadow(
                            color: const Color(0x26000000),
                            blurRadius: 14,
                            offset: const Offset(0, 4)),
                      ],
                    ),
                  ),
                ),
                Row(children: [
                  for (var i = 0; i < items.length; i++)
                    Expanded(
                      child: i == widget.big
                          ? _BigNavBtn(
                              selected: index == i,
                              icon: items[i]['on'] as IconData,
                              label: '${items[i]['t']}',
                              onTap: () => widget.onTap(i))
                          : PressScale(
                              onTap: () => widget.onTap(i),
                              radius: kRCapsule,
                              scale: 0.95,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 7),
                                child: Column(mainAxisSize: MainAxisSize.min, children: [
                                  Stack(clipBehavior: Clip.none, children: [
                                    AnimatedScale(
                                      scale: index == i ? 1.26 : 1.0,
                                      duration: const Duration(milliseconds: 220),
                                      curve: Curves.easeOutBack,
                                      child: AnimatedSwitcher(
                                        duration: const Duration(milliseconds: 220),
                                        switchInCurve: Curves.easeOutBack,
                                        switchOutCurve: Curves.easeIn,
                                        transitionBuilder: (c, anim) => ScaleTransition(
                                          scale: Tween(begin: 0.75, end: 1.0).animate(anim),
                                          child: FadeTransition(opacity: anim, child: c),
                                        ),
                                        child: Icon(
                                          (index == i ? items[i]['on'] : items[i]['off']) as IconData,
                                          key: ValueKey<bool>(index == i),
                                          size: 20,
                                          color: index == i ? Colors.white : kSub,
                                        ),
                                      ),
                                    ),
                                    if (items[i]['badge'] == true)
                                      Positioned(
                                        right: -4,
                                        top: -2,
                                        child: Container(
                                          width: 9,
                                          height: 9,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFF5B7A),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                                color: const Color(0xFF17131F), width: 1.6),
                                          ),
                                        ),
                                      ),
                                  ]),
                                  const SizedBox(height: 2),
                                  Text('${items[i]['t']}',
                                      style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight:
                                              index == i ? FontWeight.w600 : FontWeight.w400,
                                          color: index == i ? Colors.white : kSub)),
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    curve: Curves.easeOutCubic,
                                    width: index == i ? 14 : 0,
                                    height: 3,
                                    margin: const EdgeInsets.only(top: 3),
                                    decoration: BoxDecoration(
                                      color: index == i ? Colors.white : Colors.transparent,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ]),
                              ),
                            ),
                    ),
                ]),
              ]),
            );
          }),
        ),
      ),
    );
  }
}

/* --------------------------------- 背景 --------------------------------- */
/// ★27.0 底栏中间大按钮：凸起圆形玻璃盘（Liquid Glass），选中时 systemBlue 填充
class _BigNavBtn extends StatelessWidget {
  const _BigNavBtn({required this.selected, required this.icon, required this.label, required this.onTap});
  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // 圆形盘向上凸出 12，盖住玻璃胶囊上缘（中间主按钮）
        Transform.translate(
          offset: const Offset(0, -12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? kAccent : const Color(0x33FFFFFF),
              gradient: selected
                  ? null
                  : const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x59FFFFFF), Color(0x1FFFFFFF)],
                    ),
              border: Border.all(
                  color: selected ? kAccent : const Color(0x4DFFFFFF), width: 1),
              boxShadow: [
                BoxShadow(
                  color: selected ? kAccent.withValues(alpha: 0.35) : const Color(0x33000000),
                  blurRadius: 16,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Icon(icon,
                size: 26, color: selected ? Colors.white : const Color(0xE6FFFFFF)),
          ),
        ),
        const SizedBox(height: 1),
        Text(label,
            style: TextStyle(
                fontSize: 10.5,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? Colors.white : kSub)),
      ]),
    );
  }
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
          colors: [kBg, kBg2, Color(0xFF0E0E12), kBg],
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
            // ★2026-10-02 闪屏修复：gaplessPlayback —— 切页/全局 rebuild 时背景保留上一帧，
            //   新帧就绪前不闪回空白/渐变（之前每次 rebuild 都先清空再绘制 → 画面闪）
            child: Image(image: p, fit: BoxFit.cover, gaplessPlayback: true, errorBuilder: (_, __, ___) => base),
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

/* ======================= ★v27.0.14.5 三维空间动效 ======================= */
/// 统一动效时长/曲线（3D 系）
const Duration kD3 = Duration(milliseconds: 420);
const Duration kD3Short = Duration(milliseconds: 200);
const Curve k3In = Curves.easeOutCubic;
const Curve k3Spring = Curves.easeOutBack;

/// 3D 入场：从远处翻入（rotationY 透视）+ 上浮 + 淡入，弹簧收尾。
/// 用法：新消息气泡 / 主页元素 / 首屏卡片 —— 兄弟之间用 delay 错开 = 空间纵深进场。
class Appear3D extends StatefulWidget {
  const Appear3D({super.key, required this.child, this.delay = 0, this.dy = 16, this.fromAngle = 0.18, this.onDone});

  final Widget child;
  final int delay; // 毫秒，后面的兄弟错开一点（stagger）
  final double dy; // 起点上浮距离（px）
  final double fromAngle; // 起始旋转弧度（默认约 10°）
  final VoidCallback? onDone; // 播完回调（列表用它清"新消息"标记，防止滚动重建重复播）

  @override
  State<Appear3D> createState() => _Appear3DState();
}

class _Appear3DState extends State<Appear3D> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: kD3);

  @override
  void initState() {
    super.initState();
    if (widget.delay > 0) {
      Future.delayed(Duration(milliseconds: widget.delay), () {
        if (mounted) _c.forward().whenComplete(() => widget.onDone?.call());
      });
    } else {
      _c.forward().whenComplete(() => widget.onDone?.call());
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        final v = CurvedAnimation(parent: _c, curve: k3In).value;
        return Opacity(
          opacity: v,
          child: Transform(
            alignment: Alignment.bottomCenter,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0011)
              ..rotateY(widget.fromAngle * (1 - v))
              ..translate(0.0, widget.dy * (1 - v)),
            child: child,
          ),
        );
      },
    );
  }
}

/// 触摸跟随 3D 倾斜：手指按住/滑动时，卡片像悬浮的玻璃片一样跟着转动
/// （Apple 官网卡片手感）。松手弹性归零。包一层在头像/主卡片上。
class Tilt3D extends StatefulWidget {
  const Tilt3D({super.key, required this.child, this.max = 0.14});

  final Widget child;
  final double max; // 最大倾斜弧度（默认约 8°）

  @override
  State<Tilt3D> createState() => _Tilt3DState();
}

class _Tilt3DState extends State<Tilt3D> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: kD3Short);
  double _rx = 0, _ry = 0; // 当前显示角度（动画插值）
  double _tx = 0, _ty = 0; // 目标角度

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _go() {
    final fx = _rx, fy = _ry, tx = _tx, ty = _ty;
    _c.stop();
    _c.reset();
    _c.addListener(() {
      final t = Curves.easeOutCubic.transform(_c.value);
      setState(() {
        _rx = fx + (tx - fx) * t;
        _ry = fy + (ty - fy) * t;
      });
    });
    _c.forward();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanDown: (_) {},
      onPanUpdate: (d) {
        final box = context.findRenderObject();
        if (box is! RenderBox || box.size.isEmpty) return;
        final local = box.globalToLocal(d.globalPosition);
        final dx = ((local.dx / box.size.width) * 2 - 1).clamp(-1.0, 1.0);
        final dy = ((local.dy / box.size.height) * 2 - 1).clamp(-1.0, 1.0);
        _tx = dx * widget.max;
        _ty = -dy * widget.max;
        _go();
      },
      onPanEnd: (_) {
        _tx = 0;
        _ty = 0;
        _go();
      },
      onPanCancel: () {
        _tx = 0;
        _ty = 0;
        _go();
      },
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.0013)
          ..rotateX(_rx)
          ..rotateY(_ry),
        child: widget.child,
      ),
    );
  }
}

/// PageView 三维透视翻页：滑动时页面像在三维空间里翻转 ——
/// 当前页立起，滑走的页向后转远缩小，滑入的页从侧面转进来。
/// 包在 PageView 每个 child 外面，用 controller 的 page 偏移算角度。
class Page3D extends StatelessWidget {
  const Page3D({super.key, required this.ctrl, required this.index, required this.child});

  final PageController ctrl;
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ctrl,
      child: child,
      builder: (context, child) {
        final pos = ctrl.hasClients
            ? (ctrl.page ?? index.toDouble())
            : index.toDouble();
        final diff = (pos - index).clamp(-1.0, 1.0);
        final angle = diff * 0.24; // 最大约 13.8°
        final z = 1 - diff.abs() * 0.10; // 最大缩小 10%
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0012)
            ..rotateY(angle)
            ..scale(z),
          child: child,
        );
      },
    );
  }
}

/* ======================= ★v27.0.14.6 宇宙元素动画 ======================= */
/// 宇宙星尘背景：缓慢漂移 + 明暗闪烁的星星，可选偶发流星。
/// 轻量 CustomPaint 纯绘制（不建 widget 树），真机不卡、不耗电。
/// 用法：垫在页面内容下面一层，Positioned.fill + IgnorePointer 包住。
class StarField extends StatefulWidget {
  const StarField({super.key, this.count = 48, this.dim = false, this.shooting = false});

  final int count; // 星星数量（主页多一点、对话页少一点）
  final bool dim; // 更淡模式（阅读场景用）
  final bool shooting; // 是否偶发流星

  @override
  State<StarField> createState() => _StarFieldState();
}

class _StarFieldState extends State<StarField> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 60))..repeat();
  final List<_Star> _stars = [];
  final math.Random _rnd = math.Random();
  _Shoot? _shoot;
  Timer? _shootTimer;

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < widget.count; i++) {
      _stars.add(_Star(
        x: _rnd.nextDouble(),
        y: _rnd.nextDouble(),
        r: 0.4 + _rnd.nextDouble() * 1.3,
        base: 0.15 + _rnd.nextDouble() * 0.60,
        phase: _rnd.nextDouble() * 6.28,
        tw: 0.25 + _rnd.nextDouble() * 0.50,
        vx: (0.008 + _rnd.nextDouble() * 0.018) * (_rnd.nextBool() ? 1 : -1),
        vy: (0.005 + _rnd.nextDouble() * 0.014) * (_rnd.nextBool() ? 1 : -1),
      ));
    }
    if (widget.shooting) _scheduleShoot();
  }

  void _scheduleShoot() {
    _shootTimer = Timer(Duration(seconds: 3 + _rnd.nextInt(6)), () {
      if (!mounted) return;
      setState(() {
        _shoot = _Shoot(
          sx: 0.12 + _rnd.nextDouble() * 0.72,
          sy: 0.02 + _rnd.nextDouble() * 0.30,
          dx: 0.20 + _rnd.nextDouble() * 0.32,
          dy: 0.10 + _rnd.nextDouble() * 0.18,
          start: _c.value,
        );
      });
      _scheduleShoot();
    });
  }

  @override
  void dispose() {
    _shootTimer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: const SizedBox.expand(),
      builder: (context, child) => CustomPaint(
        painter: _StarPainter(
          t: _c.value,
          stars: _stars,
          shoot: _shoot,
          dim: widget.dim,
          shooting: widget.shooting,
        ),
        child: child,
      ),
    );
  }
}

class _Star {
  _Star({required this.x, required this.y, required this.r, required this.base, required this.phase, required this.tw, required this.vx, required this.vy});
  double x, y, r, base, phase, tw, vx, vy;
}

class _Shoot {
  _Shoot({required this.sx, required this.sy, required this.dx, required this.dy, required this.start});
  double sx, sy, dx, dy, start;
}

class _StarPainter extends CustomPainter {
  _StarPainter({required this.t, required this.stars, this.shoot, this.dim = false, this.shooting = false});
  final double t;
  final List<_Star> stars;
  final _Shoot? shoot;
  final bool dim;
  final bool shooting;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final mul = dim ? 0.55 : 1.0;
    for (final s in stars) {
      // 缓慢漂移（60s 一个来回，几乎不可察觉但画面是活的）
      final x = (s.x + s.vx * t) % 1.0;
      final y = (s.y + s.vy * t) % 1.0;
      // 明暗闪烁（sin 呼吸）
      final a = (s.base + s.tw * (0.5 + 0.5 * math.sin(2 * 3.14159 * (t + s.phase))))
          .clamp(0.0, 1.0) * mul;
      canvas.drawCircle(
        Offset(x * w, y * h),
        s.r,
        Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: a),
      );
    }
    // 偶发流星：斜向拖尾 + 头部亮点
    if (shooting && shoot != null) {
      final p = (t - shoot!.start) / 0.012; // 约 0.72s 划过（60s 周期换算）
      if (p >= 0 && p <= 1) {
        final px = (shoot!.sx + shoot!.dx * p) * w;
        final py = (shoot!.sy + shoot!.dy * p) * h;
        final tx = px - shoot!.dx * 0.07 * w;
        final ty = py - shoot!.dy * 0.07 * h;
        // ★不能用 Gradient.linear：material 的 Gradient 抽象类遮蔽了 dart:ui 的 → 用 LinearGradient.createShader
        final grad = Paint()
          ..shader = LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: const [Color(0x00FFFFFF), Color(0xB3FFFFFF)],
          ).createShader(Rect.fromPoints(Offset(tx, ty), Offset(px, py)));
        canvas.drawLine(Offset(tx, ty), Offset(px, py), grad..strokeWidth = 1.3);
        canvas.drawCircle(Offset(px, py), 1.5, Paint()..color = const Color(0xE6FFFFFF));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _StarPainter old) => old.t != t;
}

/// 星光光环：绕着物体缓慢旋转的光点环 + 柔光圆环（配大头像，像她自带一圈星光）。
/// 用法：Stack 里 Positioned.fill 包住，child 传占位；实际物体叠在它上面。
class StarHalo extends StatefulWidget {
  const StarHalo({super.key, required this.child});

  final Widget child;

  @override
  State<StarHalo> createState() => _StarHaloState();
}

class _StarHaloState extends State<StarHalo> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 12))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) => CustomPaint(
        painter: _HaloPainter(_c.value),
        child: child,
      ),
    );
  }
}

class _HaloPainter extends CustomPainter {
  _HaloPainter(this.t);
  final double t; // 0..1 旋转周期

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final R = size.width / 2 - 4;
    // 柔光圆环（两层，蓝系星光色）
    canvas.drawCircle(c, R,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0
          ..color = const Color(0x4DA8C8FF));
    canvas.drawCircle(c, R - 4,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..color = const Color(0x1A8FBFFF));
    // 环绕光点：径向起伏 + 亮度脉动，整体缓慢旋转
    const n = 16;
    for (var i = 0; i < n; i++) {
      final ang = i * 2 * 3.14159 / n + t * 2 * 3.14159;
      final rr = R + math.sin(i * 1.9) * 2.5;
      final px = c.dx + math.cos(ang) * rr;
      final py = c.dy + math.sin(ang) * rr;
      final a = (0.20 + 0.35 * (0.5 + 0.5 * math.sin(i * 2.7 + t * 2 * 3.14159)))
          .clamp(0.0, 1.0);
      final r = 0.8 + 0.9 * (0.5 + 0.5 * math.sin(i * 2.3));
      canvas.drawCircle(Offset(px, py), r,
          Paint()..color = const Color(0xFFCFE6FF).withValues(alpha: a));
    }
    // 顶部钻石亮斑（呼吸）
    final topA = (0.25 + 0.20 * math.sin(t * 2 * 3.14159)).clamp(0.0, 1.0);
    canvas.drawCircle(Offset(c.dx, c.dy - R + 2), 2.2,
        Paint()..color = const Color(0xE6FFFFFF).withValues(alpha: topA));
  }

  @override
  bool shouldRepaint(covariant _HaloPainter old) => old.t != t;
}

/* ================== ★v27.0.14.7 万物互联主视觉（星辰中枢） ================== */
/// 万物互联式主视觉：中心一颗主星（她的头像），外面一圈小星辰设备节点
/// 沿轨道缓慢公转，中心发出光线连到每个节点 —— 像 IoT 中枢拓扑 / 星系图。
///
/// 结构：
///   · 中心光晕（径向渐变）＋ 主星（core，可放头像）
///   · 轨道环两圈（装饰）+ 节点轨道一圈
///   · 节点 = 玻璃小圆 + 图标 + 标签，30s 一圈缓慢公转
///   · 发光连接线：中心主星边缘 → 每个节点（跟随公转）
class UniverseHub extends StatefulWidget {
  const UniverseHub({
    super.key,
    required this.core,
    required this.nodes,
    this.size = 340,
    this.coreSize = 176,
    this.orbitR = 128,
    this.basePeriod = 30,
    this.seed = 42,
  });

  final Widget core; // 中心主星（她的头像）
  final List<Map<String, dynamic>> nodes; // [{icon, label, onTap}]
  final double size; // 星系总直径
  final double coreSize; // 中心主星直径
  final double orbitR; // 节点基准轨道半径
  final int basePeriod; // 基准公转周期（秒）
  final int seed; // 无序轨道随机种子（固定，避免重建时位置乱跳）

  @override
  State<UniverseHub> createState() => _UniverseHubState();
}

/// 每颗小星辰的独立轨道参数（无序宇宙：半径/相位/速度/大小/光色都不同，
/// 没有两颗星在同一个轨道上、没有两颗星同步旋转）
class _StarSpec {
  _StarSpec(
      {required this.r,
      required this.phase,
      required this.speed,
      required this.size,
      required this.glow,
      required this.arcSeed});
  final double r; // 轨道半径（各有偏差）
  final double phase; // 初始相位（各自随机起点）
  final double speed; // 公转速度系数（0.75~1.3，快慢不一）
  final double size; // 星辰直径（有大有小）
  final Color glow; // 星光色（月白/星蓝/暖金随机）
  final int arcSeed; // 断弧轨道的随机种子（每颗星轨道断裂位置不同）
}

class _UniverseHubState extends State<UniverseHub>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: Duration(seconds: widget.basePeriod))..repeat();

  late final List<_StarSpec> _specs;

  @override
  void initState() {
    super.initState();
    final rnd = math.Random(widget.seed);
    const glows = [Color(0xFFE8F4FF), Color(0xFF8FBFFF), Color(0xFFFFD9A8)];
    _specs = [
      for (var i = 0; i < widget.nodes.length; i++)
        _StarSpec(
          r: widget.orbitR + rnd.nextDouble() * 34 - 22,
          phase: rnd.nextDouble() * 2 * math.pi,
          speed: 0.75 + rnd.nextDouble() * 0.55,
          size: 30 + rnd.nextDouble() * 12,
          glow: glows[rnd.nextInt(glows.length)],
          arcSeed: rnd.nextInt(10000),
        ),
    ];
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: widget.core,
      builder: (context, core) {
        final cx = widget.size / 2;
        final cy = widget.size / 2;
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(alignment: Alignment.center, children: [
            // 断弧轨道 + 尘埃星带 + 连接线（与节点同步旋转）
            Positioned.fill(
              child: CustomPaint(
                painter: _UniversePainter(
                  t: _c.value,
                  specs: _specs,
                  coreR: widget.coreSize / 2,
                  seed: widget.seed,
                ),
              ),
            ),
            // 中心主星
            core ?? const SizedBox.shrink(),
            // 环绕公转的小星辰
            for (var i = 0; i < _specs.length; i++) _node(i, cx, cy),
          ]),
        );
      },
    );
  }

  Widget _node(int i, double cx, double cy) {
    final s = _specs[i];
    // 轻微椭圆 + 各自相位/速度 → 无序但有生命感的公转
    final ang = s.phase + _c.value * 2 * math.pi * s.speed;
    final px = cx + math.cos(ang) * s.r;
    final py = cy + math.sin(ang) * s.r * 0.94;
    final item = widget.nodes[i];
    final d = s.size;
    return Positioned(
      left: px - 30,
      top: py - d / 2,
      width: 60,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: item['onTap'] as VoidCallback?,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // 星辰本体：中心白亮 → 星光色 → 透明，外圈双层光晕
          Container(
            width: d,
            height: d,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xF2FFFFFF),
                  s.glow.withValues(alpha: 0.85),
                  s.glow.withValues(alpha: 0.10),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                    color: s.glow.withValues(alpha: 0.45),
                    blurRadius: d * 0.9,
                    spreadRadius: 0.5),
                BoxShadow(
                    color: s.glow.withValues(alpha: 0.20),
                    blurRadius: d * 1.8),
              ],
            ),
            child: Center(
              child: Icon(item['icon'] as IconData,
                  size: d * 0.40,
                  color: const Color(0x8C1A2433)),
            ),
          ),
          const SizedBox(height: 2),
          Text('${item['label']}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 9.5, color: kSub)),
        ]),
      ),
    );
  }
}

class _UniversePainter extends CustomPainter {
  _UniversePainter(
      {required this.t,
      required this.specs,
      required this.coreR,
      required this.seed});

  final double t;
  final List<_StarSpec> specs;
  final double coreR;
  final int seed;

  late final List<_Dust> _dust = _makeDust();

  // 尘埃星带：固定种子生成，随 t 整片缓慢旋转（宇宙不是空的，是弥漫着微尘）
  List<_Dust> _makeDust() {
    final rnd = math.Random(seed);
    return [
      for (var i = 0; i < 46; i++)
        _Dust(
          r: 62 + rnd.nextDouble() * 72,
          a: rnd.nextDouble() * 2 * math.pi,
          d: 0.6 + rnd.nextDouble() * 1.4,
          o: 0.08 + rnd.nextDouble() * 0.22,
        ),
    ];
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2;
    final c = Offset(cx, cy);
    // 中心光晕：主星的光照亮整个星系核心
    final glow = Paint()
      ..shader = RadialGradient(
        colors: const [Color(0x40A8C8FF), Color(0x16A8C8FF), Color(0x00A8C8FF)],
      ).createShader(Rect.fromCircle(center: c, radius: 146));
    canvas.drawCircle(c, 146, glow);
    // 中心碎光：8 个光点绕着主星慢慢漂移（像她身边的气态卫星尘）
    final frag = Paint();
    for (var i = 0; i < 8; i++) {
      final a0 = i * 2 * math.pi / 8 + t * 2 * math.pi * 0.35;
      final rr = coreR + 10 + (i % 3) * 10.0;
      final px = cx + math.cos(a0) * rr;
      final py = cy + math.sin(a0) * rr * 0.92;
      final fa = 0.15 + 0.25 * (0.5 + 0.5 * math.sin(i * 2.1 + t * 2 * math.pi));
      frag.color = const Color(0xFFD9EBFF).withValues(alpha: fa);
      canvas.drawCircle(Offset(px, py), 1.1 + (i % 2) * 1.1, frag);
    }
    // 尘埃星带
    for (final d in _dust) {
      final a = d.a + t * 2 * math.pi * 0.05;
      final px = cx + math.cos(a) * d.r;
      final py = cy + math.sin(a) * d.r * 0.94;
      frag.color = const Color(0xFFCFE6FF).withValues(alpha: d.o);
      canvas.drawCircle(Offset(px, py), d.d, frag);
    }
    // 断弧轨道：每颗星自己的轨道，断裂位置随机（没有完美正圆，只有被扰动过的轨迹）
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = const Color(0x2EFFFFFF);
    for (var i = 0; i < specs.length; i++) {
      final s = specs[i];
      final rnd = math.Random(s.arcSeed);
      for (var k = 0; k < 3; k++) {
        final a0 = rnd.nextDouble() * 2 * math.pi;
        final span = 0.9 + rnd.nextDouble() * 1.2;
        canvas.drawArc(Rect.fromCircle(center: c, radius: s.r), a0, span, false, arc);
      }
    }
    // 发光连接线：主星边缘 → 星（断成 4 段的信号脉冲，像万物互联的数据流）
    final line = Paint()..strokeWidth = 1.0;
    for (var i = 0; i < specs.length; i++) {
      final s = specs[i];
      final ang = s.phase + t * 2 * math.pi * s.speed;
      final sx = cx + math.cos(ang) * coreR;
      final sy = cy + math.sin(ang) * coreR;
      final ex = cx + math.cos(ang) * s.r;
      final ey = cy + math.sin(ang) * s.r * 0.94;
      const segs = 4;
      for (var k = 0; k < segs; k++) {
        final f0 = k / segs, f1 = (k + 0.45) / segs;
        line.color =
            const Color(0xFFE8F4FF).withValues(alpha: 0.10 + 0.28 * (k + 1) / segs);
        canvas.drawLine(
            Offset(sx + (ex - sx) * f0, sy + (ey - sy) * f0),
            Offset(sx + (ex - sx) * f1, sy + (ey - sy) * f1),
            line);
      }
      // 星底微光
      canvas.drawCircle(
          Offset(ex, ey), 2.6, Paint()..color = s.glow.withValues(alpha: 0.55));
    }
  }

  @override
  bool shouldRepaint(covariant _UniversePainter old) =>
      old.t != t || old.seed != seed;
}

class _Dust {
  _Dust({required this.r, required this.a, required this.d, required this.o});
  final double r;
  final double a;
  final double d;
  final double o;
}
