# -*- coding: utf-8 -*-
# b42: 生成 App 图标（图二自拍）+ 改抖音 m.douyin.com
import io, os, re
from PIL import Image

# ============ 1. App 图标 ============
src = r'C:\Users\xilisi\Doubao\chats\2026-09-27\new-chat\baona-app\tools_fix\appicon-src.jpg'
appicon = r'C:\Users\xilisi\Doubao\chats\2026-09-27\new-chat\baona-app\ios\Runner\Assets.xcassets\AppIcon.appiconset'

im = Image.open(src).convert('RGB')  # jpg 无透明，iOS 图标不能带透明
w, h = im.size
# 居中裁正方形：以短边为边长，纵向居中取
side = min(w, h)
left = (w - side) // 2
top = int((h - side) * 0.42)  # 略偏上，把脸/上半身留进来（照片人偏上）
top = max(0, min(h - side, top))
im = im.crop((left, top, left + side, top + side))

master = im.resize((1024, 1024), Image.LANCZOS)
master.save(os.path.join(appicon, 'Icon-App-1024x1024@1x.png'))

# 解析所有尺寸：Icon-App-WxH@Sx.png -> px = W * S
pat = re.compile(r'Icon-App-(\d+)x(\d+)@(\d+)x\.png')
count = 0
for name in os.listdir(appicon):
    m = pat.match(name)
    if not m or name.startswith('Icon-App-1024'):
        continue
    w0, h0, scale = int(m.group(1)), int(m.group(2)), int(m.group(3))
    px = int(round(w0 * scale))
    im2 = master.resize((px, px), Image.LANCZOS)
    im2.save(os.path.join(appicon, name))
    count += 1
print(f'App 图标已生成：1024 主图 + {count} 个尺寸')

# ============ 2. douyin.dart：www -> m.douyin.com ============
p = r'C:\Users\xilisi\Doubao\chats\2026-09-27\new-chat\baona-app\lib\douyin.dart'
s = io.open(p, encoding='utf-8').read()
old = "..loadRequest(Uri.parse('https://www.douyin.com/'));"
new = "..loadRequest(Uri.parse('https://m.douyin.com/')); // ★m 站=手机网页版，直接刷视频；www 站会引导下载App"
assert old in s, 'url fail'
s = s.replace(old, new, 1)
io.open(p, 'w', encoding='utf-8', newline='').write(s)
print('douyin.dart 改 m.douyin.com OK')
