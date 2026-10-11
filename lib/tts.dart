// tts.dart — ★27.0.17 本地真人语音引擎（sherpa-onnx VITS/MeloTTS，完全离线）
// 模型不再由本文件下载：统一走「插件中心」（plugins.dart + dl.dart）下载安装到
// Documents/tts/<melo|zhll>/，本文件只负责检查就绪 + 加载引擎 + 合成 wav。
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;
import 'api.dart' show Store;

/// 音色表：zhll 模型 5 个说话人（sid 0-4）+ melo 自然声（sid=0 表示 melo）
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

  /// 某模型是否已就绪（模型主体 + 配套文件都齐）
  static Future<bool> modelReady(String sub) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final base = '${dir.path}/tts/$sub';
      return File('$base/model.onnx').existsSync() &&
          File('$base/tokens.txt').existsSync() &&
          File('$base/lexicon.txt').existsSync() &&
          Directory('$base/dict').existsSync();
    } catch (_) {
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
      if (!await modelReady(sub)) {
        // 模型没下载：提示去插件中心，不标记失败（下载完可重试）
        status = 'missing';
        statusText = '语音模型未下载 · 去「插件中心」下载后点这里重试';
        return false;
      }
      if (!await _loadModel(sub)) {
        _failed = true;
        status = 'failed';
        statusText = '语音模型加载失败$_lastErr';
        return false;
      }
      status = 'ready';
      statusText = '真人语音就绪';
      return true;
    } catch (e) {
      _failed = true;
      status = 'failed';
      statusText = '语音模型加载失败：$e';
      return false;
    }
  }

  static String _lastErr = '';

  /// ★27.0.24 失败时输出文件体检表：每个核心文件的体积，一眼看出哪个坏/缺失
  static String _fileReport(String base) {
    final sb = StringBuffer();
    sb.writeln('文件体检:');
    try {
      final names = <String>[
        'model.onnx', 'tokens.txt', 'lexicon.txt',
      ];
      for (final n in names) {
        final f = File('$base/$n');
        sb.writeln('$n=${f.existsSync() ? f.lengthSync() : 0}B');
      }
      final dict = Directory('$base/dict');
      if (dict.existsSync()) {
        for (final n in ['jieba.dict.utf8', 'hmm_model.utf8', 'idf.utf8', 'user.dict.utf8', 'stop_words.utf8']) {
          final f = File('${dict.path}/$n');
          sb.writeln('dict/$n=${f.existsSync() ? f.lengthSync() : 0}B');
        }
      } else {
        sb.writeln('dict/ 目录缺失');
      }
      var nfst = 0;
      try {
        for (final e in Directory(base).listSync()) {
          if (e is File && e.path.endsWith('.fst')) {
            nfst++;
            sb.writeln('fst/${e.path.split('/').last}=${e.lengthSync()}B');
          }
        }
      } catch (_) {}
      if (nfst == 0) sb.writeln('无 .fst 规则文件');
    } catch (_) {}
    return sb.toString();
  }

  /// 重建 OfflineTts（切换 melo/zhll 模型时调用）
  static Future<bool> _loadModel(String sub) async {
    var base = '';
    try {
      _tts?.free();
      _tts = null;
      final dir = await getApplicationDocumentsDirectory();
      base = '${dir.path}/tts/$sub';
      if (!File('$base/model.onnx').existsSync() || !File('$base/tokens.txt').existsSync()) {
        _lastErr = '（模型文件不全）';
        return false;
      }
      final lexicon = File('$base/lexicon.txt').existsSync() ? '$base/lexicon.txt' : '';
      // 动态收集模型包里实际存在的规则 fst（不同模型包文件名可能不同，缺哪个传哪个）
      final fsts = <String>[];
      try {
        for (final f in Directory(base).listSync()) {
          if (f is File && f.path.endsWith('.fst')) fsts.add(f.path);
        }
      } catch (_) {}
      final vcfg = sherpa.OfflineTtsVitsModelConfig(
        model: '$base/model.onnx',
        tokens: '$base/tokens.txt',
        lexicon: lexicon,
        // ★27.0.25 根因修复：dataDir/dictDir 必须留空！
        //   sherpa-onnx v1.12.15+ 的 VITS Validate 会把非空 data_dir 当
        //   espeak-ng 数据目录检查（要求 data_dir/phontab、phonindex、
        //   phondata、intonations 存在），我们的 dict/ 是 jieba 词典目录，
        //   传了必失败（Failed to create offline tts. Please check your config）。
        //   zh-ll 走 CharacterLexicon、melo 走 MeloTtsLexicon，都只用
        //   lexicon + tokens，data_dir/dict_dir 不需要。
      );
      final cfg = sherpa.OfflineTtsConfig(
        model: sherpa.OfflineTtsModelConfig(vits: vcfg),
        ruleFsts: fsts.join(','),
      );
      final tts = sherpa.OfflineTts(cfg);
      _tts = tts;
      _numSpeakers = tts.numSpeakers;
      _currentModel = sub;
      _lastErr = '';
      return true;
    } catch (e) {
      _lastErr = '（引擎构造失败：$e）\n${_fileReport(base)}';
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
        // 切到另一个模型：必须已就绪，再重建引擎
        if (!await modelReady(model)) return null;
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
