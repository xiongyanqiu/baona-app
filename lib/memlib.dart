// memlib.dart — ★27.0.16.14 记忆管理页（A）
// 查看全部记忆 / 语义搜索 / 单条删除 / 置顶 / 导出备份 / 导入恢复
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'api.dart';
import 'brain.dart';
import 'embd.dart';
import 'main.dart';

class MemPage extends StatefulWidget {
  const MemPage({super.key});
  @override
  State<MemPage> createState() => _MemPageState();
}

class _MemPageState extends State<MemPage> {
  List<Map<String, dynamic>> _all = []; // 全量记忆（新→旧）
  List<Map<String, dynamic>> _shown = []; // 过滤后
  final TextEditingController _q = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final b = app.brain;
    if (b == null) return;
    final r = await b.memories();
    if (!mounted) return;
    setState(() {
      _all = ((r['items'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e)).toList();
      _applyFilter();
    });
  }

  void _applyFilter() {
    final q = _q.text.trim();
    if (q.isEmpty) {
      _shown = List.of(_all);
    } else {
      _shown = _all.where((m) => '${m['text']}'.toLowerCase().contains(q.toLowerCase())).toList();
    }
  }

  /// 语义搜索：模型就绪时按余弦相似度重排
  Future<void> _semanticSearch() async {
    final q = _q.text.trim();
    if (q.isEmpty) {
      setState(() => _applyFilter());
      return;
    }
    if (!Embd.ready) {
      setState(() => _applyFilter()); // 模型没好就用关键词
      return;
    }
    setState(() => _busy = true);
    try {
      final qv = await Embd.embed(q, query: true);
      if (qv == null) {
        setState(() {
          _applyFilter();
          _busy = false;
        });
        return;
      }
      final scored = <Map<String, dynamic>>[];
      for (final m in _all) {
        final mv = await Embd.embed('${m['text']}', query: false);
        final s = (mv == null) ? -1.0 : _cos(qv, mv);
        scored.add({...m, '_s': s});
      }
      scored.sort((a, b) {
        final sa = (a['_s'] as num?)?.toDouble() ?? -1;
        final sb = (b['_s'] as num?)?.toDouble() ?? -1;
        return sb.compareTo(sa);
      });
      final top = scored.where((m) => ((m['_s'] as num?)?.toDouble() ?? -1) >= 0.22).toList();
      if (!mounted) return;
      setState(() {
        _shown = (top.isEmpty ? scored : top).map((m) => Map<String, dynamic>.from(m)..remove('_s')).toList();
        _busy = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _applyFilter();
        _busy = false;
      });
    }
  }

  double _cos(List<double> a, List<double> b) {
    var dot = 0.0, na = 0.0, nb = 0.0;
    final n = math.min(a.length, b.length);
    for (var i = 0; i < n; i++) {
      dot += a[i] * b[i];
      na += a[i] * a[i];
      nb += b[i] * b[i];
    }
    if (na <= 0 || nb <= 0) return 0;
    return dot / (math.sqrt(na) * math.sqrt(nb));
  }

  Future<void> _del(Map<String, dynamic> m) async {
    final b = app.brain;
    if (b == null) return;
    await b.memoryRemove('${m['id']}');
    if (!mounted) return;
    setState(() {
      _all.removeWhere((x) => '${x['id']}' == '${m['id']}');
      _applyFilter();
    });
  }

  Future<void> _pin(Map<String, dynamic> m) async {
    final b = app.brain;
    if (b == null) return;
    final cur = (m['importance'] as num?)?.toDouble() ?? 5;
    await b.memoryPin('${m['id']}', pin: cur < 10);
    _load();
  }

