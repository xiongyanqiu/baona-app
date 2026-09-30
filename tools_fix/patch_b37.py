# -*- coding: utf-8 -*-
import io, re

# ============ 1. account_login.dart：回退用户名+密码 ============
p = r'C:\Users\xilisi\Doubao\chats\2026-09-27\new-chat\baona-app\lib\account_login.dart'
s = io.open(p, encoding='utf-8').read()

old = """    if (!RegExp(r'^\\d{11}$').hasMatch(n)) {
      setState(() => _msg = '填 11 位手机号');
      return;
    }
    if (p.isEmpty) {
      setState(() => _msg = '再填个密码（至少 4 位）');
      return;
    }"""
new = """    if (n.isEmpty) {
      setState(() => _msg = '填个账号（自己起个名字就行）');
      return;
    }
    if (p.isEmpty) {
      setState(() => _msg = '再填个密码（至少 4 位）');
      return;
    }"""
assert old in s, 'submit anchor fail'
s = s.replace(old, new, 1)

old2 = """              const Center(
                child: Text('手机号注册登录 · 一个账号走遍全 App', style: TextStyle(color: Color(0xFF9AA0B4), fontSize: 13)),
              ),"""
new2 = """              const Center(
                child: Text('一个账号走遍全 App · 账号自己起名，密码要记得', style: TextStyle(color: Color(0xFF9AA0B4), fontSize: 13)),
              ),"""
assert old2 in s, 'subtitle fail'
s = s.replace(old2, new2, 1)

old3 = """                hint: '手机号（11 位）',
                icon: Icons.smartphone_rounded,
                phone: true,"""
new3 = """                hint: '账号（自己起个名字，比如 娜娜的老公）',
                icon: Icons.person_outline_rounded,
                phone: false,"""
assert old3 in s, 'field fail'
s = s.replace(old3, new3, 1)

io.open(p, 'w', encoding='utf-8', newline='').write(s)
print('account_login.dart 回退用户名+密码 OK')

# ============ 2. chat.dart：我的消息也有头像 ============
p2 = r'C:\Users\xilisi\Doubao\chats\2026-09-27\new-chat\baona-app\lib\chat.dart'
s2 = io.open(p2, encoding='utf-8').read()

old4 = """          if (!me) ...[
            const _MiniAvatar(),
            const SizedBox(width: 7),
          ],
          Flexible(child: body),
        ],"""
new4 = """          if (!me) ...[
            const _MiniAvatar(me: false),
            const SizedBox(width: 7),
          ],
          Flexible(child: body),
          // ★b37 我的消息右侧也有头像（微信式左右各一个）
          if (me) ...[
            const SizedBox(width: 7),
            const _MiniAvatar(me: true),
          ],
        ],"""
assert old4 in s2, 'bubble row fail'
s2 = s2.replace(old4, new4, 1)

old5 = """class _MiniAvatar extends StatelessWidget {
  const _MiniAvatar();

  @override
  Widget build(BuildContext context) {
    final av = '${app.herSet['herAvatar'] ?? ''}';
    if (av.isEmpty) {
      return Container(
        width: 30,
        height: 30,
        decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [kAccent, kAccent2])),
        child: const Center(child: Text('娜', style: TextStyle(fontSize: 13))),
      );
    }"""
new5 = """class _MiniAvatar extends StatelessWidget {
  const _MiniAvatar({this.me = false});
  final bool me;

  @override
  Widget build(BuildContext context) {
    final av = '${me ? app.herSet['myAvatar'] ?? '' : app.herSet['herAvatar'] ?? ''}';
    if (av.isEmpty) {
      return Container(
        width: 30,
        height: 30,
        decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [kAccent, kAccent2])),
        child: Center(child: Text(me ? '我' : '娜', style: const TextStyle(fontSize: 13))),
      );
    }"""
assert old5 in s2, 'mini avatar fail'
s2 = s2.replace(old5, new5, 1)

io.open(p2, 'w', encoding='utf-8', newline='').write(s2)
print('chat.dart 我的头像 OK')
