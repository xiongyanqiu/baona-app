// 包娜 · 抖音网页版
// 桌面 UA 打开 www.douyin.com 是完整网页版。iOS WKWebView 默认会把视频
// 拉进【系统全屏播放器】（不能上下滑换视频）→ 这里开内联播放 + 注入 JS
// 强制 playsinline，让视频在网页内播放，上下滑动可切换/滚动。
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

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
    // ★关键：iOS 允许网页内联播放视频，不再拉起系统全屏播放器
    final params = WebKitWebViewControllerCreationParams(
      allowsInlineMediaPlayback: true,
    );
    _wv = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(_desktopUA)
      ..setBackgroundColor(const Color(0xFF050505))
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() => _loading = true),
        onPageFinished: (_) {
          setState(() => _loading = false);
          _injectJs();
        },
      ))
      ..loadRequest(Uri.parse('https://www.douyin.com/'));
  }

  /// 强制所有 <video> 内联、禁止 webkit 全屏；上下滑 → 模拟滚轮切换/滚动
  Future<void> _injectJs() async {
    const js = '''
(function(){
  try{
    var fix=function(){
      document.querySelectorAll('video').forEach(function(v){
        v.setAttribute('playsinline','');
        v.setAttribute('webkit-playsinline','');
        v.addEventListener('webkitbeginfullscreen',function(e){
          e.preventDefault();
          try{ if(v.webkitExitFullscreen) v.webkitExitFullscreen(); }catch(_){}
        });
      });
    };
    fix();
    document.addEventListener('DOMNodeInserted',fix,false);
    var sy=0;
    document.addEventListener('touchstart',function(e){ sy=e.touches[0].clientY; },{passive:true});
    document.addEventListener('touchend',function(e){
      var dy=e.changedTouches[0].clientY-sy;
      if(Math.abs(dy)>40){
        var wd=dy<0?-160:160;
        var ev=new WheelEvent('wheel',{deltaY:wd,bubbles:true,cancelable:true});
        var t=document.querySelector('.video-player-base,.swiper,[data-e2e="feed-active-video"]')||document.elementFromPoint(e.changedTouches[0].clientX,e.changedTouches[0].clientY)||document;
        try{ t.dispatchEvent(ev); }catch(_){ window.dispatchEvent(new WheelEvent('wheel',{deltaY:wd,bubbles:true})); }
      }
    },{passive:true});
  }catch(e){}
})();
''';
    try { await _wv.runJavaScript(js); } catch (e) { /* ignore */ }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: Stack(children: [
        Positioned.fill(
          top: MediaQuery.of(context).padding.top,
          child: WebViewWidget(controller: _wv),
        ),
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
