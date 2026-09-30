# -*- coding: utf-8 -*-
import io

# ============ A. theme.dart GlassNav：图标过渡动画 + 选中放大 ============
p = r'C:\Users\xilisi\Doubao\chats\2026-09-27\new-chat\baona-app\lib\theme.dart'
s = io.open(p, encoding='utf-8').read()

old = """                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Stack(clipBehavior: Clip.none, children: [
                            Icon(
                              (index == i ? items[i]['on'] : items[i]['off']) as IconData,
                              size: 20,
                              color: index == i ? Colors.white : kSub,
                            ),"""
new = """                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Stack(clipBehavior: Clip.none, children: [
                            // ★2.0 第一波：图标 filled/outline 切换平滑过渡 + 选中项微放大（iOS 标签栏手感）
                            AnimatedScale(
                              scale: index == i ? 1.18 : 1.0,
                              duration: const Duration(milliseconds: 190),
                              curve: Curves.easeOutCubic,
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 190),
                                switchInCurve: Curves.easeOut,
                                switchOutCurve: Curves.easeIn,
                                transitionBuilder: (c, anim) => FadeTransition(opacity: anim, child: c),
                                child: Icon(
                                  (index == i ? items[i]['on'] : items[i]['off']) as IconData,
                                  key: ValueKey<bool>(index == i),
                                  size: 20,
                                  color: index == i ? Colors.white : kSub,
                                ),
                              ),
                            ),"""
assert old in s, 'glassnav icon fail'
s = s.replace(old, new)
io.open(p, 'w', encoding='utf-8', newline='').write(s)
print('theme.dart GlassNav 图标过渡+放大完成')
