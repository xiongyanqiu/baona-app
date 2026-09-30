# -*- coding: utf-8 -*-
import io

p = r'C:\Users\xilisi\Doubao\chats\2026-09-27\new-chat\baona-app\lib\douyin.dart'
s = io.open(p, encoding='utf-8').read()

# 1. import account_login.dart
old = "import 'api.dart';\nimport 'theme.dart';"
new = "import 'account_login.dart';\nimport 'api.dart';\nimport 'theme.dart';"
assert old in s, 'import anchor fail'
s = s.replace(old, new, 1)

# 2. 登录按钮：账号态
old2 = """              // ★登录入口（b35 接登录页）
              TextButton.icon(
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('抖音登录页即将上线，先刷着～'))),
                icon: const Icon(Icons.account_circle_rounded, color: Colors.white, size: 18),
                label: const Text('登录',
                    style: TextStyle(color: Colors.white, fontSize: 14)),
              ),"""
new2 = """              // ★b35 统一账号：已登录显示账号名，未登录点击去登录（登录后全局共用）
              TextButton.icon(
                onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AccountLoginPage())),
                icon: const Icon(Icons.account_circle_rounded, color: Colors.white, size: 18),
                label: Text(Store.accountName.isEmpty ? '登录' : Store.accountName,
                    style: const TextStyle(color: Colors.white, fontSize: 14)),
              ),"""
assert old2 in s, 'btn anchor fail'
s = s.replace(old2, new2, 1)

io.open(p, 'w', encoding='utf-8', newline='').write(s)
print('douyin.dart 登录按钮已改')
