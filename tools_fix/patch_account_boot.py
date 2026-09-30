# -*- coding: utf-8 -*-
import io

p = r'C:\Users\xilisi\Doubao\chats\2026-09-27\new-chat\baona-app\lib\main.dart'
s = io.open(p, encoding='utf-8').read()

# 1. import
old = "import 'api.dart';\nimport 'chat.dart';"
new = "import 'api.dart';\nimport 'account_login.dart';\nimport 'chat.dart';"
assert old in s, 'import anchor fail'
s = s.replace(old, new, 1)

# 2. Boot 账号检查
old2 = """  @override
  Widget build(BuildContext context) {
    final base = Store.baseUrl;
    if (base.isEmpty || Store.token.isEmpty) {
      return ConnectPage(host: base.isEmpty ? kHosts[0]['url']! : base);
    }"""
new2 = """  @override
  Widget build(BuildContext context) {
    // ★b35 统一账号：没登录账号先去登录（整个 App 只认这一个账号）
    if (Store.accountToken.isEmpty) {
      return const AccountLoginPage();
    }
    final base = Store.baseUrl;
    if (base.isEmpty || Store.token.isEmpty) {
      return ConnectPage(host: base.isEmpty ? kHosts[0]['url']! : base);
    }"""
assert old2 in s, 'boot anchor fail'
s = s.replace(old2, new2, 1)

io.open(p, 'w', encoding='utf-8', newline='').write(s)
print('main.dart 已改：import + Boot 账号检查')
