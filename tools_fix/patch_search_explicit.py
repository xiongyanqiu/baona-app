# -*- coding: utf-8 -*-
import io

p = r'C:\Users\xilisi\Doubao\chats\2026-09-27\new-chat\baona-app\lib\sheets.dart'
s = io.open(p, encoding='utf-8').read()

old = """    // ★2026-09-30：键盘弹起时弹窗被顶到屏幕顶 → 搜索栏贴/撞状态栏。
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
new = """    // ★2026-09-30：键盘弹起时弹窗被顶到屏幕顶 → 搜索栏贴/撞状态栏。
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
        child: Column(children: ["""
assert old in s, 'search head fail'
s = s.replace(old, new)

old2 = """          ),
        ]),
        ),
      ),
    );
  }
}"""
new2 = """          ),
        ]),
      ),
    );
  }
}"""
assert old2 in s, 'search end fail'
s = s.replace(old2, new2)
io.open(p, 'w', encoding='utf-8', newline='').write(s)
print('搜索页显式安全区完成')
