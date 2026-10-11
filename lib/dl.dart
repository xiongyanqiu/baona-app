// dl.dart — ★27.0.17 插件下载管理器（单例）
// 功能：队列下载、实时进度（百分比/速度/已下/总量）、断点续传、状态持久化、
//       下载完成回调给插件做安装（解压等）。一次只下一个，失败可重试。
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum DlStatus { idle, downloading, done, failed }

class DlTask {
  String id;          // 插件唯一 id：'voice-melo' | 'voice-zhll' | ...
  String title;
  String url;
  String savePath;    // 下载落盘完整路径
  int total;          // 总字节（0=未知）
  int downloaded;     // 已下载字节
  double speed;       // 字节/秒（估算）
  DlStatus status;
  String err;

  DlTask({
    required this.id,
    required this.title,
    required this.url,
    required this.savePath,
    this.total = 0,
    this.downloaded = 0,
    this.speed = 0,
    this.status = DlStatus.idle,
    this.err = '',
  });

  double get progress =>
      total > 0 ? math.min(1.0, downloaded / total) : 0.0;
  String get statusText {
    switch (status) {
      case DlStatus.idle:
        return total > 0 ? '${_mb(total)} · 点按下载' : '未下载';
      case DlStatus.downloading:
        final pct = (progress * 100).toStringAsFixed(0);
        final sp = speed > 0 ? '${(speed / 1048576).toStringAsFixed(1)}MB/s' : '';
        return '下载中 $pct% · ${_mb(downloaded)}/${_mb(total)}${sp.isNotEmpty ? ' · $sp' : ''}';
      case DlStatus.done:
        return '已就绪 ${_mb(total)}';
      case DlStatus.failed:
        return '下载失败 · 点按重试';
    }
  }

  static String _mb(int b) {
    if (b <= 0) return '0MB';
    final m = b / 1048576;
    return m >= 1 ? '${m.toStringAsFixed(0)}MB' : '${(b / 1024).toStringAsFixed(0)}KB';
  }
}

class DlManager extends ChangeNotifier {
  DlManager._();
  static DlManager? _i;
  static DlManager get i => _i ??= DlManager._();

  final Map<String, DlTask> _tasks = {};
  final List<String> _queue = []; // 等待队列（一次只下一个）
  bool _busy = false;
  String? _activeId;
  final Map<String, Future<void> Function(DlTask)> _installers = {}; // 插件安装回调

  DlTask? taskOf(String id) => _tasks[id];

  void register({
    required String id,
    required String title,
    required String url,
    required String savePath,
    required int total,
    required Future<void> Function(DlTask) installer,
  }) {
    _tasks[id] = DlTask(
        id: id, title: title, url: url, savePath: savePath, total: total);
    _installers[id] = installer;
    // 恢复断点：存在 .part 就从偏移续传
    final part = File('$savePath.part');
    if (part.existsSync()) {
      _tasks[id]!.downloaded = part.lengthSync();
    }
    notifyListeners();
  }

  /// 开始下载（已在下载/已完成则忽略）
  Future<void> start(String id) async {
    final t = _tasks[id];
    if (t == null) return;
    if (t.status == DlStatus.downloading || t.status == DlStatus.done) return;
    _queue.add(id);
    notifyListeners();
    if (!_busy) _pump();
  }

  Future<void> _pump() async {
    if (_busy) return;
    _busy = true;
    while (_queue.isNotEmpty) {
      final id = _queue.removeAt(0);
      await _download(id);
    }
    _busy = false;
    _activeId = null;
  }

  Future<void> _download(String id) async {
    final t = _tasks[id];
    if (t == null) return;
    _activeId = id;
    t.status = DlStatus.downloading;
    t.err = '';
    t.speed = 0;
    notifyListeners();
    try {
      final part = File('${t.savePath}.part');
      await part.parent.create(recursive: true);
      var offset = part.existsSync() ? part.lengthSync() : 0;
      if (offset > 0 && t.total > 0 && offset >= t.total) {
        // .part 已完整 → 直接进入安装
        offset = 0;
        await part.delete();
      }
      final req = http.Request('GET', Uri.parse(t.url));
      if (offset > 0) {
        req.headers['Range'] = 'bytes=$offset-';
      }
      final resp = await req.send().timeout(const Duration(seconds: 30));
      if (resp.statusCode != 200 && resp.statusCode != 206) {
        t.status = DlStatus.failed;
        t.err = 'HTTP ${resp.statusCode}';
        notifyListeners();
        return;
      }
      if (t.total == 0 && resp.contentLength != null) {
        t.total = offset + (resp.contentLength ?? 0);
      }
      final sink = part.openWrite(mode: FileMode.append);
      var last = DateTime.now();
      var lastBytes = offset;
      await for (final chunk in resp.stream) {
        sink.add(chunk);
        offset += chunk.length;
        t.downloaded = offset;
        final now = DateTime.now();
        if (now.difference(last).inMilliseconds >= 1000) {
          t.speed = (offset - lastBytes) /
              math.max(0.001, now.difference(last).inMilliseconds / 1000);
          last = now;
          lastBytes = offset;
          notifyListeners();
        }
      }
      await sink.close();
      t.downloaded = offset;
      t.speed = 0;
      notifyListeners();
      // 下载完成 → 校验 → 安装
      if (t.total > 0 && offset < t.total) {
        t.status = DlStatus.failed;
        t.err = '文件不完整';
        notifyListeners();
        return;
      }
      await part.rename('${t.savePath}'); // 从 .part 转正
      t.status = DlStatus.done;
      notifyListeners();
      // 持久化状态
      final sp = await SharedPreferences.getInstance();
      await sp.setString('dl.$id', 'done');
      // 安装（解压模型等）
      final installer = _installers[id];
      if (installer != null) {
        try {
          await installer(t);
        } catch (e) {
          t.err = '安装失败: $e';
        }
      }
      notifyListeners();
    } catch (e) {
      t.status = DlStatus.failed;
      t.err = e.toString();
      t.speed = 0;
      notifyListeners();
      final sp = await SharedPreferences.getInstance();
      await sp.setString('dl.$id', 'failed');
    }
    _activeId = null;
  }

  /// 从持久化恢复状态（App 启动时调用）
  static Future<void> restore() async {
    final sp = await SharedPreferences.getInstance();
    for (final t in i._tasks.values) {
      final st = sp.getString('dl.${t.id}');
      if (st == 'done' && File(t.savePath).existsSync()) {
        t.status = DlStatus.done;
        t.downloaded = t.total;
      }
    }
    i.notifyListeners();
  }
}
