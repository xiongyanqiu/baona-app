// alib.dart — 包娜 App v27.0.14.11 音频区：本地音频库
// 设计：iOS 27 Liquid Glass（半透明玻璃卡片，壁纸透出）
// 内容：音频文件存在 App 本地 documents/audio/，列表播放（audioplayers）
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'main.dart';
import 'theme.dart';

/// 音频区：本地音频库
class AudioLibPage extends StatefulWidget {
  const AudioLibPage({super.key});
  @override
  State<AudioLibPage> createState() => _AudioLibPageState();
}

class _AudioLibPageState extends State<AudioLibPage> {
  final AudioPlayer _ap = AudioPlayer();
  List<File> _files = [];
  bool _loaded = false;
  String _now = ''; // 正在播放的文件路径

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ap.dispose();
    super.dispose();
  }

  Future<Directory> _dir() async {
    final d = await getApplicationDocumentsDirectory();
    final a = Directory('${d.path}/audio');
    if (!await a.exists()) await a.create(recursive: true);
    return a;
  }

  Future<void> _load() async {
    try {
      final a = await _dir();
      final fs = await a.list().where((e) {
        final p = e.path.toLowerCase();
        return e is File &&
            (p.endsWith('.mp3') ||
                p.endsWith('.wav') ||
                p.endsWith('.m4a') ||
                p.endsWith('.aac') ||
                p.endsWith('.flac') ||
                p.endsWith('.aiff') ||
                p.endsWith('.aif') ||
                p.endsWith('.ogg'));
      }).toList();
      fs.sort((x, y) => y.statSync().modified.compareTo(x.statSync().modified));
      if (!mounted) return;
      setState(() {
        _files = fs.cast<File>();
        _loaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  /// 添加：从文件选音频 → 复制到本地 audio/（aiff 也支持，文件选择器原生全类型）
  Future<void> _add() async {
    final r = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'wav', 'm4a', 'aac', 'flac', 'aiff', 'aif', 'ogg'],
    );
    if (r == null || r.files.isEmpty) return;
    final f = r.files.first;
    final src = File(f.path ?? '');
    if (!await src.exists()) return;
    final a = await _dir();
    final dest = File('${a.path}/${DateTime.now().millisecondsSinceEpoch}_${f.name}');
    try {
      await src.copy(dest.path);
    } catch (_) {
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('已添加到音频库'), behavior: SnackBarBehavior.floating));
    _load();
  }

  /// 播放 / 暂停；切歌先停旧的
  Future<void> _play(String path) async {
    if (_now == path) {
      await _ap.stop();
      setState(() => _now = '');
      return;
    }
    await _ap.stop();
    try {
      await _ap.play(DeviceFileSource(path));
      setState(() => _now = path);
    } catch (_) {}
  }

  String _size(File f) {
    final kb = f.statSync().size / 1024;
    if (kb < 1024) return '${kb.round()} KB';
    return '${(kb / 1024).toStringAsFixed(1)} MB';
  }

  String _base(String p) {
    final n = p.split(Platform.pathSeparator).last;
    return n.length > 34 ? '${n.substring(0, 34)}…' : n;
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: EdgeInsets.fromLTRB(20, navSpace(context) - 30, 20, 10),
        child: Row(children: [
          const Expanded(
            child: Text('音频',
                style: TextStyle(
                    fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -0.6)),
          ),
          // 添加
          GestureDetector(
            onTap: _add,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: kAccent.withValues(alpha: 0.22),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0x26FFFFFF), width: 0.8),
              ),
              child: const Icon(Icons.add, size: 20, color: kText),
            ),
          ),
        ]),
      ),
      Expanded(
        child: !_loaded
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2.5))
            : _files.isEmpty
                ? _empty()
                : ListView.separated(
                    padding: EdgeInsets.fromLTRB(16, 4, 16, navSpace(context) + 16),
                    physics: const BouncingScrollPhysics(),
                    itemCount: _files.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (c, i) => _row(_files[i]),
                  ),
      ),
    ]);
  }

  Widget _row(File f) {
    final p = f.path;
    final playing = _now == p;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: kBg2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: playing ? kAccent.withValues(alpha: 0.5) : const Color(0x22FFFFFF),
            width: 0.8),
      ),
      child: Row(children: [
        // 播放/暂停
        GestureDetector(
          onTap: () => _play(p),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: playing ? kAccent : kAccent.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(
                playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                size: 24,
                color: playing ? Colors.white : kAccent),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_base(p),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: playing ? kAccent : kText)),
            const SizedBox(height: 3),
            Text(_size(f), style: const TextStyle(fontSize: 12, color: kSub)),
          ]),
        ),
        const Icon(Icons.music_note, size: 18, color: kSub),
      ]),
    );
  }

  Widget _empty() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: kAccent.withValues(alpha: 0.18),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.audiotrack_outlined, size: 30, color: kAccent),
        ),
        const SizedBox(height: 14),
        const Text('音频库还空着', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 5),
        const Text('点右上角「+」添加音频（mp3/wav/aiff 都行）',
            style: TextStyle(fontSize: 12.5, color: kSub)),
      ]),
    );
  }
}
