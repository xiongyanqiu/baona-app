# -*- coding: utf-8 -*-
import io

p = r'C:\Users\xilisi\Doubao\chats\2026-09-27\new-chat\baona-app\lib\sheets.dart'
s = io.open(p, encoding='utf-8').read()

# 1. openSearch：bottom sheet → 正常路由（opaque:false 淡入，全屏过渡，安全区才 100% 有效）
old1 = """/* ================================ 搜索 ================================ */
Future<void> openSearch(BuildContext context) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x8A000000),
    builder: (c) => const GlassSheet(child: _Search()),
  );
}"""
new1 = """/* ================================ 搜索 ================================ */
/// ★2026-09-30 v3：不玩 showModalBottomSheet 了 —— 键盘弹起时 sheet 被整体顶到屏幕顶，
///   内容安全区在 sheet 里不可靠。改成正常路由 + 显式 Positioned 定位，
///   顶部永远从状态栏下方开始、底部停在键盘上方，布局 100% 可控。
Future<void> openSearch(BuildContext context) async {
  await Navigator.of(context).push(PageRouteBuilder(
    transitionDuration: const Duration(milliseconds: 260),
    reverseTransitionDuration: const Duration(milliseconds: 200),
    opaque: false,
    pageBuilder: (_, __, ___) => const _Search(),
    transitionsBuilder: (_, a, __, child) =>
        FadeTransition(opacity: a, child: child),
  ));
}"""
assert old1 in s, 'openSearch fail'
s = s.replace(old1, new1)

# 2. _Search build：Stack + 遮罩 + 显式 Positioned 玻璃面板
old2 = """    // ★2026-09-30：键盘弹起时弹窗被顶到屏幕顶 → 搜索栏贴/撞状态栏。
    //   SafeArea 在 showModalBottomSheet 里不可靠 → 显式用 MediaQuery.padding 算安全区：
    //   顶部 padding = 状态栏+刘海高，高度 = 屏高 - 键盘高 - 顶部安全区，总高正好停在键盘上方
    final mq = MediaQuery.of(context);
    final kb = mq.viewInsets.bottom;
    final topPad = mq.padding.top;
    final sheetH = kb > 0 ? (mq.size.height - kb - topPad - 8) : mq.size.height * 0.8;
    return Padding(
      padding: EdgeInsets.fromLTRB(0, topPad, 0, kb),
      child: SizedBox(
        height: sheetH,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 10, 6),
            child: Row(children: [
              Expanded(child: TextField(autofocus: true, onChanged: (v) => setState(() => q = v), decoration: const InputDecoration(hintText: '搜你们的聊天记录…'))),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, size: 20)),
            ]),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(padding: const EdgeInsets.fromLTRB(14, 4, 14, 20), children: [
                    if (ql.isEmpty) const Padding(padding: EdgeInsets.only(top: 30), child: Center(child: Text('输入关键词搜聊天记录', style: TextStyle(color: kSub)))),
                    if (ql.isNotEmpty && hits.isEmpty) const Padding(padding: EdgeInsets.only(top: 30), child: Center(child: Text('没搜到～', style: TextStyle(color: kSub)))),
                    for (final m in hits) _Hit(m: m, q: q.trim()),
                  ]),
          ),
        ]),
      ),
    );
  }
}"""
new2 = """    // ★2026-09-30 v3：全屏路由 + 显式定位 —— 玻璃面板 top=状态栏下方，height 算好，
    //   键盘弹起时底部正好停在键盘上方，不再被 bottom sheet 顶飞
    final mq = MediaQuery.of(context);
    final kb = mq.viewInsets.bottom;
    final topPad = mq.padding.top;
    final sheetH = kb > 0 ? (mq.size.height - topPad - kb - 8) : mq.size.height * 0.8;
    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false, // 我们显式控制键盘，不用 Scaffold 自动缩
      body: Stack(children: [
        // 上半遮罩（点它关）
        Positioned.fill(
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const ColoredBox(color: Color(0x8A000000)),
          ),
        ),
        // 玻璃面板：顶部从状态栏下方开始，键盘弹起时底部停在键盘上方
        Positioned(
          top: topPad,
          left: 0,
          right: 0,
          height: sheetH,
          child: GlassSheet(
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 10, 6),
                child: Row(children: [
                  Expanded(child: TextField(autofocus: true, onChanged: (v) => setState(() => q = v), decoration: const InputDecoration(hintText: '搜你们的聊天记录…'))),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, size: 20)),
                ]),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView(padding: const EdgeInsets.fromLTRB(14, 4, 14, 20), children: [
                        if (ql.isEmpty) const Padding(padding: EdgeInsets.only(top: 30), child: Center(child: Text('输入关键词搜聊天记录', style: TextStyle(color: kSub)))),
                        if (ql.isNotEmpty && hits.isEmpty) const Padding(padding: EdgeInsets.only(top: 30), child: Center(child: Text('没搜到～', style: TextStyle(color: kSub)))),
                        for (final m in hits) _Hit(m: m, q: q.trim()),
                      ]),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}"""
assert old2 in s, 'search build fail'
s = s.replace(old2, new2)
io.open(p, 'w', encoding='utf-8', newline='').write(s)
print('搜索页 v3 全屏路由完成')