  /// 导出：全量记忆 → .json 临时文件 → 系统分享（存文件/微信/备忘录）
  Future<void> _export() async {
    final b = app.brain;
    if (b == null) return;
    final r = await b.memoryExport();
    if (r['ok'] != true) return;
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/baona-memory-backup-${DateTime.now().millisecondsSinceEpoch}.json');
    await f.writeAsString(const JsonEncoder.withIndent('  ').convert({'app': 'baona', 'ver': r['ver'], 'exported': DateTime.now().toIso8601String(), 'items': r['items']}));
    try {
      await Share.shareXFiles([XFile(f.path, mimeType: 'application/json')], text: '包娜 记忆备份');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('分享失败：$e'), behavior: SnackBarBehavior.floating));
    }
  }

  /// 导入：选 .json → 合并进记忆库（id/文本去重）
  Future<void> _import() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final res = await FilePicker.platform.pickFiles(type: FileType.any);
      if (res == null || res.files.isEmpty) {
        if (mounted) setState(() => _busy = false);
        return;
      }
      final p = res.files.first.path;
      if (p == null) {
        if (mounted) setState(() => _busy = false);
        return;
      }
      final raw = await File(p).readAsString();
      final j = jsonDecode(raw);
      final items = (j is Map ? (j['items'] as List?) : j) ?? [];
      final b = app.brain;
      if (b == null) return;
      final r = await b.memoryImport(items);
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('导入完成：新增 ${r['added'] ?? 0} 条，现有 ${r['total'] ?? 0} 条'),
        behavior: SnackBarBehavior.floating,
      ));
      _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('导入失败：$e（要选备份的 .json 文件）'), behavior: SnackBarBehavior.floating));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: Text('记忆管理（${_all.length}）', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            tooltip: '导入备份',
            icon: const Icon(Icons.file_download_outlined),
            onPressed: _busy ? null : _import,
          ),
          IconButton(
            tooltip: '导出备份',
            icon: const Icon(Icons.ios_share),
            onPressed: _export,
          ),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: TextField(
            controller: _q,
            onChanged: (_) {
              if (Embd.ready) _semanticSearch(); else setState(_applyFilter);
            },
            decoration: InputDecoration(
              hintText: '搜记忆（有语义模型时按意思搜）',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _busy
                  ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)))
                  : IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () { _q.clear(); setState(_applyFilter); }),
              isDense: true,
              filled: true,
              fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ),
        if (_shown.isEmpty)
          Expanded(child: Center(child: Text(_q.text.trim().isEmpty ? '还没有记忆\n聊天时她会慢慢记住你们的事' : '没搜到匹配的记忆', textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14))))
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
              itemCount: _shown.length,
              itemBuilder: (c, i) => _tile(c, _shown[i]),
            ),
          ),
      ]),
    );
  }

  Widget _tile(BuildContext c, Map<String, dynamic> m) {
    final cs = Theme.of(c).colorScheme;
    final type = '${m['type'] ?? ''}';
    final imp = (m['importance'] as num?)?.toDouble() ?? 5;
    final t = (m['t'] as num?)?.toInt() ?? 0;
    final time = t > 0 ? _fmt(DateTime.fromMillisecondsSinceEpoch(t)) : '';
    final label = type == 'summary' ? '摘要' : type == 'insight' ? '洞察' : '普通';
    final Color badge = type == 'summary' ? const Color(0xFF34C759) : type == 'insight' ? const Color(0xFFAF52DE) : cs.secondaryContainer;
    final Color badgeFg = type == 'summary' ? Colors.white : type == 'insight' ? Colors.white : cs.onSecondaryContainer;
    return Dismissible(
      key: ValueKey('${m['id']}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        margin: const EdgeInsets.symmetric(vertical: 3),
        decoration: BoxDecoration(color: const Color(0xFFFF3B30), borderRadius: BorderRadius.circular(14)),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => _del(m),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${m['text']}', style: TextStyle(fontSize: 14.5, height: 1.4, color: cs.onSurface)),
              const SizedBox(height: 5),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(color: badge, borderRadius: BorderRadius.circular(6)),
                  child: Text(label, style: TextStyle(fontSize: 10, color: badgeFg)),
                ),
                const SizedBox(width: 8),
                if (imp >= 8)
                  Row(children: [
                    Icon(Icons.star, size: 12, color: const Color(0xFFFFCC00)),
                    Text('重要', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                  ])
                else
                  Text('重要度 ${imp.toStringAsFixed(0)}', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                const Spacer(),
                Text(time, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
              ]),
            ]),
          ),
          IconButton(
            tooltip: imp >= 10 ? '取消置顶' : '置顶',
            icon: Icon(imp >= 10 ? Icons.push_pin : Icons.push_pin_outlined, size: 18, color: imp >= 10 ? const Color(0xFFFF9500) : cs.onSurfaceVariant),
            onPressed: () => _pin(m),
          ),
        ]),
      ),
    );
  }

  static String _fmt(DateTime d) {
    final now = DateTime.now();
    final sameDay = d.year == now.year && d.month == now.month && d.day == now.day;
    final hh = '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    if (sameDay) return hh;
    return '${d.month}月${d.day}日 $hh';
  }
}
