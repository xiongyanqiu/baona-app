// alib.dart — 包娜 App v27.0.21 音频区：本地音频库 + 完整播放器页面
// 设计：iOS 27 Liquid Glass（半透明玻璃卡片，壁纸透出）
// 内容：音频文件存在 App 本地 documents/audio/，列表播放；点行进播放器页
//       （进度可拖、上一首/下一首、快进快退、倍速、自动连播）
import 'dart:async';
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
  Duration _pos = Duration.zero;
  Duration _dur = Duration.zero;

  @override
  void initState() {
    super.initState();
    _load();
    _ap.onPositionChanged.listen((d) {
      if (mounted) setState(() => _pos = d);
    });
    _ap.onDurationChanged.listen((d) {
      if (mounted) setState(() => _dur = d);
    });
    _ap.onPlayerComplete.listen((_) {
      // 列表页播放完自动下一首
      if (!mounted) return;
      final i = _files.indexWhere((f) => f.path == _now);
      if (i >= 0 && i < _files.length - 1) {
        _play(_files[i + 1].path, silentStop: false);
      } else {
        setState(() => _now = '');
      }
    });
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

  /// 添加：从文件选音频 → 复制到本地 audio/
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
  Future<void> _play(String path, {bool silentStop = true}) async {
    if (_now == path) {
      if (_ap.state == PlayerState.playing) {
        await _ap.pause();
      } else {
        await _ap.resume();
      }
      setState(() {});
      return;
    }
    if (silentStop) await _ap.stop();
    try {
      await _ap.play(DeviceFileSource(path));
      setState(() {
        _now = path;
        _pos = Duration.zero;
      });
    } catch (_) {}
  }

  /// 删除音频
  Future<void> _delete(String path) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kBg2,
        title: const Text('删除这段音频？', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('删除', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (_now == path) {
      await _ap.stop();
      setState(() => _now = '');
    }
    try {
      await File(path).delete();
    } catch (_) {}
    _load();
  }

  String _size(File f) {
    final kb = f.statSync().size / 1024;
    if (kb < 1024) return '${kb.round()} KB';
    return '${(kb / 1024).toStringAsFixed(1)} MB';
  }

  String _base(String p) {
    final n = p.split(Platform.pathSeparator).last;
    final dot = n.lastIndexOf('.');
    return dot > 0 ? n.substring(0, dot) : n;
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${d.inMinutes}:$m:$s';
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
    return GestureDetector(
      onTap: () => _openPlayer(p),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: kBg2,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: playing ? kAccent.withValues(alpha: 0.5) : const Color(0x22FFFFFF),
              width: 0.8),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
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
                    playing
                        ? (_ap.state == PlayerState.playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded)
                        : Icons.play_arrow_rounded,
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
            // 播放中的行显示当前进度
            if (playing)
              Text(_fmt(_pos),
                  style: const TextStyle(fontSize: 12, color: kAccent)),
            const SizedBox(width: 10),
            // 删除
            GestureDetector(
              onTap: () => _delete(p),
              child: const Icon(Icons.delete_outline_rounded, size: 18, color: kSub),
            ),
          ]),
          if (playing) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: _dur.inMilliseconds > 0
                    ? (_pos.inMilliseconds / _dur.inMilliseconds).clamp(0.0, 1.0)
                    : 0,
                minHeight: 3,
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                color: kAccent,
              ),
            ),
          ],
        ]),
      ),
    );
  }

  Future<void> _openPlayer(String path) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AudioPlayerPage(files: _files, initialPath: path),
      ),
    );
    if (mounted) setState(() {});
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

/// 播放器页面：进度可拖、上一首/下一首、快进快退、倍速、自动连播
class AudioPlayerPage extends StatefulWidget {
  final List<File> files;
  final String initialPath;
  const AudioPlayerPage({super.key, required this.files, required this.initialPath});

  @override
  State<AudioPlayerPage> createState() => _AudioPlayerPageState();
}

class _AudioPlayerPageState extends State<AudioPlayerPage> {
  final AudioPlayer _ap = AudioPlayer();
  late int _idx;
  Duration _pos = Duration.zero;
  Duration _dur = Duration.zero;
  bool _playing = false;
  double _rate = 1.0;
  bool _dragging = false;
  double _dragVal = 0;
  StreamSubscription<Duration>? _sPos;
  StreamSubscription<Duration>? _sDur;
  StreamSubscription<void>? _sEnd;

  @override
  void initState() {
    super.initState();
    _idx = widget.files.indexWhere((f) => f.path == widget.initialPath);
    if (_idx < 0) _idx = 0;
    _sPos = _ap.onPositionChanged.listen((d) {
      if (mounted && !_dragging) setState(() => _pos = d);
    });
    _sDur = _ap.onDurationChanged.listen((d) {
      if (mounted) setState(() => _dur = d);
    });
    _sEnd = _ap.onPlayerComplete.listen((_) {
      if (!mounted) return;
      if (_idx < widget.files.length - 1) {
        _idx++;
        _playAt(_idx);
      } else {
        setState(() {
          _playing = false;
          _pos = Duration.zero;
        });
      }
    });
    _playAt(_idx);
  }

  @override
  void dispose() {
    _sPos?.cancel();
    _sDur?.cancel();
    _sEnd?.cancel();
    _ap.dispose();
    super.dispose();
  }

  String _name() {
    final p = widget.files[_idx].path;
    final n = p.split(Platform.pathSeparator).last;
    final dot = n.lastIndexOf('.');
    return dot > 0 ? n.substring(0, dot) : n;
  }

