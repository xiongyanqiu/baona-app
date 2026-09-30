# -*- coding: utf-8 -*-
import io

p = r'C:\Users\xilisi\Doubao\chats\2026-09-27\new-chat\baona-app\lib\sheets.dart'
s = io.open(p, encoding='utf-8').read()

old = """  @override
  Widget build(BuildContext context) {
    final ql = q.trim().toLowerCase();
    final hits = ql.isEmpty ? <Msg>[] : _all.where((m) => m.content.toLowerCase().contains(ql)).toList().reversed.take(60).toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(children: ["""
new = """  @override
  Widget build(BuildContext context) {
    final ql = q.trim().toLowerCase();
    final hits = ql.isEmpty ? <Msg>[] : _all.where((m) => m.content.toLowerCase().contains(ql)).toList().reversed.take(60).toList();
    // ★2026-09-30：键盘弹起时弹窗被顶到屏幕顶 → 搜索栏贴/撞状态栏。
    //   修：SafeArea 保护顶部安全区 + 键盘弹起时高度自适应（刚好停在键盘上方）
    final mq = MediaQuery.of(context);
    final kb = mq.viewInsets.bottom;
    final sheetH = kb > 0 ? (mq.size.height - kb - 8) : mq.size.height * 0.8;
    return Padding(
      padding: EdgeInsets.only(bottom: kb),
      child: SafeArea(
        top: true,
        bottom: false,
        child: SizedBox(
        height: sheetH,
        child: Column(children: ["""
assert old in s, 'search head fail'
s = s.replace(old, new)

# 补闭合：原结构 Padding(SizedBox(Column(...))) 结尾是：
#         ]),
#       ),
#     );
# 现在多一层 SafeArea，需要多加一个 )
old2 = """          ),
        ]),
      ),
    );
  }
}

class _Hit extends StatelessWidget {"""
new2 = """          ),
        ]),
        ),
      ),
    );
  }
}

class _Hit extends StatelessWidget {"""
assert old2 in s, 'search end fail'
s = s.replace(old2, new2)
io.open(p, 'w', encoding='utf-8', newline='').write(s)
print('搜索页 SafeArea + 高度自适应完成')
