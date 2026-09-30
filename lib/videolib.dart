// 包娜 · 视频库（独立入口，与抖音无关）
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
