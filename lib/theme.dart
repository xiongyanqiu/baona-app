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
import 'dart:io';
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
const String kAppVer = '27.0.2'; // App 版本（跟 pubspec 对齐，装上能一眼看出是不是新的）
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
const Color kSpecTop = Color(0x5CFFFFFF); // 上缘高光
const Color kSpecBottom = Color(0x0FFFFFFF); // 下缘收暗
const Color kFillA = Color(0x17FFFFFF); // 玻璃填充（亮）
const Color kFillB = Color(0x0AFFFFFF); // 玻璃填充（暗）
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
    // ★26.2.22：blur<=0 跳过 BackdropFilter —— 列表卡片用纯渐变（实时模糊每行一个太耗电）
    if (blur > 0) {
      core = ClipRRect(
        borderRadius: BorderRadius.circular(radius - 1),
        child: BackdropFilter(filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur), child: core),
      );
    }

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
