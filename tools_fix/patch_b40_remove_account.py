# -*- coding: utf-8 -*-
import io, re, os

# ============ 1. pubspec：flutter_inappwebview -> webview_flutter（官方稳定） ============
p = r'C:\Users\xilisi\Doubao\chats\2026-09-27\new-chat\baona-app\pubspec.yaml'
s = io.open(p, encoding='utf-8').read()
old = "  flutter_inappwebview: ^6.1.5           # ★b39 抖音手机直连（内置官方网页版，不走电脑中转）"
new = "  webview_flutter: ^4.10.0              # ★b40 抖音手机直连（内置官方网页版，不走电脑中转）"
assert old in s, 'pubspec dep fail'
s = s.replace(old, new, 1)
io.open(p, 'w', encoding='utf-8', newline='').write(s)
print('pubspec 换 webview_flutter OK')

# ============ 2. douyin.dart：重写为 webview_flutter ============
p2 = r'C:\Users\xilisi\Doubao\chats\2026-09-27\new-chat\baona-app\lib\douyin.dart'
new_content = '''// 包娜 App · 抖音页（b40 手机直连版）
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
'''
io.open(p2, 'w', encoding='utf-8', newline='').write(new_content)
print('douyin.dart 重写为 webview_flutter 版 OK')

# ============ 3. main.dart：Boot 去掉账号拦截 ============
p3 = r'C:\Users\xilisi\Doubao\chats\2026-09-27\new-chat\baona-app\lib\main.dart'
s3 = io.open(p3, encoding='utf-8').read()
old3 = """import 'api.dart';
import 'account_login.dart';
import 'chat.dart';"""
new3 = """import 'api.dart';
import 'chat.dart';"""
assert old3 in s3, 'main import fail'
s3 = s3.replace(old3, new3, 1)

old3b = """  @override
  Widget build(BuildContext context) {
    // ★b35 统一账号：没登录账号先去登录（整个 App 只认这一个账号）
    if (Store.accountToken.isEmpty) {
      return const AccountLoginPage();
    }
    final base = Store.baseUrl;"""
new3b = """  @override
  Widget build(BuildContext context) {
    final base = Store.baseUrl;"""
assert old3b in s3, 'main boot fail'
s3 = s3.replace(old3b, new3b, 1)
io.open(p3, 'w', encoding='utf-8', newline='').write(s3)
print('main.dart 去掉账号拦截 OK')

# ============ 4. sheets.dart：移除账号中心 + import ============
p4 = r'C:\Users\xilisi\Doubao\chats\2026-09-27\new-chat\baona-app\lib\sheets.dart'
s4 = io.open(p4, encoding='utf-8').read()
old4 = "import 'account_login.dart';\nimport 'api.dart';"
new4 = "import 'api.dart';"
assert old4 in s4, 'sheets import fail'
s4 = s4.replace(old4, new4, 1)

old4b = """        const Sec('账号中心'),
        RowTile(
          label: '当前账号',
          sub: Store.accountName.isEmpty ? '还没登录（去登录页注册/登录）' : '已登录：${Store.accountName}',
          hair: false,
          trail: Chip2('退出登录', ico: Icons.logout, on: () async {
            await Store.setAccountToken('');
            await Store.setAccountName('');
            if (!mounted) return;
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const AccountLoginPage()),
              (r) => false,
            );
          }),
        ),
        const Padding(
          padding: EdgeInsets.only(left: 4, top: 4),
          child: Text('账号存在你电脑端（手机号+密码），登录后抖音等所有功能共用这个账号。',
              style: TextStyle(fontSize: 11.5, color: kSub, height: 1.4)),
        ),

        const Sec('她的脑子（模型）'),"""
new4b = """        const Sec('她的脑子（模型）'),"""
assert old4b in s4, 'sheets account block fail'
s4 = s4.replace(old4b, new4b, 1)
io.open(p4, 'w', encoding='utf-8', newline='').write(s4)
print('sheets.dart 移除账号中心 OK')

# ============ 5. api.dart：删 accountToken/accountName ============
p5 = r'C:\Users\xilisi\Doubao\chats\2026-09-27\new-chat\baona-app\lib\api.dart'
s5 = io.open(p5, encoding='utf-8').read()
old5 = """  static Future<void> setPwd(String v) => _p.setString('pwd', v);
  // ★b35 统一账号：整个 App 只登录一次，所有功能共用
  static String get accountToken => _p.getString('account.token') ?? '';
  static Future<void> setAccountToken(String v) => _p.setString('account.token', v);
  static String get accountName => _p.getString('account.name') ?? '';
  static Future<void> setAccountName(String v) => _p.setString('account.name', v);"""
new5 = """  static Future<void> setPwd(String v) => _p.setString('pwd', v);"""
assert old5 in s5, 'api store fail'
s5 = s5.replace(old5, new5, 1)
io.open(p5, 'w', encoding='utf-8', newline='').write(s5)
print('api.dart 删账号字段 OK')

# ============ 6. 删除 account_login.dart ============
f = r'C:\Users\xilisi\Doubao\chats\2026-09-27\new-chat\baona-app\lib\account_login.dart'
if os.path.exists(f):
    os.remove(f)
    print('account_login.dart 已删除')
else:
    print('account_login.dart 不存在（已删）')
