// novel.dart — ★27.0.16.8 番茄小说（主页星辰圆环「小说」入口）
// 内置番茄小说网页版（fanqienovel.com），桌面 UA 打开完整网页版，可阅读/搜索/书架。
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import 'theme.dart';

class NovelPage extends StatefulWidget {
  const NovelPage({super.key});
  @override
  State<NovelPage> createState() => _NovelPageState();
}

class _NovelPageState extends State<NovelPage> {
  late final WebViewController _wv;
  bool _loading = true;

  /// 桌面 Chrome UA：手机 UA 会被识别成"没装 App"→ 引导下载
  static const String _desktopUA =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36';

  @override
  void initState() {
    super.initState();
    final params = WebKitWebViewControllerCreationParams(
      allowsInlineMediaPlayback: true,
    );
    _wv = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(_desktopUA)
      ..setBackgroundColor(const Color(0xFF0A0A0C))
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() => _loading = true),
        onPageFinished: (_) => setState(() => _loading = false),
      ))
      ..loadRequest(Uri.parse('https://fanqienovel.com/'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0C),
      body: Stack(children: [
        Positioned.fill(
          top: MediaQuery.of(context).padding.top,
          child: WebViewWidget(controller: _wv),
        ),
        // 顶栏：返回 + 标题
        Positioned(
          top: MediaQuery.of(context).padding.top + 4,
          left: 0,
          right: 0,
          child: Row(children: [
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0x33000000),
                  borderRadius: BorderRadius.circular(19),
                  border: Border.all(color: const Color(0x1AFFFFFF), width: 0.8),
                ),
                child: const Icon(Icons.arrow_back_ios_new, size: 17, color: kText),
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('番茄小说',
                  style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, color: kText, letterSpacing: -0.2)),
            ),
            const SizedBox(width: 48),
          ]),
        ),
        if (_loading)
          const Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4, color: kAccent),
              ),
            ),
          ),
      ]),
    );
  }
}
