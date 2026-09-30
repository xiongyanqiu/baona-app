# -*- coding: utf-8 -*-
import io

p = r'C:\Users\xilisi\Doubao\chats\2026-09-27\new-chat\baona-app\lib\main.dart'
s = io.open(p, encoding='utf-8').read()

# 1. 从 _BaonaAppState 的 dispose 移除误插的 _fadeCtrl.dispose()
old_bad = """  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _fadeCtrl.dispose();
    super.dispose();
  }"""
new_good = """  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }"""
assert old_bad in s, 'bad dispose fail'
s = s.replace(old_bad, new_good)

# 2. 在 _HomePageState 加正确的 dispose（插在 _onScroll 注释前）
old_scroll = """  /// ★下滑收起底栏：**聊天页不参与**（聊天时底栏要一直钉在那儿），只有商城/游戏/我们才收
  bool _onScroll(ScrollNotification n) {"""
new_scroll = """  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  /// ★下滑收起底栏：**聊天页不参与**（聊天时底栏要一直钉在那儿），只有商城/游戏/我们才收
  bool _onScroll(ScrollNotification n) {"""
assert old_scroll in s, 'scroll anchor fail'
s = s.replace(old_scroll, new_scroll)

io.open(p, 'w', encoding='utf-8', newline='').write(s)
print('dispose 位置已修复')