  Future<void> _playAt(int i) async {
    if (i < 0 || i >= widget.files.length) return;
    await _ap.stop();
    try {
      await _ap.setPlaybackRate(_rate);
      await _ap.play(DeviceFileSource(widget.files[i].path));
      if (mounted) {
        setState(() {
          _idx = i;
          _playing = true;
          _pos = Duration.zero;
          _dur = Duration.zero;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _playing = false);
    }
  }

  Future<void> _toggle() async {
    if (!_playing) {
      await _ap.resume();
      setState(() => _playing = true);
    } else {
      await _ap.pause();
      setState(() => _playing = false);
    }
  }

  Future<void> _seek(Duration d) async {
    var t = d;
    if (t < Duration.zero) t = Duration.zero;
    if (_dur > Duration.zero && t > _dur) t = _dur;
    await _ap.seek(t);
    if (mounted) setState(() => _pos = t);
  }

  Future<void> _setRate(double r) async {
    setState(() => _rate = r);
    await _ap.setPlaybackRate(r);
  }

  String _fmt(Duration d) {
    final h = d.inHours > 0 ? '${d.inHours}:' : '';
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$h$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final total = _dur.inMilliseconds > 0 ? _dur : null;
    final curMs = _dragging
        ? _dragVal
        : (_pos.inMilliseconds.toDouble().clamp(0.0, total?.inMilliseconds.toDouble() ?? 1e12));
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Column(children: [
          // 顶栏：关闭 + 标题
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Row(children: [
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: kBg2,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.keyboard_arrow_down_rounded, size: 24, color: kText),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(_name(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 50),
            ]),
          ),
          const SizedBox(height: 8),
          // 曲目信息
          Expanded(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              // 封面（玻璃频谱卡片）
              Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [kAccent.withValues(alpha: 0.55), kAccent.withValues(alpha: 0.15)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: const Color(0x2EFFFFFF), width: 1),
                ),
                child: Icon(
                  Icons.audiotrack_rounded,
                  size: 84,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: 28),
              Text(_name(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text('${_idx + 1} / ${widget.files.length}',
                  style: TextStyle(fontSize: 13, color: kSub)),
            ]),
          ),
          // 进度
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(children: [
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 4,
                  activeTrackColor: kAccent,
                  inactiveTrackColor: Colors.white.withValues(alpha: 0.12),
                  thumbColor: kAccent,
                  overlayColor: kAccent.withValues(alpha: 0.15),
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                ),
                child: Slider(
                  value: (curMs / 1000).clamp(0.0, total?.inSeconds.toDouble() ?? 1).toDouble(),
                  max: total?.inSeconds.toDouble() ?? 1,
                  onChangeStart: (_) => setState(() => _dragging = true),
                  onChanged: (v) => setState(() => _dragVal = v * 1000),
                  onChangeEnd: (v) {
                    setState(() {
                      _dragging = false;
                      _pos = Duration(milliseconds: (v * 1000).round());
                    });
                    _ap.seek(Duration(milliseconds: (v * 1000).round()));
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(children: [
                  Text(_fmt(Duration(milliseconds: curMs.round())),
                      style: TextStyle(fontSize: 12, color: kSub)),
                  const Spacer(),
                  Text(total == null ? '--:--' : _fmt(total),
                      style: TextStyle(fontSize: 12, color: kSub)),
                ]),
              ),
              const SizedBox(height: 10),
              // 倍速
              Wrap(spacing: 8, children: [
                for (final r in [0.5, 1.0, 1.5, 2.0])
                  GestureDetector(
                    onTap: () => _setRate(r),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: _rate == r
                            ? kAccent.withValues(alpha: 0.25)
                            : kBg2,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: _rate == r
                                ? kAccent.withValues(alpha: 0.6)
                                : const Color(0x22FFFFFF),
                            width: 0.8),
                      ),
                      child: Text('${r}x',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _rate == r ? kAccent : kText)),
                    ),
                  ),
              ]),
              const SizedBox(height: 16),
              // 控制排：后退15 / 播放暂停 / 前进15
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _ctl(Icons.replay_10_rounded, '后退 10 秒', () => _seek(_pos - const Duration(seconds: 10))),
                const SizedBox(width: 36),
                GestureDetector(
                  onTap: _toggle,
                  child: Container(
                    width: 78,
                    height: 78,
                    decoration: BoxDecoration(
                      color: kAccent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: kAccent.withValues(alpha: 0.35), blurRadius: 24, spreadRadius: 2),
                      ],
                    ),
                    child: Icon(_playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        size: 40, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 36),
                _ctl(Icons.forward_10_rounded, '前进 10 秒', () => _seek(_pos + const Duration(seconds: 10))),
              ]),
              const SizedBox(height: 14),
              // 上一首 / 下一首
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _ctl(Icons.skip_previous_rounded, '上一首',
                    _idx > 0 ? () => _playAt(_idx - 1) : null),
                const SizedBox(width: 36),
                _ctl(Icons.skip_next_rounded, '下一首',
                    _idx < widget.files.length - 1 ? () => _playAt(_idx + 1) : null),
                const SizedBox(width: 36),
                _ctl(Icons.repeat_rounded, '播放完自动下一首', () {}),
              ]),
              const SizedBox(height: 20),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _ctl(IconData icon, String tooltip, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: tooltip,
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: kBg2,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0x22FFFFFF), width: 0.8),
          ),
          child: Icon(icon,
              size: 26,
              color: onTap == null ? kSub.withValues(alpha: 0.4) : kText),
        ),
      ),
    );
  }
}
