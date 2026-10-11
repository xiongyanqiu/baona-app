// 包娜 App · 音频库（对话列表里、视频库下面）：手机本地音频，本地播放
// ★2026-10-01 v26.2.11 新增：音频只存手机本地（App 文档目录 al/），不走网络
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme.dart';

class AlAudio {
  AlAudio({required this.path, required this.name, required this.added, this.dur = 0});
  final String path;
  final String name;
  final int added;
  int dur; // 秒（播放时回填）
  factory AlAudio.fromJson(Map<String, dynamic> j) => AlAudio(
        path: j['path'] as String? ?? '',
        name: j['name'] as String? ?? '',
        added: (j['added'] as num?)?.toInt() ?? 0,
        dur: (j['dur'] as num?)?.toInt() ?? 0,
      );
  Map<String, dynamic> toJson() => {'path': path, 'name': name, 'added': added, 'dur': dur};
}

class AudioLibPage extends StatefulWidget {
  const AudioLibPage({super.key});
  @override
  State<AudioLibPage> createState() => _AudioLibPageState();
}

class _AudioLibPageState extends State<AudioLibPage> {
  static const _dbKey = 'al.db';
  static const _avKey = 'al.avatar';
  static const _nameKey = 'al.name';
  List<AlAudio> _tracks = [];
  bool _loaded = false;
  int? _playing; // 正在播放的 added
  final AudioPlayer _player = AudioPlayer();
  Duration _pos = Duration.zero;
  Duration _dur = Duration.zero;
  bool _playingNow = false;
  String _name = '包娜的音频库';
  String _avatar = '';
  Uint8List? _avatarBytes; // 头像解码缓存（防滑动重建闪烁）

  @override
  void initState() {
    super.initState();
    _load();
    // 播放进度/状态
    _player.onPositionChanged.listen((p) => setState(() => _pos = p));
    _player.onDurationChanged.listen((d) => setState(() => _dur = d));
    _player.onPlayerStateChanged.listen((s) {
      setState(() => _playingNow = s == PlayerState.playing);
      if (s == PlayerState.completed) setState(() => _pos = Duration.zero);
    });
  }

  @override
  void dispose() {
    _player.stop();
    _player.release();
    super.dispose();
  }

  Future<void> _load() async {
    final sp = await SharedPreferences.getInstance();
    try {
      final db = sp.getString(_dbKey) ?? '[]';
      final list = (jsonDecode(db) as List).cast<Map<String, dynamic>>();
      _tracks = list
          .map(AlAudio.fromJson)
          .where((a) => File(a.path).existsSync())
          .toList();
      // 时长没回填的补一下（读文件元数据太麻烦，播放时自然会回填）
    } catch (_) {
      _tracks = [];
    }
    _avatar = sp.getString(_avKey) ?? '';
    _avatarBytes = _decodeAvatar(_avatar);
    _name = sp.getString(_nameKey) ?? '包娜的音频库';
    if (mounted) setState(() => _loaded = true);
  }

  Uint8List? _decodeAvatar(String dataUrl) {
    if (!dataUrl.startsWith('data:image/')) return null;
    try {
      final b64 = dataUrl.substring(dataUrl.indexOf(',') + 1);
      return base64Decode(b64);
    } catch (_) {
      return null;
    }
  }

