// 包娜 App · 图片磁盘缓存 —— 根治"卡、烫、慢"
// ★2026-09-30 老公提的：总体太卡加载太慢。元凶=所有图片 Image.network 无磁盘缓存，
//   每次进页面/滑回来都重新从服务端下载 → 反复网络 + 反复解码 = 卡 + 烫 + 慢。
//   现在：第一次下载后存进应用支持目录，之后直接读本地文件，秒开且不耗网。
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class ImgCache {
  static Directory? _dir;

  static Future<Directory> _ensureDir() async {
    if (_dir != null) return _dir!;
    final d = await getApplicationSupportDirectory();
    _dir = Directory('${d.path}${Platform.pathSeparator}imgcache');
    if (!_dir!.existsSync()) {
      try {
        _dir!.createSync(recursive: true);
      } catch (_) {/* ignore */}
    }
    return _dir!;
  }

  static String _name(String url) {
    // url 本身做文件名（base64Url 去掉 = ），同 url 永远同一个文件
    return base64Url.encode(utf8.encode(url)).replaceAll('=', '');
  }

  static Future<File> _file(String url) async =>
      File('${(await _ensureDir()).path}${Platform.pathSeparator}${_name(url)}');

  /// 取一个可用的 ImageProvider：本地有缓存读本地，没有就下载并存盘
  /// [headers] 有的图要带鉴权头（比如表情 /api/emoji/xxx 要 x-wc-token）
  static Future<ImageProvider> provider(String url, {Map<String, String>? headers}) async {
    if (url.isEmpty) return _emptyImage();
    // ★data: 内嵌图（手机上传的头像）不走网络也不走盘，直接内存解码
    if (url.startsWith('data:')) {
      final i = url.indexOf(',');
      try {
        return MemoryImage(base64Decode(i >= 0 ? url.substring(i + 1) : url));
      } catch (_) {
        return _emptyImage();
      }
    }
    final f = await _file(url);
    try {
      if (await f.exists()) {
        final bytes = await f.readAsBytes();
        if (bytes.isNotEmpty) return MemoryImage(bytes);
      }
    } catch (_) {/* ignore */}
    try {
      final resp = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 20));
      if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
        try {
          await f.writeAsBytes(resp.bodyBytes);
        } catch (_) {/* 写盘失败不影响显示 */}
        return MemoryImage(resp.bodyBytes);
      }
    } catch (_) {/* ignore */}
    return NetworkImage(url); // 兜底交给系统
  }

  static MemoryImage _emptyImage() =>
      MemoryImage(base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=='));
}

/// 带磁盘缓存的图片组件，用法跟 Image.network 一样
class CacheImg extends StatelessWidget {
  const CacheImg(this.url,
      {super.key,
      this.width,
      this.height,
      this.fit = BoxFit.cover,
      this.radius,
      this.cacheWidth,
      this.headers});

  final String url;
  final double? width, height;
  final BoxFit fit;
  final BorderRadius? radius;
  final int? cacheWidth;
  final Map<String, String>? headers;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) return _ph;
    return FutureBuilder<ImageProvider>(
      future: ImgCache.provider(url, headers: headers),
      builder: (c, s) {
        Widget w;
        if (s.connectionState != ConnectionState.done || s.hasError || s.data == null) {
          w = _ph;
        } else {
          // ★Image 构造器没有 cacheWidth，缩略图用 ResizeImage 省内存
          final ip = cacheWidth != null ? ResizeImage(s.data!, width: cacheWidth) : s.data!;
          w = Image(
            image: ip,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (_, __, ___) => _ph,
          );
        }
        if (radius != null) w = ClipRRect(borderRadius: radius!, child: w);
        return w;
      },
    );
  }

  Widget get _ph => Container(width: width, height: height, color: const Color(0x14FFFFFF));
}
