# -*- coding: utf-8 -*-
import io

p = r'C:\Users\xilisi\Doubao\chats\2026-09-27\new-chat\baona-app\lib\main.dart'
s = io.open(p, encoding='utf-8').read()

# 1. 类头部：去 SingleTickerProviderStateMixin，_fadeCtrl 换 PageController
old1 = """class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  int _tab = 0;
  bool _navHidden = false;
  double _lastPix = 0;
  // ★2.0 第一波：切 tab 淡入（保持各页状态，只是透明度过渡）
  late final AnimationController _fadeCtrl =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 230), value: 1);

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }"""
new1 = """class _HomePageState extends State<HomePage> {
  int _tab = 0;
  bool _navHidden = false;
  double _lastPix = 0;
  // ★2.0 第四波：页面换成 PageView —— 手指左右滑页面跟手走（iOS 26 Liquid Glass 标签栏规范）
  final PageController _pageCtrl = PageController();

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  /// 底栏点击 / 顶栏"我"：动画滑到目标页（页面滑动动画 + 底栏立即高亮）
  void _switchTab(int i) {
    if (i == _tab) return;
    setState(() {
      _tab = i;
      _navHidden = false;
      if (i == 0) app.unread = 0; // 进了聊天就没有小红点了
      app.chatVisible = (i == 0);
    });
    _pageCtrl.animateToPage(i,
        duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
  }"""
assert old1 in s, 'head fail'
s = s.replace(old1, new1)

# 2. 顶栏"我"走 _switchTab
old2 = "_Header(onSearch: () => openSearch(context), onSet: () => openSettings(context), onCtrl: () => openCtrl(context), onUs: () => setState(() => _tab = 3)),"
new2 = "_Header(onSearch: () => openSearch(context), onSet: () => openSettings(context), onCtrl: () => openCtrl(context), onUs: () => _switchTab(3)),"
assert old2 in s, 'header fail'
s = s.replace(old2, new2)

# 3. Expanded：FadeTransition+SlideTransition+IndexedStack → PageView
old3 = """                  Expanded(
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
new3 = """                  Expanded(
                    // ★2.0 第四波：PageView 左右滑动切换 —— 页面跟手走，才是 iOS 26 的标签栏
                    child: PageView(
                      controller: _pageCtrl,
                      physics: const BouncingScrollPhysics(),
                      onPageChanged: (i) {
                        if (i == _tab) return;
                        HapticFeedback.selectionClick(); // 翻页轻震
                        setState(() {
                          _tab = i;
                          _navHidden = false;
                          if (i == 0) app.unread = 0;
                          app.chatVisible = (i == 0);
                        });
                      },
                      children: const [
                        KeepAliveWrapper(child: ChatListPage()),
                        KeepAliveWrapper(child: ShopPage()),
                        KeepAliveWrapper(child: GamePage()),
                        KeepAliveWrapper(child: UsPage()),
                      ],
                    ),
                  ),"""
assert old3 in s, 'pageview fail'
s = s.replace(old3, new3)

# 4. 底栏点击走 _switchTab
old4 = """                onTap: (i) => setState(() {
                  HapticFeedback.selectionClick(); // ★点哪儿手感跟一下（iOS 上有效）
                  if (i != _tab) _fadeCtrl.forward(from: 0); // 切页淡入
                  _tab = i;
                  _navHidden = false;
                  if (i == 0) app.unread = 0; // 进了聊天就没有小红点了
                  app.chatVisible = (i == 0);
                }),"""
new4 = """                onTap: (i) {
                  HapticFeedback.selectionClick(); // ★点哪儿手感跟一下（iOS 上有效）
                  _switchTab(i);
                },"""
assert old4 in s, 'nav fail'
s = s.replace(old4, new4)

# 5. 文件末尾加 KeepAliveWrapper（追加在 _Nav 类之后）
old5 = """          {'off': Icons.favorite_border, 'on': Icons.favorite, 't': '我们'},
        ],
      );
}"""
new5 = """          {'off': Icons.favorite_border, 'on': Icons.favorite, 't': '我们'},
        ],
      );
}

/// ★2.0 第四波：PageView 里的页面保活（切走不销毁，回来还是原来的状态）
class KeepAliveWrapper extends StatefulWidget {
  const KeepAliveWrapper({super.key, required this.child});
  final Widget child;

  @override
  State<KeepAliveWrapper> createState() => _KeepAliveWrapperState();
}

class _KeepAliveWrapperState extends State<KeepAliveWrapper>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}"""
assert old5 in s, 'keepalive fail'
s = s.replace(old5, new5)

io.open(p, 'w', encoding='utf-8', newline='').write(s)
print('main.dart PageView 改造完成')
