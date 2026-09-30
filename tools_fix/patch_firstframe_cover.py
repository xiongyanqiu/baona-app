# -*- coding: utf-8 -*-
import io

path = r'C:\Users\xilisi\Doubao\chats\2026-09-27\new-chat\baona-app\lib\videolib.dart'
s = io.open(path, encoding='utf-8').read()

# _Cover：StatelessWidget → StatefulWidget，用 video_player 渲染视频首帧做封面
old = """/// 封面卡片：真实视频缩略图 + 底部渐变遮罩
class _Cover extends StatelessWidget {
  final VlVideo video;
  final bool cur;
  const _Cover({required this.video, required this.cur});

  String _fmt(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.month}/${d.day}';
  }

  @override
  Widget build(BuildContext context) {
    final grad = _catGrad[video.cat] ?? _catGrad['其他']!;
    final name = video.path.split('/').last;
    final hasThumb =
        video.thumb.isNotEmpty && File(video.thumb).existsSync();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: grad.last.withOpacity(cur ? 0.45 : 0.18),
            blurRadius: cur ? 28 : 12,
            spreadRadius: cur ? 2 : 0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(fit: StackFit.expand, children: [
          // 背景：真实缩略图 / 渐变回退
          hasThumb
              ? Image.file(File(video.thumb),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity)
              : Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: grad,
                    ),
                  ),
                ),"""
new = """/// 封面卡片：video_player 渲染视频首帧（不依赖缩略图插件，HEVC 等格式也能显示）+ 底部渐变遮罩
class _Cover extends StatefulWidget {
  final VlVideo video;
  final bool cur;
  const _Cover({super.key, required this.video, required this.cur});

  @override
  State<_Cover> createState() => _CoverState();
}

class _CoverState extends State<_Cover> {
  VideoPlayerController? _vc;
  bool _vcOk = false;
  bool _inited = false;

  @override
  void initState() {
    super.initState();
    // 非当前卡片延迟初始化，避免多个解码器同时启动卡顿
    if (widget.cur) {
      _init();
    } else {
      Future.delayed(const Duration(milliseconds: 250), _init);
    }
  }

  Future<void> _init() async {
    if (_inited) return;
    _inited = true;
    final vc = VideoPlayerController.file(File(widget.video.path));
    _vc = vc;
    try {
      await vc.initialize();
      await vc.seekTo(Duration.zero);
      if (mounted) setState(() => _vcOk = true);
    } catch (_) {}
  }

  @override
  void dispose() {
    _vc?.dispose();
    super.dispose();
  }

  String _fmt(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.month}/${d.day}';
  }

  @override
  Widget build(BuildContext context) {
    final video = widget.video;
    final cur = widget.cur;
    final grad = _catGrad[video.cat] ?? _catGrad['其他']!;
    final name = video.path.split('/').last;
    final hasThumb =
        video.thumb.isNotEmpty && File(video.thumb).existsSync();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: grad.last.withOpacity(cur ? 0.45 : 0.18),
            blurRadius: cur ? 28 : 12,
            spreadRadius: cur ? 2 : 0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(fit: StackFit.expand, children: [
          // 背景：已生成缩略图 → 缩略图；否则 video_player 首帧；再失败渐变
          hasThumb
              ? Image.file(File(video.thumb),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity)
              : _vcOk
                  ? Container(
                      color: Colors.black,
                      child: Center(child: VideoPlayer(_vc!)),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: grad,
                        ),
                      ),
                    ),"""
assert old in s, 'cover class'
s = s.replace(old, new)

# 底部信息部分原来用 video 变量，检查闭包引用（video/cur/grad/name 已在上文重定义，保持不变）
io.open(path, 'w', encoding='utf-8', newline='').write(s)
print('video-first-frame cover done, len=', len(s))
