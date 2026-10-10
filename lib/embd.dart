// embd.dart — ★27.0.16.12 本地语义记忆检索（bge-small-zh fp32 512 维 @ flutter_onnxruntime）
// 完全离线：记忆向量在手机本地算、本地比，不联网不花钱。
// 检索协议：query 加 bge 官方指令前缀，passage（记忆条目）不加；取 [CLS] 向量（维度从 config.json hidden_size 读）。
// 模型 96MB fp32 超过 GitHub 100MB 单文件上限 → 仓库存 model.onnx.gz（54MB），首次运行解压到 Documents 缓存，之后直接加载。
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:path_provider/path_provider.dart';

class Embd {
  static OnnxRuntime? _ort;
  static OrtSession? _session;
  static Map<String, int>? _vocab;
  static int _clsId = 101;
  static int _sepId = 102;
  static int _unkId = 100;
  static int _dim = 512; // 向量维度：config.json hidden_size（small=512）
  static bool _ready = false;
  static bool _failed = false;

  /// 记忆指令前缀（bge-zh 官方：检索 query 要加，库内 passage 不加）
  static const String queryPrefix = '为这个句子生成表示以用于检索相关文章：';

  static bool get ready => _ready;

  /// 确保本地有可加载的 model.onnx：首次从 asset 的两个 .gz 分片拼接解压到 Documents，之后复用。
  static Future<String?> _ensureModelFile() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final target = File('${dir.path}/model.onnx');
      if (target.existsSync() && target.lengthSync() > 90000000) return target.path;
      final b1 = await rootBundle.load('assets/models/model.onnx.gz.part1');
      final b2 = await rootBundle.load('assets/models/model.onnx.gz.part2');
      final raw = Uint8List(b1.lengthInBytes + b2.lengthInBytes);
      raw.setAll(0, b1.buffer.asUint8List(b1.offsetInBytes, b1.lengthInBytes));
      raw.setAll(b1.lengthInBytes, b2.buffer.asUint8List(b2.offsetInBytes, b2.lengthInBytes));
      final uncompressed = gzip.decode(raw);
      await target.writeAsBytes(uncompressed, flush: true);
      return target.path;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> init() async {
    if (_ready) return true;
    if (_failed) return false;
    try {
      final modelPath = await _ensureModelFile();
      if (modelPath == null) {
        _failed = true;
        return false;
      }
      _ort = OnnxRuntime();
      _session = await _ort!.createSession(modelPath);
      final tj = jsonDecode(await rootBundle.loadString('assets/models/tokenizer.json'));
      final model = tj['model'];
      final v = model['vocab'];
      if (v is Map) {
        _vocab = v.map((k, val) => MapEntry('$k', (val as num).toInt()));
      } else if (v is List) {
        final vocab = <String, int>{};
        for (var i = 0; i < v.length; i++) {
          vocab['${v[i]}'] = i;
        }
        _vocab = vocab;
      }
      // special tokens 覆盖（added_tokens 里可能改了 id）
      final added = tj['added_tokens'];
      if (added is List) {
        for (final a in added) {
          if (a is Map) {
            final tok = '${a['content'] ?? ''}';
            final id = (a['id'] as num?)?.toInt();
            if (tok == '[CLS]') _clsId = id ?? _clsId;
            if (tok == '[SEP]') _sepId = id ?? _sepId;
            if (tok == '[UNK]') _unkId = id ?? _unkId;
          }
        }
      }
      if (_vocab == null || _vocab!.isEmpty) {
        _failed = true;
        return false;
      }
      // 向量维度：从 config.json 的 hidden_size 读（bge-small=512）
      try {
        final cfg = jsonDecode(await rootBundle.loadString('assets/models/config.json'));
        final hs = (cfg['hidden_size'] as num?)?.toInt();
        if (hs != null && hs > 0) _dim = hs;
      } catch (_) {}
      _ready = true;
      return true;
    } catch (_) {
      _failed = true;
      return false;
    }
  }

