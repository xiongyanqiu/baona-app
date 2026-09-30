// 包娜 · 抖音网页版（b44）
// 抖音把手机 UA / WebView 全封（下载引导页），但桌面 UA 打开 www.douyin.com
// 是完整网页版（精选推荐流、可看视频）。
// 本页用 WebView + 桌面 UA 直连抖音官网：手机直连官方，不走电脑中转。
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class DouyinPage extends StatefulWidget {
  const DouyinPage({super.key});
  @override
  State<DouyinPage> createState() => _DouyinPageState();
}

class _DouyinPageState extends State<DouyinPage> {
  late final WebViewController _wv;
  bool _loading = true;

  /// 桌面 Chrome UA：手机 UA 会被抖音识别成"没装 App"→ 引导下载页
  static const String _desktopUA =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36';

  @override
  void initState() {
    super.initState();
    _wv = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(_desktopUA)
      ..setBackgroundColor(const Color(0xFF050505))
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() => _loading = true),
        onPageFinished: (_) => setState(() => _loading = false),
      ))
      ..loadRequest(Uri.parse('https://www.douyin.com/'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: Stack(children: [
        // 全屏网页（从状态栏下面开始，网页顶部导航不被刘海挡住/可点）
        Positioned.fill(
          top: MediaQuery.of(context).padding.top,
          child: WebViewWidget(controller: _wv),
        ),
        // 左上角小返回按钮（不遮挡网页顶部导航）
        Positioned(
          top: MediaQuery.of(context).padding.top + 4,
          left: 8,
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0x66000000),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 18),
            ),
          ),
        ),
        // 加载指示
        if (_loading)
          const Positioned(
            top: 100, left: 0, right: 0,
            child: Center(
              child: SizedBox(
                width: 26, height: 26,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              ),
            ),
          ),
      ]),
    );
  }
}
