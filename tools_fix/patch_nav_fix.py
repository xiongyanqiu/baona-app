# -*- coding: utf-8 -*-
import io

p = r'C:\Users\xilisi\Doubao\chats\2026-09-27\new-chat\baona-app\lib\main.dart'
s = io.open(p, encoding='utf-8').read()

# 1. 加 _firstScroll 字段
old1 = """  // ★2.0 第四波：页面换成 PageView —— 手指左右滑页面跟手走（iOS 26 Liquid Glass 标签栏规范）
  final PageController _pageCtrl = PageController();"""
new1 = """  // ★2.0 第四波：页面换成 PageView —— 手指左右滑页面跟手走（iOS 26 Liquid Glass 标签栏规范）
  final PageController _pageCtrl = PageController();
  bool _firstScroll = true; // ★切页后第一条滚动只校准位置，不误收起底栏（不然切回滚动中的页面底栏立刻消失）"""
assert old1 in s, 'field fail'
s = s.replace(old1, new1)

# 2. _switchTab：呼出底栏 + 重置校准
old2 = """    setState(() {
      _tab = i;
      _navHidden = false;
      if (i == 0) app.unread = 0; // 进了聊天就没有小红点了
      app.chatVisible = (i == 0);
    });"""
new2 = """    setState(() {
      _tab = i;
      _navHidden = false; // ★切页先让底栏出来，他不想看时自己往上滑才收
      _firstScroll = true; // 下一条滚动只校准位置，不碰底栏
      if (i == 0) app.unread = 0; // 进了聊天就没有小红点了
      app.chatVisible = (i == 0);
    });"""
assert old2 in s, 'switch fail'
s = s.replace(old2, new2)

# 3. onPageChanged：同样呼出 + 重置校准
old3 = """                        HapticFeedback.selectionClick(); // 翻页轻震
                        setState(() {
                          _tab = i;
                          _navHidden = false;
                          if (i == 0) app.unread = 0;
                          app.chatVisible = (i == 0);
                        });"""
new3 = """                        HapticFeedback.selectionClick(); // 翻页轻震
                        setState(() {
                          _tab = i;
                          _navHidden = false; // ★横滑切页底栏也是先出来
                          _firstScroll = true;
                          if (i == 0) app.unread = 0;
                          app.chatVisible = (i == 0);
                        });"""
assert old3 in s, 'onpage fail'
s = s.replace(old3, new3)

# 4. _onScroll：过滤横向(PageView)通知 + 首条校准
old4 = """    if (n is! ScrollUpdateNotification) return false;
    final p = n.metrics.pixels;
    final d = p - _lastPix;
    _lastPix = p;
    if (d > 8 && p > 60 && !_navHidden) {"""
new4 = """    if (n is! ScrollUpdateNotification) return false;
    // ★PageView 横向滑动(切页)的通知不碰底栏逻辑，别把 _lastPix 污染了
    if (n.metrics.axis != Axis.vertical) return false;
    final p = n.metrics.pixels;
    // 切页后第一条纵向通知只校准位置：无论新页面滚到哪，底栏都保持呼出，等他自己滑
    if (_firstScroll) {
      _firstScroll = false;
      _lastPix = p;
      return false;
    }
    final d = p - _lastPix;
    _lastPix = p;
    if (d > 8 && p > 60 && !_navHidden) {"""
assert old4 in s, 'scroll fail'
s = s.replace(old4, new4)

io.open(p, 'w', encoding='utf-8', newline='').write(s)
print('底栏收起逻辑修复完成')
