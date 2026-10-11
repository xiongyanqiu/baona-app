// tts.dart — ★27.0.16.16 本地真人语音引擎（sherpa-onnx VITS/MeloTTS，完全离线不联网）
// 模型：assets/models/tts/melo（MeloTTS 中文最自然，1 声）+ assets/models/tts/zhll（VITS 5 音色）
// 首次运行把 model.onnx 从 gz 分片解到 Documents，之后直接复用。
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;
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

  /// 首次运行：把两个模型的 model.onnx 从 assets 分片解到 Documents/tts/
  static Future<bool> _ensureModels() async {
    final dir = await getApplicationDocumentsDirectory();
    for (final sub in ['melo', 'zhll']) {
      final target = File('${dir.path}/tts/$sub/model.onnx');
      if (target.existsSync() && target.lengthSync() > 100000000) continue;
      final parts = <ByteData>[];
      for (var i = 1; i <= 10; i++) {
        try {
          parts.add(await rootBundle.load('assets/models/tts/$sub/model.onnx.gz.part$i'));
        } catch (_) {
          break;
        }
      }
      if (parts.isEmpty) return false;
      var total = 0;
      for (final b in parts) {
        total += b.lengthInBytes;
      }
      final raw = Uint8List(total);
      var off = 0;
      for (final b in parts) {
        raw.setAll(off, b.buffer.asUint8List(b.offsetInBytes, b.lengthInBytes));
        off += b.lengthInBytes;
      }
      final uncompressed = gzip.decode(raw);
      await target.parent.create(recursive: true);
      await target.writeAsBytes(uncompressed, flush: true);
    }
    return true;
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
    statusText = '加载真人语音模型…（首次较慢，之后秒开）';
    try {
      sherpa.initBindings(); // sherpa-onnx 每个用到它的 isolate 都要初始化绑定
      final ok = await _ensureModels();
      if (!ok) {
        _failed = true;
        status = 'failed';
        statusText = '语音模型加载失败（模型文件缺失）';
        return false;
      }
      final v = Store.voiceId == 'melo' ? 'melo' : 'zhll';
      if (!await _loadModel(v)) {
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

  /// 合成整句为 wav 文件，返回绝对路径；失败返回 null
  static Future<String?> speak(String text, {String voiceId = 'melo', double speed = 1.0}) async {
    try {
      if (_tts == null) {
        if (!await init()) return null;
      }
      final model = voiceId == 'melo' ? 'melo' : 'zhll';
      final sid = voiceId == 'melo' ? 0 : int.parse(voiceId.substring(4));
      if (_currentModel != model) {
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
