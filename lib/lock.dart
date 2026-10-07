// lock.dart — 包娜 App v27.0.14.16 启动锁（纯密码）
// 规则：
//   1) 第一次打开 App → LockSetupPage：设密码（≥4 位，输两遍一致）；
//   2) 之后每次冷启动 → LockGatePage：输对密码才放行；
//   3) 挂在后台再切回来（resume）→ 不重新锁，只有冷启动才验证；
//   4) ★自签(侧载) App 不支持 Face ID（local_auth 会崩）→ 人脸识别整个去掉，
//      只保留密码，不依赖任何原生能力，自签环境完全可靠。
//   5) 密码只存 SHA-256 哈希，不存明文。
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'api.dart';
import 'theme.dart';

/// 密码 SHA-256 哈希（本地只存哈希，不存明文）
String _hash(String pwd) => sha256.convert(utf8.encode('v27.$pwd')).toString();

/* ================= 首次设置：设密码 ================= */
class LockSetupPage extends StatefulWidget {
  const LockSetupPage({super.key, required this.onDone});
  final VoidCallback onDone;
  @override
  State<LockSetupPage> createState() => _LockSetupPageState();
}

class _LockSetupPageState extends State<LockSetupPage> {
  final TextEditingController _p1 = TextEditingController();
  final TextEditingController _p2 = TextEditingController();
  bool _err = false;
  bool _busy = false;

  @override
  void dispose() {
    _p1.dispose();
    _p2.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final p1 = _p1.text;
    final p2 = _p2.text;
    if (p1.length < 4 || p1 != p2) {
      setState(() => _err = true);
      return;
    }
    if (_busy) return;
    setState(() {
      _busy = true;
      _err = false;
    });
    try {
      await Store.setLockHash(_hash(p1));
    } catch (e) {
      try { Store.setCrashLog('setup: $e'); } catch (_) {}
      if (mounted) setState(() {
        _busy = false;
        _err = true;
      });
      return;
    }
    try { HapticFeedback.mediumImpact(); } catch (_) {/* 无震动设备忽略 */}
    if (!mounted) return;
    // 下一帧再切主页（等锁页完全退场，避免切换树时机问题）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onDone();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Wall(
      url: '',
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Container(
                  width: 76,
                  height: 76,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: kAccent.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock_outline_rounded, size: 34, color: kAccent),
                ),
                const SizedBox(height: 18),
                const Text('设置启动密码',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.4)),
                const SizedBox(height: 6),
                const Text('每次打开 App 都需要验证\n（挂在后台再回来不用）',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: kSub, height: 1.5)),
                const SizedBox(height: 26),
                TextField(
                  controller: _p1,
                  obscureText: true,
                  maxLength: 16,
                  enableSuggestions: false,
                  autocorrect: false,
                  keyboardType: TextInputType.visiblePassword,
                  style: const TextStyle(fontSize: 17, letterSpacing: 2),
                  decoration: const InputDecoration(
                    hintText: '设置密码（至少 4 位）',
                    counterText: '',
                    prefixIcon: Icon(Icons.password_rounded, size: 20, color: kSub),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _p2,
                  obscureText: true,
                  maxLength: 16,
                  enableSuggestions: false,
                  autocorrect: false,
                  keyboardType: TextInputType.visiblePassword,
                  style: const TextStyle(fontSize: 17, letterSpacing: 2),
                  decoration: const InputDecoration(
                    hintText: '再输一遍确认',
                    counterText: '',
                    prefixIcon: Icon(Icons.verified_user_outlined, size: 20, color: kSub),
                  ),
                ),
                if (_err)
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Text('密码至少 4 位，且两次要一致',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: kBad)),
                  ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: _busy ? null : _save,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  child: Text(_busy ? '保存中…' : '完成并进入', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/* ================= 冷启动解锁门（纯密码） ================= */
class LockGatePage extends StatefulWidget {
  const LockGatePage({super.key, required this.onUnlocked});
  final VoidCallback onUnlocked;
  @override
  State<LockGatePage> createState() => _LockGatePageState();
}

class _LockGatePageState extends State<LockGatePage> {
  final TextEditingController _p = TextEditingController();
  bool _busy = false;
  bool _err = false;

  @override
  void dispose() {
    _p.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    final p = _p.text;
    if (p.isEmpty) {
      setState(() => _err = true);
      return;
    }
    if (_busy) return;
    setState(() {
      _busy = true;
      _err = false;
    });
    try {
      // 哈希比对（延时一点点，防暴力试密码的手感）
      await Future.delayed(const Duration(milliseconds: 220));
      final ok = _hash(p) == Store.lockHash;
      if (!mounted) return;
      setState(() => _busy = false);
      if (ok) {
        try { HapticFeedback.mediumImpact(); } catch (_) {}
        widget.onUnlocked();
      } else {
        setState(() => _err = true);
        _p.clear();
      }
    } catch (e) {
      try { Store.setCrashLog('unlock: $e'); } catch (_) {}
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Wall(
      url: '',
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Container(
                  width: 76,
                  height: 76,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: kAccent.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock_outline_rounded, size: 34, color: kAccent),
                ),
                const SizedBox(height: 18),
                const Text('包娜',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: 4)),
                const SizedBox(height: 6),
                const Text('输入密码解锁',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13.5, color: kSub)),
                const SizedBox(height: 26),
                TextField(
                  controller: _p,
                  obscureText: true,
                  maxLength: 16,
                  autofocus: true,
                  enableSuggestions: false,
                  autocorrect: false,
                  keyboardType: TextInputType.visiblePassword,
                  style: const TextStyle(fontSize: 17, letterSpacing: 2),
                  onSubmitted: (_) => _unlock(),
                  decoration: const InputDecoration(
                    hintText: '密码',
                    counterText: '',
                    prefixIcon: Icon(Icons.password_rounded, size: 20, color: kSub),
                  ),
                ),
                if (_err)
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Text('密码不对，再试试',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: kBad)),
                  ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: _busy ? null : _unlock,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  child: Text(_busy ? '验证中…' : '解锁', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
                // ★.14.14 崩溃留痕：上次异常会显示在这里（定位闪退用）
                if (Store.crashLog.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Text('上次异常：${Store.crashLog}',
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: kSub)),
                  ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
