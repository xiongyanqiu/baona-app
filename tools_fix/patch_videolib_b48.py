# -*- coding: utf-8 -*-
import io

# 1) 新建独立视频库占位页
videolib = '''// 包娜 · 视频库（独立入口，与抖音无关）
// 占位页：等待老婆提供图标和用途后填充
import 'package:flutter/material.dart';

class VideoLibPage extends StatefulWidget {
  const VideoLibPage({super.key});
  @override
  State<VideoLibPage> createState() => _VideoLibPageState();
}

class _VideoLibPageState extends State<VideoLibPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      appBar: AppBar(
        backgroundColor: const Color(0xFF050505),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('视频库',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
      ),
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.video_library_rounded,
              color: Colors.white24, size: 64),
          const SizedBox(height: 16),
          const Text('视频库 · 建设中',
              style: TextStyle(color: Colors.white70, fontSize: 15)),
          const SizedBox(height: 8),
          const Text('等待图标和用途',
              style: TextStyle(color: Colors.white38, fontSize: 12.5)),
        ]),
      ),
    );
  }
}
'''
path_vl = r'C:\Users\xilisi\Doubao\chats\2026-09-27\new-chat\baona-app\lib\videolib.dart'
io.open(path_vl, 'w', encoding='utf-8', newline='').write(videolib)
print('videolib.dart 创建完成')

# 2) chatlist: videolib 不再打开 DouyinPage
path_cl = r'C:\Users\xilisi\Doubao\chats\2026-09-27\new-chat\baona-app\lib\chatlist.dart'
s = io.open(path_cl, encoding='utf-8').read()

old_tap = """      onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => (id == 'douyin' || id == 'videolib')
              ? const DouyinPage()
              : const ConversationPage())),"""
new_tap = """      onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => id == 'douyin'
              ? const DouyinPage()
              : id == 'videolib'
                  ? const VideoLibPage()
                  : const ConversationPage())),"""
assert old_tap in s, 'tap block not found'
s = s.replace(old_tap, new_tap)

# import videolib.dart
old_imp = """import 'theme.dart';"""
new_imp = """import 'theme.dart';
import 'videolib.dart';"""
assert old_imp in s, 'import not found'
s = s.replace(old_imp, new_imp)

io.open(path_cl, 'w', encoding='utf-8', newline='').write(s)
print('chatlist 已改为独立入口, len=', len(s))
