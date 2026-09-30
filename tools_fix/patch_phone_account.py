# -*- coding: utf-8 -*-
import io

# ============ 1. account_login.dart：手机号登录 ============
p = r'C:\Users\xilisi\Doubao\chats\2026-09-27\new-chat\baona-app\lib\account_login.dart'
s = io.open(p, encoding='utf-8').read()

old = "    if (n.isEmpty || p.isEmpty) {\n      setState(() => _msg = '先填上账号和密码');\n      return;\n    }"
new = "    if (!RegExp(r'^\\d{11}$').hasMatch(n)) {\n      setState(() => _msg = '填 11 位手机号');\n      return;\n    }\n    if (p.isEmpty) {\n      setState(() => _msg = '再填个密码（至少 4 位）');\n      return;\n    }"
assert old in s, 'submit anchor fail'
s = s.replace(old, new, 1)

old2 = """              const Center(
                child: Text('登录你的小世界', style: TextStyle(color: Color(0xFF9AA0B4), fontSize: 13)),
              ),"""
new2 = """              const Center(
                child: Text('手机号注册登录 · 一个账号走遍全 App', style: TextStyle(color: Color(0xFF9AA0B4), fontSize: 13)),
              ),"""
assert old2 in s, 'subtitle anchor fail'
s = s.replace(old2, new2, 1)

old3 = "                hint: '账号（自己起一个名字）',\n                icon: Icons.person_outline_rounded,"
new3 = "                hint: '手机号（11 位）',\n                icon: Icons.smartphone_rounded,\n                phone: true,"
assert old3 in s, 'field anchor fail'
s = s.replace(old3, new3, 1)

old4 = """  Widget _field({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? trailing,
  }) {"""
new4 = """  Widget _field({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    bool phone = false,
    Widget? trailing,
  }) {"""
assert old4 in s, 'field sig fail'
s = s.replace(old4, new4, 1)

old5 = """          child: TextField(
            controller: controller,
            obscureText: obscure,"""
new5 = """          child: TextField(
            controller: controller,
            obscureText: obscure,
            keyboardType: phone ? TextInputType.phone : TextInputType.text,
            maxLength: phone ? 11 : null,"""
assert old5 in s, 'field body fail'
s = s.replace(old5, new5, 1)

# maxLength 会显示计数器，去掉 counter
old6 = """            decoration: InputDecoration(
              hintText: hint,"""
new6 = """            decoration: InputDecoration(
              counterText: '',
              hintText: hint,"""
assert old6 in s, 'counter fail'
s = s.replace(old6, new6, 1)

io.open(p, 'w', encoding='utf-8', newline='').write(s)
print('account_login.dart 手机号改造完成')

# ============ 2. sheets.dart：账号中心 ============
p2 = r'C:\Users\xilisi\Doubao\chats\2026-09-27\new-chat\baona-app\lib\sheets.dart'
s2 = io.open(p2, encoding='utf-8').read()

old7 = "import 'api.dart';\nimport 'main.dart';"
new7 = "import 'account_login.dart';\nimport 'api.dart';\nimport 'main.dart';"
assert old7 in s2, 'sheets import fail'
s2 = s2.replace(old7, new7, 1)

old8 = """        const SizedBox(height: 10),
        const _Probe(),

        const Sec('她的脑子（模型）'),"""
new8 = """        const SizedBox(height: 10),
        const _Probe(),

        const Sec('账号中心'),
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
assert old8 in s2, 'account sec anchor fail'
s2 = s2.replace(old8, new8, 1)

io.open(p2, 'w', encoding='utf-8', newline='').write(s2)
print('sheets.dart 账号中心完成')
