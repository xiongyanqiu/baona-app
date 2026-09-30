# -*- coding: utf-8 -*-
import io

p = r'C:\Users\xilisi\Doubao\chats\2026-09-27\new-chat\baona-app\lib\imgsrv.dart'
s = io.open(p, encoding='utf-8').read()

old = """/// 带磁盘缓存的图片组件，用法跟 Image.network 一样
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
}"""

new = """/// 带磁盘缓存的图片组件，用法跟 Image.network 一样
/// ★★2026-09-30：改成 StatefulWidget，future 在 initState 取一次存住——
///   之前每次 rebuild 都新建 Future，FutureBuilder 重置 → 图片闪回占位再显示（对话界面"闪"的元凶）
class CacheImg extends StatefulWidget {
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
  State<CacheImg> createState() => _CacheImgState();
}

class _CacheImgState extends State<CacheImg> {
  late Future<ImageProvider> _f = ImgCache.provider(widget.url, headers: widget.headers);

  @override
  void didUpdateWidget(CacheImg old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url) {
      _f = ImgCache.provider(widget.url, headers: widget.headers);
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.url, width = widget.width, height = widget.height,
        fit = widget.fit, radius = widget.radius, cacheWidth = widget.cacheWidth;
    if (url.isEmpty) return _ph;
    return FutureBuilder<ImageProvider>(
      future: _f,
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

  Widget get _ph => Container(width: widget.width, height: widget.height, color: const Color(0x14FFFFFF));
}"""
assert old in s, 'cacheimg fail'
s = s.replace(old, new)
io.open(p, 'w', encoding='utf-8', newline='').write(s)
print('CacheImg future 缓存完成')
