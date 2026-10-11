// tts.dart — ★27.0.16.16/17 本地真人语音引擎（sherpa-onnx VITS/MeloTTS，完全离线不联网）
// ★27.0.16.17 模型不再打包进 IPA（377MB 传不动）→ 首次用语音时 App 内下载（镜像 6MB/s，约半分钟）
// 下载一次永久本地；断网/失败自动退回 iOS 系统语音，不白屏不卡死。
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;
import 'package:http/http.dart' as http;
import 'package:archive/archive.dart';
import 'api.dart' show Store;

/// 音色表：zhll 模型 5 个说话人（sid 0-4）+ melo 自然声（sid=100 表示 melo）
class VoiceOption {
  final String id; // 'melo' | 'zhll0'..'zhll4'
  final String name;
  const VoiceOption(this.id, this.name);
  String get model => id == 'melo' ? 'melo' : 'zhll';
  int get sid => id == 'melo' ? 0 : int.parse(id.substring(4));
}

const kVoiceOptions = <VoiceOption>[
  VoiceOption('melo', '自然声（Melo）'),
  VoiceOption('zhll0', '苏樱雪'),
  VoiceOption('zhll1', '顾念'),
  VoiceOption('zhll2', '傅诗雨'),
  VoiceOption('zhll3', '冰娇'),
  VoiceOption('zhll4', '霸总'),
];

class LocalTts {
  static bool _ready = false;
  static bool _failed = false;
  static Future<bool>? _initFuture;
  static sherpa.OfflineTts? _tts;
  static String _currentModel = '';
  static int _numSpeakers = 0;
  static String status = 'idle';
  static String statusText = '未启动（打开语音回复后自动加载）';

  // 模型下载地址（ghfast.top 镜像加速，App 内不受浏览器安全拦截）
  static const String _mirror = 'https://ghfast.top/';
  static const Map<String, String> _urls = {
    'melo': 'https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/vits-melo-tts-zh_en.tar.bz2',
    'zhll': 'https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/sherpa-onnx-vits-zh-ll.tar.bz2',
  };

  /// 确保某个模型在本地：没有就从镜像下载并解压（下载一次，永久保留）
  static Future<bool> _ensureModel(String sub) async {
    final dir = await getApplicationDocumentsDirectory();
    final tdir = Directory('${dir.path}/tts/$sub');
    final target = File('${tdir.path}/model.onnx');
    if (target.existsSync() && target.lengthSync() > 100000000) return true;
    final nice = sub == 'melo' ? '自然声音色' : '角色音色';
    status = 'loading';
    statusText = '正在下载$nice模型（约${sub == 'melo' ? '160' : '115'}MB，首次需要）…';
    try {
      await tdir.create(recursive: true);
      final tmp = File('${tdir.path}/model.tar.bz2');
      final req = http.Request('GET', Uri.parse(_mirror + _urls[sub]!));
      final resp = await req.send().timeout(const Duration(seconds: 40));
      if (resp.statusCode != 200) return false;
      final total = resp.contentLength ?? 0;
      var got = 0;
      final sink = tmp.openWrite();
      await for (final chunk in resp.stream) {
        sink.add(chunk);
        got += chunk.length;
        if (total > 0 && got % (total ~/ 20) < 500000) {
          statusText = '正在下载$nice模型 ${(got * 100 / total).toStringAsFixed(0)}%';
        }
      }
      await sink.close();
      statusText = '正在解压语音模型…';
      final bytes = await tmp.readAsBytes();
      final bz2 = BZip2Decoder().decodeBytes(bytes);
      final tar = TarDecoder().decodeBytes(bz2);
      for (final f in tar.files) {
        if (!f.isFile) continue;
        final rel = f.name.split('/').skip(1).join('/');
        if (rel.isEmpty) continue;
        final out = File('${tdir.path}/$rel');
        await out.parent.create(recursive: true);
        await out.writeAsBytes(f.content as List<int>, flush: true);
      }
      try {
        await tmp.delete();
      } catch (_) {}
      return target.existsSync() && target.lengthSync() > 100000000;
    } catch (_) {
      statusText = '语音模型下载失败（检查网络后点这里重试）';
      return false;
    }
  }

  static Future<bool> init() async {
    if (_ready) return true;
    if (_failed) return false;
    if (_initFuture != null) return _initFuture!;
    final f = _doInit();
    _initFuture = f;
    final ok = await f;
    _initFuture = null;
    return ok;
  }

  static Future<bool> _doInit() async {
    status = 'loading';
    statusText = '加载真人语音引擎…';
    try {
      sherpa.initBindings(); // sherpa-onnx 每个用到它的 isolate 都要初始化绑定
      final sub = Store.voiceId == 'melo' ? 'melo' : 'zhll';
      final ok = await _ensureModel(sub);
      if (!ok) {
        _failed = true;
        status = 'failed';
        return false;
      }
      if (!await _loadModel(sub)) {
        _failed = true;
        status = 'failed';
        statusText = '语音模型加载失败';
        return false;
      }
      status = 'ready';
      statusText = '真人语音就绪';
      return true;
    } catch (_) {
      _failed = true;
      status = 'failed';
      statusText = '语音模型加载失败';
      return false;
    }
  }

  /// 重建 OfflineTts（切换 melo/zhll 模型时调用）
  static Future<bool> _loadModel(String sub) async {
    try {
      _tts?.free();
      _tts = null;
      final dir = await getApplicationDocumentsDirectory();
      final base = '${dir.path}/tts/$sub';
      final cfg = sherpa.OfflineTtsConfig(
        model: sherpa.OfflineTtsModelConfig(
          vits: sherpa.OfflineTtsVitsModelConfig(
            model: '$base/model.onnx',
            tokens: '$base/tokens.txt',
            lexicon: '$base/lexicon.txt',
            dataDir: '$base/dict',
          ),
        ),
        ruleFsts: '$base/date.fst,$base/number.fst,$base/phone.fst,$base/new_heteronym.fst',
      );
      final tts = sherpa.OfflineTts(cfg);
      _tts = tts;
      _numSpeakers = tts.numSpeakers;
      _currentModel = sub;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 合成整句为 wav 文件，返回绝对路径；失败返回 null（调用方自动退回系统语音）
  static Future<String?> speak(String text, {String voiceId = 'melo', double speed = 1.0}) async {
    try {
      if (_tts == null) {
        if (!await init()) return null;
      }
      final model = voiceId == 'melo' ? 'melo' : 'zhll';
      final sid = voiceId == 'melo' ? 0 : int.parse(voiceId.substring(4));
      if (_currentModel != model) {
        // 切到另一个模型：确保已下载，再重建引擎
        if (!await _ensureModel(model)) return null;
        if (!await _loadModel(model)) return null;
      }
      final audio = _tts!.generateWithConfig(
        text: text,
        config: sherpa.OfflineTtsGenerationConfig(sid: sid, speed: speed),
        onProgress: (_, __) => 1,
      );
      if (audio.samples.isEmpty) return null;
      final dir = await getApplicationDocumentsDirectory();
      final vdir = Directory('${dir.path}/voices');
      await vdir.create(recursive: true);
      final path = '${vdir.path}/v${DateTime.now().millisecondsSinceEpoch}.wav';
      final ok = sherpa.writeWave(
        filename: path,
        samples: audio.samples,
        sampleRate: audio.sampleRate,
      );
      return ok ? path : null;
    } catch (_) {
      return null;
    }
  }

  static void dispose() {
    try {
      _tts?.free();
    } catch (_) {}
    _tts = null;
  }
}
