# -*- coding: utf-8 -*-
import io

p = r'C:\Users\xilisi\Doubao\chats\2026-09-27\new-chat\baona-app\lib\theme.dart'
s = io.open(p, encoding='utf-8').read()

start = s.index('/// iOS 26 那种悬浮胶囊标签栏')
end = s.index('/* --------------------------------- 背景 --------------------------------- */')

new_glassnav = '''/// iOS 26 Liquid Glass 悬浮胶囊标签栏
/// 手指在底栏上左右拖：液态玻璃高亮片跟手滑动，松手吸附到最近 tab（发布会那个特效）
class GlassNav extends StatefulWidget {
  const GlassNav({super.key, required this.items, required this.index, required this.onTap});

  final List<Map<String, dynamic>> items; // [{'on': Icons.x, 'off': Icons.y, 't': '聊天'}]
  final int index;
  final ValueChanged<int> onTap;

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
                      child: PressScale(
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

'''

s = s[:start] + new_glassnav + s[end:]
io.open(p, 'w', encoding='utf-8', newline='').write(s)
print('GlassNav 跟手玻璃滑块完成')
