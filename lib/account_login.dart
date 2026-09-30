// 包娜 · 统一账号登录/注册页（b35）
// 整个 App 只用一个账号：打开 App 先登录，抖音等所有功能共用这个登录态。
// 账号存在电脑端（8633 服务 /auth/register·login·me），登录后 token 存本地 7 天有效。
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'api.dart';
import 'main.dart'; // ConnectPage / HomePage（登录成功后跳转）
import 'theme.dart';

class AccountLoginPage extends StatefulWidget {
  const AccountLoginPage({super.key});
  @override
  State<AccountLoginPage> createState() => _AccountLoginPageState();
}

class _AccountLoginPageState extends State<AccountLoginPage> {
  final _name = TextEditingController();
  final _pwd = TextEditingController();
  bool _regMode = false; // 登录 / 注册 切换
  bool _busy = false;
  bool _obscure = true;
  String _msg = '';
  int _hostIdx = 0; // 服务器：家里 / 蒲公英

  String get _svcHost =>
      Uri.parse(kHosts[_hostIdx]['url']!).host;

  @override
  void dispose() {
    _name.dispose();
    _pwd.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final n = _name.text.trim();
    final p = _pwd.text.trim();
    if (n.isEmpty || p.isEmpty) {
      setState(() => _msg = '先填上账号和密码');
      return;
    }
    setState(() {
      _busy = true;
      _msg = '';
    });
    final base = 'http://$_svcHost:8633';
    try {
      Map<String, dynamic> j;
      if (_regMode) {
        // 注册 → 服务端 ok 后自动登录拿 token
        final r = await http
            .post(Uri.parse('$base/auth/register'),
                headers: {'Content-Type': 'application/json'}, body: jsonEncode({'name': n, 'pwd': p}))
            .timeout(const Duration(seconds: 12));
        j = Map<String, dynamic>.from(jsonDecode(utf8.decode(r.bodyBytes)));
        if (j['ok'] != true) {
          setState(() {
            _busy = false;
            _msg = '${j['msg'] ?? '注册失败'}';
          });
          return;
        }
        final r2 = await http
            .post(Uri.parse('$base/auth/login'),
                headers: {'Content-Type': 'application/json'}, body: jsonEncode({'name': n, 'pwd': p}))
            .timeout(const Duration(seconds: 12));
        j = Map<String, dynamic>.from(jsonDecode(utf8.decode(r2.bodyBytes)));
      } else {
        final r = await http
            .post(Uri.parse('$base/auth/login'),
                headers: {'Content-Type': 'application/json'}, body: jsonEncode({'name': n, 'pwd': p}))
            .timeout(const Duration(seconds: 12));
        j = Map<String, dynamic>.from(jsonDecode(utf8.decode(r.bodyBytes)));
      }
      if (!mounted) return;
      if (j['ok'] == true && j['token'] != null) {
        await Store.setAccountToken('${j['token']}');
        await Store.setAccountName('${j['name'] ?? n}');
        // 统一账号登录成功 → 没连过服务器去连，连过直接进主页
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => Store.baseUrl.isEmpty
                ? ConnectPage(host: kHosts[_hostIdx]['url']!)
                : const HomePage(),
          ),
          (_) => false,
        );
      } else {
        setState(() {
          _busy = false;
          _msg = '${j['msg'] ?? '登录失败'}';
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _msg = '连不上电脑端（$base）\n确认电脑开着、同一个网络';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C0D12),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              // 顶部：包娜
              const SizedBox(height: 26),
              Center(
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [kAccent, kAccent2],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Center(
                      child: Text('娜', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w600))),
                ),
              ),
              const SizedBox(height: 16),
              const Center(
                child: Text('包娜', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: 2)),
              ),
              const SizedBox(height: 6),
              const Center(
                child: Text('登录你的小世界', style: TextStyle(color: Color(0xFF9AA0B4), fontSize: 13)),
              ),
              const SizedBox(height: 34),

              // 账号
              _field(
                controller: _name,
                hint: '账号（自己起一个名字）',
                icon: Icons.person_outline_rounded,
              ),
              const SizedBox(height: 14),
              // 密码
              _field(
                controller: _pwd,
                hint: '密码（至少 4 位）',
                icon: Icons.lock_outline_rounded,
                obscure: _obscure,
                trailing: IconButton(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(_obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                      color: const Color(0xFF9AA0B4), size: 20),
                ),
              ),

              if (_msg.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(_msg, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFFF8A80), fontSize: 12.5)),
              ],

              const SizedBox(height: 22),
              // 登录 / 注册按钮
              GestureDetector(
                onTap: _busy ? null : _submit,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(colors: [kAccent, kAccent2]),
                    boxShadow: [
                      BoxShadow(
                        color: kAccent.withOpacity(0.35),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Center(
                    child: _busy
                        ? const SizedBox(
                            width: 22, height: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4))
                        : Text(_regMode ? '注册并登录' : '登录',
                            style: const TextStyle(color: Colors.white, fontSize: 16.5, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // 切换登录/注册
              Center(
                child: GestureDetector(
                  onTap: () => setState(() {
                    _regMode = !_regMode;
                    _msg = '';
                  }),
                  child: Text(
                    _regMode ? '已有账号？去登录' : '没有账号？注册一个',
                    style: const TextStyle(color: Color(0xFFB9C0D8), fontSize: 13.5),
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // 服务器地址（账号存在电脑端）
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0x14FFFFFF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0x1FFFFFFF)),
                ),
                child: Row(children: [
                  const Icon(Icons.dns_rounded, color: Color(0xFF9AA0B4), size: 16),
                  const SizedBox(width: 8),
                  const Text('账号存电脑端 ·', style: TextStyle(color: Color(0xFF9AA0B4), fontSize: 12)),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _hostIdx = (_hostIdx + 1) % kHosts.length),
                      child: Text(' ${kHosts[_hostIdx]['name']} ($_svcHost)',
                          style: const TextStyle(color: Color(0xFFD8DDF0), fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text('点服务器名称可切换 家里 / 蒲公英',
                    style: TextStyle(color: Color(0xFF6A7085), fontSize: 11)),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? trailing,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0x14FFFFFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x1FFFFFFF)),
      ),
      child: Row(children: [
        const SizedBox(width: 14),
        Icon(icon, color: const Color(0xFF9AA0B4), size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: controller,
            obscureText: obscure,
            style: const TextStyle(color: Colors.white, fontSize: 15.5),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Color(0xFF6A7085)),
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
        if (trailing != null) trailing,
        const SizedBox(width: 8),
      ]),
    );
  }
}
