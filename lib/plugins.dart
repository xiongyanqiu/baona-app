// plugins.dart — ★27.0.17 插件中心：可下载的功能包统一在这里安装/查看进度
// 第一批：真人语音模型（自然声 Melo / 角色音色 5 声）。以后壁纸包、书源、皮肤等都走这里。
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'dl.dart';
import 'theme.dart';

/// 注册语音模型插件（App 启动时调用一次）
Future<void> initPlugins() async {
  const mirror = 'https://ghfast.top/';
  const base = 'https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/';
  final dir = await getApplicationDocumentsDirectory();

  Future<void> installTar(String savePath, String sub) async {
    // 把下载好的 tar.bz2 解到 Documents/tts/<sub>/（全量文件，语音引擎必需）
    final tdir = Directory('${dir.path}/tts/$sub');
    await tdir.create(recursive: true);
    final bytes = await File(savePath).readAsBytes();
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
      await File(savePath).delete();
    } catch (_) {}
  }

  DlManager.i
    ..register(
      id: 'voice-melo',
      title: '自然声音色（Melo）',
      url: mirror + base + 'vits-melo-tts-zh_en.tar.bz2',
      savePath: '${dir.path}/tts_dl/melo.tar.bz2',
      total: 167006755,
      installer: (t) => installTar(t.savePath, 'melo'),
    )
    ..register(
      id: 'voice-zhll',
      title: '角色音色包（苏樱雪/顾念/傅诗雨/冰娇/霸总）',
      url: mirror + base + 'sherpa-onnx-vits-zh-ll.tar.bz2',
      savePath: '${dir.path}/tts_dl/zhll.tar.bz2',
      total: 118810709,
      installer: (t) => installTar(t.savePath, 'zhll'),
    );
  await DlManager.restore();
}

class PluginsPage extends StatefulWidget {
  const PluginsPage({super.key});
  @override
  State<PluginsPage> createState() => _PluginsPageState();
}

class _PluginsPageState extends State<PluginsPage> {
  @override
  void initState() {
    super.initState();
    DlManager.i.addListener(_refresh);
  }

  @override
  void dispose() {
    DlManager.i.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _tap(String id) async {
    final t = DlManager.i.taskOf(id);
    if (t == null) return;
    if (t.status == DlStatus.done) return;
    await DlManager.i.start(id);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final col = Theme.of(context).colorScheme;
    final melo = DlManager.i.taskOf('voice-melo');
    final zhll = DlManager.i.taskOf('voice-zhll');

    Widget row(String id, IconData icon, String title, String desc) {
      final t = DlManager.i.taskOf(id);
      if (t == null) return const SizedBox.shrink();
      final downloading = t.status == DlStatus.downloading;
      final done = t.status == DlStatus.done;
      final failed = t.status == DlStatus.failed;
      return ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: done
                ? col.primary.withOpacity(0.15)
                : col.secondaryContainer.withOpacity(0.9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon,
              color: done ? col.primary : col.onSecondaryContainer, size: 24),
        ),
        title: Text(title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(downloading ? t.statusText : desc,
                style: TextStyle(fontSize: 12.5, color: col.onSurfaceVariant)),
            if (downloading) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: t.progress,
                  minHeight: 5,
                  backgroundColor: col.surfaceContainerHighest,
                ),
              ),
            ],
          ],
        ),
        trailing: done
            ? Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: col.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('已就绪',
                    style: TextStyle(
                        fontSize: 12, color: col.primary, fontWeight: FontWeight.w600)),
              )
            : (failed
                ? Text('重试',
                    style: TextStyle(
                        fontSize: 14, color: col.primary, fontWeight: FontWeight.w600))
                : (downloading
                    ? Text('${(t.progress * 100).toStringAsFixed(0)}%',
                        style: TextStyle(fontSize: 14, color: col.primary))
                    : Text('下载',
                        style: TextStyle(
                            fontSize: 14, color: col.primary, fontWeight: FontWeight.w600)))),
        onTap: () => _tap(id),
      );
    }

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('插件中心',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 40),
        children: [
          _sectionHeader(context, '语音模型'),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: kBg2,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                row('voice-melo', Icons.record_voice_over_rounded,
                    '自然声音色（Melo）', '160MB · 最接近真人的自然女声'),
                Divider(height: 1, indent: 80, color: col.outlineVariant),
                row('voice-zhll', Icons.favorite_rounded, '角色音色包（5 种）',
                    '115MB · 苏樱雪 / 顾念 / 傅诗雨 / 冰娇 / 霸总'),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _sectionHeader(context, '即将上线'),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: kBg2,
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              leading: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: col.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.widgets_outlined,
                    color: col.onSurfaceVariant, size: 24),
              ),
              title: const Text('更多功能插件',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              subtitle: Text('壁纸包 / 番茄书源 / 桌宠皮肤…敬请期待',
                  style:
                      TextStyle(fontSize: 12.5, color: col.onSurfaceVariant)),
              trailing: Text('开发中',
                  style: TextStyle(fontSize: 13, color: col.outline)),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              '插件下载后可离线使用，一次下载永久保留；\n下载中断会自动续传，失败点按重试。',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: col.outline, height: 1.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
      child: Text(title,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurfaceVariant)),
    );
  }
}
