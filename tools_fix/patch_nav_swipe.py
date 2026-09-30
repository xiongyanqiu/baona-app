# -*- coding: utf-8 -*-
import io

# theme.dart GlassNav：加横向滑动切换（iOS 26 Liquid Glass 标签栏规范）
p = r'C:\Users\xilisi\Doubao\chats\2026-09-27\new-chat\baona-app\lib\theme.dart'
s = io.open(p, encoding='utf-8').read()

old = """  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
          child: GlassSurface(
            radius: kRCapsule,
            blur: kBlur,
            pad: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Row("""
new = """  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
          // ★2.0 第三波：iOS 26 Liquid Glass 标签栏 —— 在底栏上左右滑动直接切 tab
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragEnd: (d) {
              final v = d.primaryVelocity ?? 0;
              if (v.abs() < 200) return; // 太轻不算
              final next = v < 0 ? index + 1 : index - 1; // 左滑下一个 / 右滑上一个
              if (next >= 0 && next < items.length) onTap(next);
            },
            child: GlassSurface(
            radius: kRCapsule,
            blur: kBlur,
            pad: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Row("""
assert old in s, 'glassnav gesture anchor fail'
s = s.replace(old, new)

# 补闭合：原 Row(...) 的结尾结构是 Row(children:[...]) 包在 GlassSurface 里，需要多一层 }) 闭合
# 原末尾结构：
#             child: Row(
#               children: [ ... ],
#             ),
#           ),
#         ),
#       );
# 现在 GestureDetector 包在 GlassSurface 外，GlassSurface 的结尾 ) 需要多加一个 }
old_end = """              ],
            ),
          ),
        ),
      );
}

/* --------------------------------- 背景 --------------------------------- */"""
new_end = """              ],
            ),
            ),
          ),
        ),
      );
}

/* --------------------------------- 背景 --------------------------------- */"""
assert old_end in s, 'glassnav end fail'
s = s.replace(old_end, new_end)
io.open(p, 'w', encoding='utf-8', newline='').write(s)
print('GlassNav 滑动切换完成')