  /// 换头像：相册选图 → dataURL 存本地（对话列表头像同步）
  Future<void> _pickAvatar() async {
    final f = await ImagePicker().pickImage(
        source: ImageSource.gallery, maxWidth: 512, imageQuality: 80);
    if (f == null) return;
    final bytes = await f.readAsBytes();
    final dataUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}';
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_avKey, dataUrl);
    if (mounted) {
      setState(() {
        _avatar = dataUrl;
        _avatarBytes = _decodeAvatar(dataUrl);
      });
    }
  }

  /// 改名字：弹输入框 → 存本地（对话列表名字同步）
  Future<void> _rename() async {
    final ctl = TextEditingController(text: _name);
    final newName = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: kBg2,
        title: const Text('给音频库起个名字', style: TextStyle(color: kText)),
        content: TextField(
          controller: ctl,
          maxLength: 14,
          autofocus: true,
          style: const TextStyle(color: kText),
          decoration: const InputDecoration(hintText: '包娜的音频库', hintStyle: TextStyle(color: kSub)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('取消', style: TextStyle(color: kSub))),
          TextButton(onPressed: () => Navigator.pop(c, ctl.text.trim()), child: const Text('保存', style: TextStyle(color: kAccent2))),
        ],
      ),
    );
    if (newName == null || newName.isEmpty) return;
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_nameKey, newName);
    if (mounted) setState(() => _name = newName);
  }

  Future<void> _save() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_dbKey, jsonEncode(_tracks.map((a) => a.toJson()).toList()));
  }

  /// 从文件选音频 → 复制进 App 文档目录 al/ → 入库
  Future<void> _addAudio() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        // ★2026-10-02 加 aiff/aif：苹果的 AIFF 音频（Core Audio 原生支持，之前列表没有它所以根本选不了）
        allowedExtensions: ['mp3', 'wav', 'm4a', 'aac', 'flac', 'ogg', 'amr', 'wma', 'opus', 'caf', 'aiff', 'aif'],
        allowMultiple: false,
      );
      if (res == null || res.files.isEmpty) return;
      final f = res.files.first;
      final src = f.path;
      if (src == null || src.isEmpty) return;
      final dir = await getApplicationDocumentsDirectory();
      final alDir = Directory('${dir.path}/al');
      if (!alDir.existsSync()) alDir.createSync(recursive: true);
      final ts = DateTime.now().millisecondsSinceEpoch;
      final ext = src.contains('.') ? src.split('.').last.toLowerCase() : 'mp3';
      final target = '${alDir.path}/${ts}_al.$ext';
      await File(src).copy(target);
      final name = f.name.isEmpty ? '音频 ${ts % 100000}' : f.name;
      if (!mounted) return;
      setState(() {
        _tracks.add(AlAudio(path: target, name: name, added: ts));
        _playing = ts;
      });
      await _save();
      await _playTrack(_tracks.length - 1);
    } catch (_) {/* 取消/失败都不动 */}
  }

  Future<void> _playTrack(int index) async {
    if (index < 0 || index >= _tracks.length) return;
    final t = _tracks[index];
    if (_playing == t.added && _playingNow) {
      await _player.pause();
      return;
    }
    if (_playing != t.added) {
      await _player.stop();
      _pos = Duration.zero;
      _dur = Duration.zero;
      setState(() => _playing = t.added);
      try {
        // ★2026-10-02 修"音频播放不了"：play 时带 iOS 播放上下文（audioplayers 6.x 写法）——
        //   respectSilence=false = 静音键不吞声音；stayAwake=true = 锁屏继续放
        final _ctx = AudioContextConfig(respectSilence: false, stayAwake: true).build();
        await _player.play(DeviceFileSource(t.path), ctx: _ctx);
      } catch (_) {
        // 文件坏了或格式 iOS 播不了（比如 ogg/opus/wma）→ 给个明确提示，别无声无息
        setState(() => _playing = null);
        if (mounted) toast(context, '这个格式苹果播不了，换个 mp3/wav/aiff 试试');
      }
    } else {
      await _player.resume();
    }
  }

  Future<void> _deleteTrack(int index) async {
    final t = _tracks[index];
    final sure = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: kBg2,
        title: const Text('删掉这段音频？', style: TextStyle(color: kText)),
        content: Text('「${t.name}」会从手机上删掉，删了找不回来。', style: const TextStyle(color: kSub, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('不删', style: TextStyle(color: kSub))),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('删', style: TextStyle(color: Color(0xFFFF6B6B)))),
        ],
      ),
    );
    if (sure != true) return;
    if (_playing == t.added) {
      await _player.stop();
      _pos = Duration.zero;
      _dur = Duration.zero;
      _playing = null;
    }
    try {
      File(t.path).deleteSync();
    } catch (_) {/* ignore */}
    setState(() => _tracks.removeAt(index));
    await _save();
  }

  Future<void> _openPlayer(int index) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AudioPlayerPageV2(
        tracks: _tracks,
        initialIndex: index,
        title: _name,
        avatarBytes: _avatarBytes,
      ),
    ));
    if (mounted) setState(() {});
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _fmtSec(int sec) => _fmt(Duration(seconds: sec));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // 头：头像设置入口 + 标题（点一下改名） + 添加按钮
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Row(children: [
              // 头像设置入口（点一下换头像）
              GestureDetector(
                onTap: _pickAvatar,
                child: Stack(clipBehavior: Clip.none, children: [
                  _avatarCircle(30),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF2F6BFF),
                      ),
                      child: const Icon(Icons.photo_camera_rounded, color: Colors.white, size: 11),
                    ),
                  ),
                ]),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: _rename,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Flexible(
                        child: Text(_name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: kText)),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.edit_rounded, size: 14, color: kSub),
                    ]),
                    const Text('点名字可改名 · 点头像可换', style: TextStyle(fontSize: 11, color: kSub)),
                  ]),
                ),
              ),
              GestureDetector(
                onTap: _addAudio,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: kAccent.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(kRCapsule),
                    border: Border.all(color: kAccent.withOpacity(0.35)),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.add, size: 18, color: kAccent2),
                    SizedBox(width: 4),
                    Text('添加音频', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kAccent2)),
                  ]),
                ),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text('存在手机本地，随时能听', style: const TextStyle(fontSize: 12, color: kSub)),
          ),
          const SizedBox(height: 6),
          // 正在播放的进度条
          if (_playing != null && _dur > Duration.zero)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _dur.inMilliseconds > 0 ? (_pos.inMilliseconds / _dur.inMilliseconds).clamp(0.0, 1.0) : 0,
                  minHeight: 3,
                  backgroundColor: kGlass2,
                  valueColor: const AlwaysStoppedAnimation(kAccent),
                ),
              ),
            ),
          const SizedBox(height: 8),
          // 列表
          Expanded(
            child: !_loaded
                ? const Center(child: CircularProgressIndicator(color: kAccent))
                : _tracks.isEmpty
                    ? _empty()
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: _tracks.length,
                        itemBuilder: (c, i) => _row(i),
                      ),
          ),
        ]),
      ),
    );
  }

  Widget _empty() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: kGlass,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: kLine),
          ),
          child: const Icon(Icons.music_note_outlined, size: 34, color: kSub),
        ),
        const SizedBox(height: 14),
        const Text('还没有音频', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: kText)),
        const SizedBox(height: 6),
        const Text('点右上角「添加音频」\n把想听的音乐/语音放进来', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: kSub, height: 1.5)),
      ]),
    );
  }

  Widget _avatarCircle(double size) {
    final bytes = _avatarBytes;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(colors: [Color(0xFF7B2FFF), Color(0xFFC95BFF)]),
        image: bytes == null
            ? null
            : DecorationImage(image: MemoryImage(bytes), fit: BoxFit.cover),
      ),
      child: bytes == null
          ? const Icon(Icons.music_note_rounded, color: Colors.white, size: 16)
          : null,
    );
  }

  Widget _row(int index) {
    final t = _tracks[index];
    final isCur = _playing == t.added;
    final active = isCur && _playingNow;
    return GestureDetector(
      onTap: () => _openPlayer(index),
      onLongPress: () => _deleteTrack(index),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isCur ? kAccent.withOpacity(0.12) : kGlass,
          borderRadius: BorderRadius.circular(kRCell),
          border: Border.all(color: isCur ? kAccent.withOpacity(0.3) : kLine),
        ),
        child: Row(children: [
          // 播放/暂停
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isCur ? kAccent : kGlass2,
              shape: BoxShape.circle,
            ),
            child: Icon(
              active ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: isCur ? kText : kAccent2,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          // 名称
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                t.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isCur ? kText : Colors.white.withOpacity(0.92)),
              ),
              const SizedBox(height: 3),
              Text(
                t.dur > 0 ? '时长 ${_fmtSec(t.dur)} · 长按可删除' : '长按可删除',
                style: const TextStyle(fontSize: 11, color: kSub),
              ),
            ]),
          ),
          // 进度（当前播放）
          if (isCur && _dur > Duration.zero)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text('${_fmt(_pos)} / ${_fmt(_dur)}', style: const TextStyle(fontSize: 11, color: kAccent2)),
            ),
        ]),
      ),
    );
  }
}

