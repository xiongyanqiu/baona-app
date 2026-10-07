// lock.dart — 包娜 App v27.0.14.13 启动锁：Face ID 人脸识别 + 密码
// 规则：
//   1) 第一次打开 App → LockSetupPage：设密码（≥4 位）+ 可选开启人脸识别；
//   2) 之后每次打开（冷启动）→ LockGatePage：开启过人脸就自动调 Face ID，
//      识别失败 / 取消 / 设备不支持 → 落回密码输入；密码对才放行；
//   3) 挂在后台再切回来（resume）→ 不重新锁（锁只在冷启动出现一次）。
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

import 'api.dart';
import 'theme.dart';

/// 密码 SHA-256 哈希（本地只存哈希，不存明文）
String _hash(String pwd) => sha256.convert(utf8.encode('v27.$pwd')).toString();

/// 设备是否支持生物识别（Face ID / Touch ID）
Future<bool> _biometricsAvailable() async {
  try {
    final a = LocalAuthentication();
    return await a.canCheckBiometrics;
  } catch (_) {
    return false;
  }
}

/// 调起系统人脸识别，返回是否通过
Future<bool> _tryFace() async {
  try {
    final a = LocalAuthentication();
    return await a.authenticate(
      localizedReason: '用 Face ID 解锁包娜',
      options: const AuthenticationOptions(
        biometricOnly: true,
        stickyAuth: true,
      ),
    );
  } catch (_) {
    return false;
  }
}

/* ================= 首次设置：设密码 + 可选开人脸 ================= */
class LockSetupPage extends StatefulWidget {
  const LockSetupPage({super.key, required this.onDone});
  final VoidCallback onDone;
  @override
  State<LockSetupPage> createState() => _LockSetupPageState();
}

class _LockSetupPageState extends State<LockSetupPage> {
  final TextEditingController _p1 = TextEditingController();
  final TextEditingController _p2 = TextEditingController();
  bool _face = false;
  bool _faceAvail = false;
  bool _err = false;

  @override
  void initState() {
    super.initState();
    _biometricsAvailable().then((v) {
      if (mounted) setState(() => _faceAvail = v);
    });
  }

  @override
  void dispose() {
    _p1.dispose();
    _p2.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final p1 = _p1.text;
    final p2 = _p2.text;
    if (p1.length < 4) {
      setState(() => _err = true);
      return;
    }
    if (p1 != p2) {
      setState(() => _err = true);
      return;
    }
    // 存哈希 + 是否开人脸（用户自己点开关选择）
    await Store.setLockHash(_hash(p1));
    await Store.setLockFace(_face && _faceAvail);
    HapticFeedback.mediumImpact();
    if (mounted) widget.onDone();
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
                const SizedBox(height: 16),
                if (_faceAvail)
                  SwitchListTile(
                    value: _face,
                    onChanged: (v) => setState(() => _face = v),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('开启人脸识别', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600)),
                    subtitle: const Text('打开时自动 Face ID 解锁，识别不了再输密码', style: TextStyle(fontSize: 12, color: kSub)),
                    secondary: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: _face ? kAccent.withValues(alpha: 0.18) : kBg2,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.face_retouching_natural, size: 22,
                          color: _face ? kAccent : kSub),
                    ),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.only(bottom: 6),
                    child: Text('这台设备不支持人脸识别，将只用密码解锁',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: kSub)),
                  ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: _save,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  child: const Text('完成并进入', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/* ================= 冷启动解锁门 ================= */
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
  bool _faceTried = false; // 这次冷启动已经试过人脸（避免循环弹）

  @override
  void initState() {
    super.initState();
    // 开启过人脸 & 设备支持 → 自动调起
    if (Store.lockFace) {
      _autoFace();
    }
  }

  Future<void> _autoFace() async {
    if (_faceTried) return;
    _faceTried = true;
    final avail = await _biometricsAvailable();
    if (!avail || !mounted) return;
    setState(() => _busy = true);
    final ok = await _tryFace();
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      HapticFeedback.mediumImpact();
      widget.onUnlocked();
    }
  }

  Future<void> _unlock() async {
    final p = _p.text;
    if (p.isEmpty) {
      setState(() => _err = true);
      return;
    }
    setState(() {
      _busy = true;
      _err = false;
    });
    // 哈希比对（延时一点点，防暴力试密码的手感）
    await Future.delayed(const Duration(milliseconds: 220));
    final ok = _hash(p) == Store.lockHash;
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      HapticFeedback.mediumImpact();
      widget.onUnlocked();
    } else {
      setState(() => _err = true);
      _p.clear();
    }
  }

  @override
  void dispose() {
    _p.dispose();
    super.dispose();
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
                Text(
                  _busy ? '正在验证…' : '输入密码解锁',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13.5, color: kSub),
                ),
                const SizedBox(height: 26),
                TextField(
                  controller: _p,
                  obscureText: true,
                  maxLength: 16,
                  autofocus: !Store.lockFace, // 开了人脸就等人脸，不抢键盘
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
                if (Store.lockFace)
                  TextButton(
                    onPressed: _busy ? null : _autoFace,
                    child: const Text('用人脸识别解锁', style: TextStyle(fontSize: 14, color: kAccent)),
                  ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
