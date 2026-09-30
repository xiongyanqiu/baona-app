# -*- coding: utf-8 -*-
import io

# ============ B. main.dart：Tab 切换淡入 ============
p = r'C:\Users\xilisi\Doubao\chats\2026-09-27\new-chat\baona-app\lib\main.dart'
s = io.open(p, encoding='utf-8').read()

# 1. state 字段（实际：_tab/_navHidden/_lastPix）
old_state = """  int _tab = 0;
  bool _navHidden = false;
  double _lastPix = 0;"""
new_state = """  int _tab = 0;
  bool _navHidden = false;
  double _lastPix = 0;
  // ★2.0 第一波：切 tab 淡入（保持各页状态，只是透明度过渡）
  late final AnimationController _fadeCtrl =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 170), value: 1);"""
assert old_state in s, 'state anchor fail'
s = s.replace(old_state, new_state)

# 2. dispose：找 _HomePageState 的 dispose（"WidgetsBinding.instance.removeObserver(this)" 属于它）
old_disp = """  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }"""
new_disp = """  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _fadeCtrl.dispose();
    super.dispose();
  }"""
assert old_disp in s, 'dispose fail'
s = s.replace(old_disp, new_disp)

# 3. IndexedStack 包 FadeTransition
old_stack = """                  Expanded(
                    child: IndexedStack(index: _tab, children: const [
                      ChatListPage(),
                      ShopPage(),
                      GamePage(),
                      UsPage(),
                    ]),
                  ),"""
new_stack = """                  Expanded(
                    // ★2.0 第一波：切 tab 淡入
                    child: FadeTransition(opacity: _fadeCtrl, child: IndexedStack(index: _tab, children: const [
                      ChatListPage(),
                      ShopPage(),
                      GamePage(),
                      UsPage(),
                    ])),
                  ),"""
assert old_stack in s, 'stack fail'
s = s.replace(old_stack, new_stack)

# 4. onTap 触发淡入
old_tap = """                onTap: (i) => setState(() {
                  HapticFeedback.selectionClick(); // ★点哪儿手感跟一下（iOS 上有效）
                  _tab = i;"""
new_tap = """                onTap: (i) => setState(() {
                  HapticFeedback.selectionClick(); // ★点哪儿手感跟一下（iOS 上有效）
                  if (i != _tab) _fadeCtrl.forward(from: 0); // 切页淡入
                  _tab = i;"""
assert old_tap in s, 'tap fail'
s = s.replace(old_tap, new_tap)

io.open(p, 'w', encoding='utf-8', newline='').write(s)
print('main.dart Tab 淡入完成')

# ============ C. chat.dart 发送触感 + shop.dart 购买触感 ============
p = r'C:\Users\xilisi\Doubao\chats\2026-09-27\new-chat\baona-app\lib\chat.dart'
s = io.open(p, encoding='utf-8').read()
old_send = """  void _send() {
    final t = _input.text.trim();
    if (t.isEmpty) return;"""
new_send = """  void _send() {
    final t = _input.text.trim();
    if (t.isEmpty) return;
    HapticFeedback.lightImpact(); // ★2.0 第一波：发送轻触感"""
assert old_send in s, 'chat send fail'
s = s.replace(old_send, new_send)
io.open(p, 'w', encoding='utf-8', newline='').write(s)
print('chat.dart 发送触感完成')

p = r'C:\Users\xilisi\Doubao\chats\2026-09-27\new-chat\baona-app\lib\shop.dart'
s = io.open(p, encoding='utf-8').read()
if 'HapticFeedback' not in s:
    old_imp = "import 'package:flutter/material.dart';"
    new_imp = "import 'package:flutter/material.dart';\nimport 'package:flutter/services.dart';"
    assert old_imp in s, 'shop services import fail'
    s = s.replace(old_imp, new_imp)
old_buy = """  Future<void> _buy(ShopItem it, {bool forHer = false}) async {"""
new_buy = """  Future<void> _buy(ShopItem it, {bool forHer = false}) async {
    HapticFeedback.mediumImpact(); // ★2.0 第一波：购买确认触感"""
assert old_buy in s, 'shop buy fail'
s = s.replace(old_buy, new_buy)
io.open(p, 'w', encoding='utf-8', newline='').write(s)
print('shop.dart 购买触感完成')
