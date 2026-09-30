# -*- coding: utf-8 -*-
import io

p = r'C:\Users\xilisi\Doubao\chats\2026-09-27\new-chat\baona-app\lib\douyin.dart'
s = io.open(p, encoding='utf-8').read()

old = """        // 顶部加载进度条
        ValueListenableBuilder<double>(
          valueListenable: _c.onProgress,
          builder: (c, v, _) {
            if (v >= 1 || v <= 0) return const SizedBox.shrink();
            return Positioned(
              top: MediaQuery.of(c).padding.top + 48,
              left: 0, right: 0,
              child: LinearProgressIndicator(
                value: v,
                minHeight: 2,
                backgroundColor: const Color(0x22FFFFFF),
                color: Colors.white,
              ),
            );
          },
        ),
      ]),
    );
  }
}"""
new = """      ]),
    );
  }
}"""
assert old in s, 'progress block fail'
s = s.replace(old, new, 1)
io.open(p, 'w', encoding='utf-8', newline='').write(s)
print('douyin.dart 去掉 onProgress OK')

# 复查没有其他 4.x 不支持 API
import re
bad = re.findall(r'\.onProgress|WebViewWidget|loadRequest|onWebResourceError', s)
print('关键 API 存在:', bad)
