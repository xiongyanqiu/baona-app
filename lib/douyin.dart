// 包娜 App · 抖音页（b40 手机直连版）
// ★不走电脑中转：手机内置抖音官方网页版，直连抖音服务器刷视频，
//   不受电脑端 / 蒲公英 2M 限速影响。官方页自带：推荐流（每次不一样）、
//   点赞、收藏、真手机号验证码登录抖音。
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class DouyinPage extends StatefulWidget {
  const DouyinPage({super.key});
  @override
  State<DouyinPage> createState() => _DouyinPageState();
}

class _DouyinPageState extends State<DouyinPage> {
  late final WebViewController _c;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF050505))
      ..setNavigationDelegate(NavigationDelegate(
        // 只有「真断网/找不到服务器」这类才提示重试；子资源（广告等）小错误不打扰
        onWebResourceError: (e) {
          const netErrs = {-1009, -1003, -1004, -1001, -1000, -102, -106};
          if (netErrs.contains(e.errorCode) && mounted) {
            setState(() => _failed = true);
          }
        },
      ))
      ..loadRequest(Uri.parse('https://www.douyin.com/'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: Stack(children: [
        Positioned.fill(
          child: _failed
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.wifi_off_rounded, color: Color(0xFF9AA0B4), size: 42),
                    const SizedBox(height: 12),
                    const Text('抖音没连上（检查网络）', style: TextStyle(color: Colors.white, fontSize: 15)),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: () {
                        setState(() => _failed = false);
                        _c.reload();
                      },
                      child: const Text('重试'),
                    ),
                  ]),
                )
              : WebViewWidget(controller: _c),
        ),
        // 顶部浮层：返回 + 抖音 + 刷新
        Positioned(
          top: 0, left: 0, right: 0,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xB3050505), Color(0x00050505)],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Row(children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                ),
                const Text('抖音',
                    style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
                const Spacer(),
                IconButton(
                  onPressed: () => _c.reload(),
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
                  tooltip: '刷新',
                ),
                const SizedBox(width: 8),
              ]),
            ),
          ),
        ),
        // 顶部加载进度条
        ValueListenableBuilder<double>(
          valueListenable: _c.onProgress,
          builder: (c, v, _) {
            if (v >= 1 || v <= 0) return const SizedBox.shrink();
            return Positioned(
              top: MediaQuery.of(c).padding.top + 48,
              left: 0, right: 0,
              child: LinearProgressIndicator(
                value: v,
                minHeight: 2,
                backgroundColor: const Color(0x22FFFFFF),
                color: Colors.white,
              ),
            );
          },
        ),
      ]),
    );
  }
}
