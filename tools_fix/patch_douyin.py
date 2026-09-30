# -*- coding: utf-8 -*-
import io

# ============ 1. chatlist.dart：列表加抖音行 ============
p = r'C:\Users\xilisi\Doubao\chats\2026-09-27\new-chat\baona-app\lib\chatlist.dart'
s = io.open(p, encoding='utf-8').read()

# 1a. import
old = """import 'api.dart';"""
new = """import 'api.dart';
import 'douyin.dart';"""
assert old in s, 'import fail'
s = s.replace(old, new)

# 1b. 列表数据：包娜下面加抖音行
old2 = """        final chats = _loaded
            ? [
                {
                  'id': 'baona',
                  'name': app.nick,
                  'avatar': '${app.herSet['herAvatar'] ?? ''}',
                  'last': _last,
                  'lastT': _lastT,
                  'unread': app.unread,
                },
              ]
            : <Map<String, dynamic>>[];"""
new2 = """        final chats = _loaded
            ? [
                {
                  'id': 'baona',
                  'name': app.nick,
                  'avatar': '${app.herSet['herAvatar'] ?? ''}',
                  'last': _last,
                  'lastT': _lastT,
                  'unread': app.unread,
                },
                // ★2026-09-30：抖音入口 —— 点进去是全屏抖音风格短视频页（模拟源）
                {
                  'id': 'douyin',
                  'name': '抖音',
                  'avatar': '',
                  'last': '点进来刷会儿视频～',
                  'lastT': 0,
                  'unread': 0,
                },
              ]
            : <Map<String, dynamic>>[];"""
assert old2 in s, 'rows fail'
s = s.replace(old2, new2)

# 1c. _row：路由 + 抖音头像
old3 = """  Widget _row(Map<String, dynamic> c) {
    final av = '${c['avatar'] ?? ''}';
    final unread = (c['unread'] as int?) ?? 0;
    return InkWell(
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const ConversationPage())),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(children: [
          // 头像 + 未读红点
          Stack(clipBehavior: Clip.none, children: [
            av.isEmpty
                ? Container(
                    width: 52,
                    height: 52,
                    decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [kAccent, kAccent2])),
                    child: const Center(child: Text('娜', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600))),
                  )
                : FutureBuilder<ImageProvider>("""
new3 = """  Widget _row(Map<String, dynamic> c) {
    final id = '${c['id'] ?? 'baona'}';
    final av = '${c['avatar'] ?? ''}';
    final unread = (c['unread'] as int?) ?? 0;
    return InkWell(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => id == 'douyin' ? const DouyinPage() : const ConversationPage())),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(children: [
          // 头像 + 未读红点
          Stack(clipBehavior: Clip.none, children: [
            if (id == 'douyin')
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
            else if (av.isEmpty)
                Container(
                    width: 52,
                    height: 52,
                    decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [kAccent, kAccent2])),
                    child: const Center(child: Text('娜', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600))),
                  )
                else FutureBuilder<ImageProvider>("""
assert old3 in s, 'row fail'
s = s.replace(old3, new3)
io.open(p, 'w', encoding='utf-8', newline='').write(s)
print('chatlist 抖音行完成')

# ============ 2. pubspec.yaml：加 video_player ============
p2 = r'C:\Users\xilisi\Doubao\chats\2026-09-27\new-chat\baona-app\pubspec.yaml'
s2 = io.open(p2, encoding='utf-8').read()
old4 = """  flutter_local_notifications: ^18.0.1   # 消息通知（她发消息时手机弹出来）
  camera: ^0.12.1"""
new4 = """  flutter_local_notifications: ^18.0.1   # 消息通知（她发消息时手机弹出来）
  camera: ^0.12.1
  video_player: ^2.9.2                   # 抖音页视频播放"""
assert old4 in s2, 'pubspec fail'
s2 = s2.replace(old4, new4)
io.open(p2, 'w', encoding='utf-8', newline='').write(s2)
print('pubspec video_player 完成')
