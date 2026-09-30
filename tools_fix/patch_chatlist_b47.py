# -*- coding: utf-8 -*-
import io

path = r'C:\Users\xilisi\Doubao\chats\2026-09-27\new-chat\baona-app\lib\chatlist.dart'
s = io.open(path, encoding='utf-8').read()

# 1) 列表加 videolib 条目（在 douyin 后面）
old_list = """                {
                  'id': 'douyin',
                  'name': '抖音',
                  'avatar': '',
                  'last': '点进来刷会儿视频～',
                  'lastT': 0,
                  'unread': 0,
                },
              ]"""
new_list = """                {
                  'id': 'douyin',
                  'name': '抖音',
                  'avatar': '',
                  'last': '点进来刷会儿视频～',
                  'lastT': 0,
                  'unread': 0,
                },
                // ★b47：肉便器包娜的视频库 —— 点进去是抖音网页版
                {
                  'id': 'videolib',
                  'name': '肉便器包娜的视频库',
                  'avatar': '',
                  'last': '点进来刷会儿视频～',
                  'lastT': 0,
                  'unread': 0,
                },
              ]"""
assert old_list in s, 'list block not found'
s = s.replace(old_list, new_list)

# 2) onTap 打开 DouyinPage
old_tap = """      onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => id == 'douyin' ? const DouyinPage() : const ConversationPage())),"""
new_tap = """      onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => (id == 'douyin' || id == 'videolib')
              ? const DouyinPage()
              : const ConversationPage())),"""
assert old_tap in s, 'tap block not found'
s = s.replace(old_tap, new_tap)

# 3) videolib 头像：深紫底 + 播放图标（与抖音黑底区分）
old_av = """            if (id == 'douyin')
              // 抖音头像：黑底 + 音符（近似 logo）
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF111318)),
                child: const Stack(alignment: Alignment.center, children: [
                  Icon(Icons.music_note, color: Color(0xFF39F2FF), size: 24),
                  Positioned(right: 13, bottom: 12, child: Icon(Icons.music_note, color: Color(0xFFFF3B5C), size: 12)),
                ]),
              )"""
new_av = """            if (id == 'douyin')
              // 抖音头像：黑底 + 音符（近似 logo）
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF111318)),
                child: const Stack(alignment: Alignment.center, children: [
                  Icon(Icons.music_note, color: Color(0xFF39F2FF), size: 24),
                  Positioned(right: 13, bottom: 12, child: Icon(Icons.music_note, color: Color(0xFFFF3B5C), size: 12)),
                ]),
              )
            else if (id == 'videolib')
              // 视频库头像：深紫底 + 播放三角
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [Color(0xFF7B2FFF), Color(0xFF2F6BFF)])),
                child: const Center(child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 26)),
              )"""
assert old_av in s, 'avatar block not found'
s = s.replace(old_av, new_av)

io.open(path, 'w', encoding='utf-8', newline='').write(s)
print('chatlist videolib patch ok, len=', len(s))