/// ★27.0.23 完整播放器页面：进度可拖、上一首/下一首、快进快退、倍速、自动连播
class AudioPlayerPageV2 extends StatefulWidget {
  final List<AlAudio> tracks;
  final int initialIndex;
  final String title;
  final Uint8List? avatarBytes;
  const AudioPlayerPageV2({
    super.key,
    required this.tracks,
    required this.initialIndex,
    required this.title,
    this.avatarBytes,
  });

  @override
  State<AudioPlayerPageV2> createState() => _AudioPlayerPageV2State();
}

class _AudioPlayerPageV2State extends State<AudioPlayerPageV2> {
  final AudioPlayer _player = AudioPlayer();
  late int _idx;
  Duration _pos = Duration.zero;
  Duration _dur = Duration.zero;
  bool _playing = false;
  bool _dragging = false;
  double _dragMs = 0;
  double _rate = 1.0;

  @override
  void initState() {
    super.initState();
    _idx = widget.initialIndex;
    _player.onPositionChanged.listen((p) {
      if (mounted && !_dragging) setState(() => _pos = p);
    });
    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _dur = d);
    });
    _player.onPlayerStateChanged.listen((s) {
      if (!mounted) return;
      setState(() => _playing = s == PlayerState.playing);
      if (s == PlayerState.completed) {
        // 自动连播下一首
        if (_idx < widget.tracks.length - 1) {
          _idx++;
          _playAt(_idx);
        } else {
          setState(() {
            _playing = false;
            _pos = Duration.zero;
          });
        }
      }
    });
    _playAt(_idx);
  }

  @override
  void dispose() {
    _player.stop();
    _player.release();
    super.dispose();
  }

  Future<void> _playAt(int i) async {
    if (i < 0 || i >= widget.tracks.length) return;
    final t = widget.tracks[i];
    await _player.stop();
    _pos = Duration.zero;
    _dur = Duration.zero;
    try {
      final ctx = AudioContextConfig(respectSilence: false, stayAwake: true).build();
      await _player.setPlaybackRate(_rate);
      await _player.play(DeviceFileSource(t.path), ctx: ctx);
      if (mounted) {
        setState(() {
          _idx = i;
          _playing = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _playing = false);
    }
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _player.pause();
      setState(() => _playing = false);
    } else {
      await _player.resume();
      setState(() => _playing = true);
    }
  }

  Future<void> _seek(Duration d) async {
    var t = d;
    if (t < Duration.zero) t = Duration.zero;
    if (_dur > Duration.zero && t > _dur) t = _dur;
    await _player.seek(t);
    if (mounted) setState(() => _pos = t);
  }

  Future<void> _setRate(double r) async {
    setState(() => _rate = r);
    await _player.setPlaybackRate(r);
  }

  String _curName() {
    final t = widget.tracks[_idx];
    return t.name.isEmpty ? '音频 ${t.added % 100000}' : t.name;
  }

  String _fmt(Duration d) {
    final h = d.inHours > 0 ? '${d.inHours}:' : '';
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$h$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final totalMs = _dur.inMilliseconds;
    final curMs = _dragging ? _dragMs : _pos.inMilliseconds.toDouble();
    final maxSec = totalMs > 0 ? totalMs / 1000.0 : 1.0;
    final curSec = (curMs / 1000.0).clamp(0.0, maxSec);
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Column(children: [
          // 顶栏
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Row(children: [
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: kGlass2,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.keyboard_arrow_down_rounded, size: 24, color: kText),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: kText)),
              ),
              const SizedBox(width: 50),
            ]),
          ),
          // 封面 + 曲名
          Expanded(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                width: 210,
                height: 210,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [kAccent.withValues(alpha: 0.5), kAccent.withValues(alpha: 0.12)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: const Color(0x2EFFFFFF), width: 1),
                  image: widget.avatarBytes == null
                      ? null
                      : DecorationImage(
                          image: MemoryImage(widget.avatarBytes!), fit: BoxFit.cover),
                ),
                child: widget.avatarBytes == null
                    ? Icon(Icons.audiotrack_rounded, size: 80, color: Colors.white.withValues(alpha: 0.9))
                    : null,
              ),
              const SizedBox(height: 26),
              Text(_curName(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: kText)),
              const SizedBox(height: 6),
              Text('${_idx + 1} / ${widget.tracks.length}',
                  style: const TextStyle(fontSize: 13, color: kSub)),
            ]),
          ),
          // 进度条
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
                ),
                child: Slider(
                  value: curSec,
                  max: maxSec,
                  onChangeStart: (_) => setState(() => _dragging = true),
                  onChanged: (v) => setState(() => _dragMs = v * 1000),
                  onChangeEnd: (v) {
                    setState(() {
                      _dragging = false;
                      _pos = Duration(milliseconds: (v * 1000).round());
                    });
                    _player.seek(Duration(milliseconds: (v * 1000).round()));
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(children: [
                  Text(_fmt(Duration(milliseconds: curMs.round())),
                      style: const TextStyle(fontSize: 12, color: kSub)),
                  const Spacer(),
                  Text(totalMs > 0 ? _fmt(_dur) : '--:--',
                      style: const TextStyle(fontSize: 12, color: kSub)),
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
                        color: _rate == r ? kAccent.withValues(alpha: 0.25) : kGlass2,
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
              const SizedBox(height: 14),
              // 控制排
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _ctl(Icons.replay_10_rounded, '后退 10 秒',
                    () => _seek(_pos - const Duration(seconds: 10))),
                const SizedBox(width: 36),
                GestureDetector(
                  onTap: _toggle,
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: kAccent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: kAccent.withValues(alpha: 0.35), blurRadius: 24, spreadRadius: 2),
                      ],
                    ),
                    child: Icon(_playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        size: 38, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 36),
                _ctl(Icons.forward_10_rounded, '前进 10 秒',
                    () => _seek(_pos + const Duration(seconds: 10))),
              ]),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _ctl(Icons.skip_previous_rounded, '上一首',
                    _idx > 0 ? () => _playAt(_idx - 1) : null),
                const SizedBox(width: 36),
                _ctl(Icons.skip_next_rounded, '下一首',
                    _idx < widget.tracks.length - 1 ? () => _playAt(_idx + 1) : null),
                const SizedBox(width: 36),
                _ctl(Icons.repeat_rounded, '自动连播', () {}),
              ]),
              const SizedBox(height: 16),
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
            color: kGlass2,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0x22FFFFFF), width: 0.8),
          ),
          child: Icon(icon, size: 26, color: onTap == null ? kSub.withValues(alpha: 0.4) : kText),
        ),
      ),
    );
  }
}