  /// 文本 → 归一化向量（维度=_dim，bge-base 768）。query=true 加检索指令前缀。失败返回 null（调用方降级 bigram）。
  static Future<Float32List?> embed(String text, {bool query = false}) async {
    if (!_ready && !await init()) return null;
    try {
      final input = query ? '$queryPrefix$text' : text;
      final ids = _tokenize(input);
      if (ids.length < 3) return null;
      final mask = List<int>.filled(ids.length, 1);
      final tti = List<int>.filled(ids.length, 0); // token_type_ids 必填（全 0）
      final inputs = <String, OrtValue>{
        'input_ids': await OrtValue.fromList(ids, [1, ids.length]),
        'attention_mask': await OrtValue.fromList(mask, [1, ids.length]),
        'token_type_ids': await OrtValue.fromList(tti, [1, ids.length]),
      };
      final out = await _session!.run(inputs);
      OrtValue? ov;
      for (final name in ['sentence_embedding', 'pooler_output', 'last_hidden_state', 'output', 'embedding']) {
        if (out.containsKey(name)) {
          ov = out[name];
          break;
        }
      }
      if (ov == null && out.isNotEmpty) ov = out.values.first;
      if (ov == null) return null;
      final arr = await ov.asList();
      final flat = <double>[];
      _flatten(arr, flat);
      if (flat.length < 128) return null;
      // [1,seq,dim] → 取第一行（CLS）= 前 _dim 个；[1,dim] pooled → 直接全用
      var vec = flat;
      if (flat.length > _dim) vec = flat.sublist(0, _dim);
      // 归一化
      var sum = 0.0;
      for (final v in vec) {
        sum += v * v;
      }
      final norm = sum <= 0 ? 1.0 : 1.0 / sqrt(sum);
      final outVec = Float32List(vec.length);
      for (var i = 0; i < vec.length; i++) {
        outVec[i] = vec[i] * norm;
      }
      return outVec;
    } catch (_) {
      return null;
    }
  }

  /// 余弦相似度（向量都是归一化的，直接点积）
  static double cos(Float32List a, Float32List b) {
    if (a.length != b.length) return 0;
    var s = 0.0;
    for (var i = 0; i < a.length; i++) {
      s += a[i] * b[i];
    }
    return s;
  }

  /// 向量 base64（存记忆条目）
  static String toB64(Float32List v) {
    final b = ByteData(v.length * 4);
    for (var i = 0; i < v.length; i++) {
      b.setFloat32(i * 4, v[i]);
    }
    return base64Encode(b.buffer.asUint8List());
  }

  static Float32List? fromB64(String s) {
    try {
      final bytes = base64Decode(s);
      if (bytes.length < 128 || bytes.length % 4 != 0) return null;
      final b = ByteData.sublistView(Uint8List.fromList(bytes));
      final out = Float32List(bytes.length ~/ 4);
      for (var i = 0; i < out.length; i++) {
        out[i] = b.getFloat32(i * 4);
      }
      return out;
    } catch (_) {
      return null;
    }
  }

  // ---------- tokenizer（BERT WordPiece，中文按字） ----------

  static List<int> _tokenize(String text, {int maxLen = 512}) {
    final clean = _clean(text);
    final ids = <int>[_clsId];
    final words = _splitWords(clean);
    for (final w in words) {
      if (ids.length >= maxLen - 1) break;
      final pieces = _wordPiece(w);
      if (pieces == null) {
        if (ids.length < maxLen - 1) ids.add(_unkId);
        continue;
      }
      for (final p in pieces) {
        if (ids.length >= maxLen - 1) break;
        ids.add(_vocab![p] ?? _unkId);
      }
    }
    ids.add(_sepId);
    return ids;
  }

  static String _clean(String s) {
    // 全角空白 → 半角；换行/制表 → 空格；连续空白压缩；小写（bge 英文词表是小写）
    final b = StringBuffer();
    var prevSpace = false;
    for (final ch in s.toLowerCase().runes) {
      final c = String.fromCharCode(ch);
      if (c == '\n' || c == '\r' || c == '\t' || c == '　' || c == ' ') {
        if (!prevSpace) b.write(' ');
        prevSpace = true;
      } else {
        b.write(c);
        prevSpace = false;
      }
    }
    return b.toString().trim();
  }

  /// 中文按单字、连续英文/数字按词（WordPiece 内部再切）
  static List<String> _splitWords(String s) {
    final out = <String>[];
    final buf = StringBuffer();
    void flush() {
      if (buf.isNotEmpty) {
        out.add(buf.toString());
        buf.clear();
      }
    }

    for (final ch in s.runes) {
      final c = String.fromCharCode(ch);
      final isWordChar = RegExp(r'[A-Za-z0-9]').hasMatch(c);
      if (isWordChar) {
        buf.write(c);
      } else {
        flush();
        out.add(c); // 中文标点/单字
      }
    }
    flush();
    return out;
  }

  /// WordPiece：整体命中 → 子词（##前缀），无任何命中返回 null（→ [UNK]）
  static List<String>? _wordPiece(String token) {
    if (_vocab!.containsKey(token)) return [token];
    final out = <String>[];
    var cur = token;
    while (cur.isNotEmpty) {
      var matched = false;
      for (var i = cur.length; i > 0; i--) {
        final sub = i == cur.length ? cur : '##${cur.substring(0, i)}';
        if (_vocab!.containsKey(sub)) {
          out.add(sub);
          cur = cur.substring(i);
          matched = true;
          break;
        }
      }
      if (!matched) return null;
    }
    return out;
  }

  static void _flatten(dynamic v, List<double> out) {
    if (v is List) {
      for (final e in v) {
        _flatten(e, out);
      }
    } else if (v is num) {
      out.add(v.toDouble());
    }
  }
}
