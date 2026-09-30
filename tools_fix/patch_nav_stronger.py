# -*- coding: utf-8 -*-
import io

# ============ 1. theme.dart GlassNav：更强选中反馈 + 指示条 ============
p = r'C:\Users\xilisi\Doubao\chats\2026-09-27\new-chat\baona-app\lib\theme.dart'
s = io.open(p, encoding='utf-8').read()

old = """                          const SizedBox(height: 2),
                          Text('${items[i]['t']}',
                              style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: index == i ? FontWeight.w600 : FontWeight.w400,
                                  color: index == i ? Colors.white : kSub)),
                        ]),"""
new = """                          const SizedBox(height: 2),
                          Text('${items[i]['t']}',
                              style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: index == i ? FontWeight.w600 : FontWeight.w400,
                                  color: index == i ? Colors.white : kSub)),
                          // ★2.0 第二波：选中指示小横条（滑出来=iOS 标签栏的确认感）
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
                        ]),"""
assert old in s, 'indicator anchor fail'
s = s.replace(old, new)

# 放大加强 + 图标过渡加强
old2 = """                            AnimatedScale(
                              scale: index == i ? 1.18 : 1.0,
                              duration: const Duration(milliseconds: 190),
                              curve: Curves.easeOutCubic,
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 190),
                                switchInCurve: Curves.easeOut,
                                switchOutCurve: Curves.easeIn,
                                transitionBuilder: (c, anim) => FadeTransition(opacity: anim, child: c),"""
new2 = """                            AnimatedScale(
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
                                ),"""
assert old2 in s, 'icon anim anchor fail'
s = s.replace(old2, new2)
io.open(p, 'w', encoding='utf-8', newline='').write(s)
print('theme.dart 选中指示条+动效加强完成')

# ============ 2. main.dart Tab 淡入加强：加轻微上滑 ============
p = r'C:\Users\xilisi\Doubao\chats\2026-09-27\new-chat\baona-app\lib\main.dart'
s = io.open(p, encoding='utf-8').read()

old3 = """                  Expanded(
                    // ★2.0 第一波：切 tab 淡入
                    child: FadeTransition(opacity: _fadeCtrl, child: IndexedStack(index: _tab, children: const [
                      ChatListPage(),
                      ShopPage(),
                      GamePage(),
                      UsPage(),
                    ])),
                  ),"""
new3 = """                  Expanded(
                    // ★2.0 第二波：切 tab 淡入 + 轻微上滑（更明显）
                    child: FadeTransition(
                      opacity: _fadeCtrl,
                      child: SlideTransition(
                        position: Tween(begin: const Offset(0, 0.02), end: Offset.zero)
                            .animate(CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOutCubic)),
                        child: IndexedStack(index: _tab, children: const [
                          ChatListPage(),
                          ShopPage(),
                          GamePage(),
                          UsPage(),
                        ]),
                      ),
                    ),
                  ),"""
assert old3 in s, 'stack anchor fail'
s = s.replace(old3, new3)

old4 = "      AnimationController(vsync: this, duration: const Duration(milliseconds: 170), value: 1);"
new4 = "      AnimationController(vsync: this, duration: const Duration(milliseconds: 230), value: 1);"
assert old4 in s, 'duration anchor fail'
s = s.replace(old4, new4)
io.open(p, 'w', encoding='utf-8', newline='').write(s)
print('main.dart Tab 淡入加强完成')
