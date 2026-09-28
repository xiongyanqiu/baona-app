// 包娜 App · 外观（跟手机网页一个味道：深色 + 紫色 + 玻璃气泡）
import 'dart:ui';

import 'package:flutter/material.dart';

const Color kBg = Color(0xFF0B0B0F);
const Color kBg2 = Color(0xFF16121F);
const Color kAccent = Color(0xFF7C6BF5);
const Color kAccent2 = Color(0xFFB98CFF);
const Color kText = Color(0xFFF2F1F7);
const Color kSub = Color(0xFF9A98A6);
const Color kLine = Color(0x1AFFFFFF);
const Color kGlass = Color(0x14FFFFFF);
const Color kGlass2 = Color(0x22FFFFFF);

Color hexColor(String h, [Color dflt = kAccent]) {
  try {
    var s = h.trim().replaceFirst('#', '');
    if (s.length == 6) s = 'FF$s';
    return Color(int.parse(s, radix: 16));
  } catch (_) {
    return dflt;
  }
}

ThemeData buildTheme() {
  final t = ThemeData(brightness: Brightness.dark, useMaterial3: true);
  return t.copyWith(
    scaffoldBackgroundColor: kBg,
    colorScheme: const ColorScheme.dark(primary: kAccent, secondary: kAccent2, surface: kBg),
    appBarTheme: const AppBarTheme(backgroundColor: Colors.transparent, elevation: 0, foregroundColor: kText),
    textTheme: t.textTheme.apply(bodyColor: kText, displayColor: kText),
    dividerColor: kLine,
    splashColor: const Color(0x227C6BF5),
    highlightColor: const Color(0x117C6BF5),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: kGlass,
      hintStyle: TextStyle(color: kSub),
      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14)), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14)), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14)), borderSide: BorderSide(color: kAccent)),
      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
    bottomSheetTheme: const BottomSheetThemeData(backgroundColor: Color(0xF216121F)),
    dialogTheme: const DialogThemeData(backgroundColor: Color(0xFF1B1726)),
    snackBarTheme: const SnackBarThemeData(backgroundColor: Color(0xF02A2438), contentTextStyle: TextStyle(color: kText)),
  );
}

/// 背景：有自定义壁纸就用壁纸，没有就默认深色渐变（可模糊）
class Wall extends StatelessWidget {
  const Wall({super.key, required this.url, this.blur = 0, required this.child});
  final String url;
  final double blur;
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
      base = Stack(fit: StackFit.expand, children: [
        Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => base),
        const ColoredBox(color: Color(0x66000000)),
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

/// 玻璃卡片
class Glass extends StatelessWidget {
  const Glass({super.key, required this.child, this.pad = const EdgeInsets.all(12), this.radius = 16, this.color});
  final Widget child;
  final EdgeInsets pad;
  final double radius;
  final Color? color;

  @override
  Widget build(BuildContext context) => Container(
        padding: pad,
        decoration: BoxDecoration(
          color: color ?? kGlass,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: kLine),
        ),
        child: child,
      );
}

/// 小圆角按钮（页面上那排 chip）
class Chip2 extends StatelessWidget {
  const Chip2(this.text, {super.key, this.on, this.on2 = false, this.ico});
  final String text;
  final VoidCallback? on;
  final bool on2;
  final IconData? ico;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: on,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: on2 ? kAccent.withValues(alpha: 0.28) : kGlass,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: on2 ? kAccent : kLine),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (ico != null) ...[Icon(ico, size: 15, color: on2 ? kText : kSub), const SizedBox(width: 5)],
            Text(text, style: TextStyle(fontSize: 13, color: on2 ? kText : kText.withValues(alpha: 0.85))),
          ]),
        ),
      );
}

/// 一页的小标题
class Sec extends StatelessWidget {
  const Sec(this.text, {super.key, this.trail});
  final String text;
  final Widget? trail;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 14, 2, 8),
        child: Row(children: [
          Text(text, style: const TextStyle(fontSize: 13, color: kSub, letterSpacing: 0.5)),
          const Spacer(),
          if (trail != null) trail!,
        ]),
      );
}

/// 开关行
class SwitchRow extends StatelessWidget {
  const SwitchRow(this.title, this.value, this.onChanged, {super.key, this.sub});
  final String title;
  final String? sub;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Expanded(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 14.5)),
              if (sub != null) Text(sub!, style: const TextStyle(fontSize: 11.5, color: kSub)),
            ]),
          ),
          Switch(value: value, onChanged: onChanged, activeColor: kAccent),
        ]),
      );
}

void toast(BuildContext c, String t) {
  ScaffoldMessenger.of(c).showSnackBar(SnackBar(
    content: Text(t),
    duration: const Duration(seconds: 2),
    behavior: SnackBarBehavior.floating,
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 76),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  ));
}
