# -*- coding: utf-8 -*-
import io

p = r'C:\Users\xilisi\Doubao\chats\2026-09-27\new-chat\baona-app\lib\douyin.dart'
s = io.open(p, encoding='utf-8').read()

old = """  // ★模拟流视频源（全部 https 公开测试视频，iOS 可直接播；以后想换真实源改这里）
  static const List<Map<String, String>> _vids = [
    {
      'url': 'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
      'author': '@包娜',
      'desc': '你看这只蜜蜂，像不像我催你睡觉的样子🐝',
      'likes': '12.8万', 'comments': '386', 'shares': '1.2万',
      'music': '原声 - 包娜',
      'bg': '0xFF1F2430',
    },
    {
      'url': 'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4',
      'author': '@小蝴蝶',
      'desc': '慢一点，再慢一点，世界就安静了✨',
      'likes': '3.2万', 'comments': '98', 'shares': '2300',
      'music': '慢 - 轻音乐',
      'bg': '0xFF2B2130',
    },
    {
      'url': 'https://interactive-examples.mdn.mozilla.net/media/cc0-videos/flower.mp4',
      'author': '@花园日记',
      'desc': '春天开的第一朵花，送给你🌷',
      'likes': '8.7万', 'comments': '512', 'shares': '6400',
      'music': '原声 - 花园',
      'bg': '0xFF1F2A24',
    },
    {
      'url': 'https://media.w3.org/2010/05/sintel/trailer.mp4',
      'author': '@电影研究所',
      'desc': '这段预告片的每一帧都是壁纸🎬',
      'likes': '21.4万', 'comments': '1203', 'shares': '3.4万',
      'music': 'Sintel - Trailer',
      'bg': '0xFF1C1C28',
    },
    {
      'url': 'https://www.w3schools.com/html/mov_bbb.mp4',
      'author': '@大兔子',
      'desc': 'Big Buck Bunny 经典动画，治愈一下🥕',
      'likes': '5.5万', 'comments': '276', 'shares': '4100',
      'music': '原声 - 兔子',
      'bg': '0xFF24301F',
    },
  ];"""

new = """  // ★模拟流视频源 —— 2026-09-30 换成国内 CDN（西瓜视频/字节、百度），直连快；
  //   之前的 GitHub/MDN/W3C 是境外源，国内直连巨卡。以后想换真实源改这里就行
  static const List<Map<String, String>> _vids = [
    {
      'url': 'https://sf1-cdn-tos.huoshanstatic.com/obj/media-fe/xgplayer_doc_video/mp4/xgplayer-demo-360p.mp4',
      'author': '@包娜',
      'desc': '你看这朵云，像不像我催你睡觉的样子☁️',
      'likes': '12.8万', 'comments': '386', 'shares': '1.2万',
      'music': '原声 - 包娜',
      'bg': '0xFF1F2430',
    },
    {
      'url': 'https://bdcloud-player-new.cdn.bcebos.com/testvideo/mp4/360video/ThaiKongfu.mp4',
      'author': '@功夫熊猫',
      'desc': '中国功夫，你学会了吗🥋',
      'likes': '3.2万', 'comments': '98', 'shares': '2300',
      'music': '慢 - 武侠',
      'bg': '0xFF2B2130',
    },
    {
      'url': 'https://artplayer.org/assets/sample/video.mp4',
      'author': '@花园日记',
      'desc': '镜头里的一切都刚刚好🌷',
      'likes': '8.7万', 'comments': '512', 'shares': '6400',
      'music': '原声 - 花园',
      'bg': '0xFF1F2A24',
    },
    {
      'url': 'https://sf1-cdn-tos.huoshanstatic.com/obj/media-fe/xgplayer_doc_video/mp4/xgplayer-demo-360p.mp4',
      'author': '@深夜电台',
      'desc': '同一段画面，不同的心情。晚安🌙',
      'likes': '21.4万', 'comments': '1203', 'shares': '3.4万',
      'music': '晚安电台',
      'bg': '0xFF1C1C28',
    },
    {
      'url': 'https://bdcloud-player-new.cdn.bcebos.com/testvideo/mp4/360video/ThaiKongfu.mp4',
      'author': '@大兔子',
      'desc': '每天练一遍，神清气爽🥕',
      'likes': '5.5万', 'comments': '276', 'shares': '4100',
      'music': '原声 - 兔子',
      'bg': '0xFF24301F',
    },
  ];"""
assert old in s, 'vids fail'
s = s.replace(old, new)
io.open(p, 'w', encoding='utf-8', newline='').write(s)
print('视频源换成国内 CDN')
