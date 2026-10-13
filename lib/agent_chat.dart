// 包娜 App · 电脑 Agent 独立会话页（★v27.0.29 万物互联：三个对话接口之一）
// 定位：电脑端是一个【纯 Agent】（通用助手，不是包娜）。手机端经贝锐蒲公英远程连上电脑，
//   在独立会话里跟它单独对话 —— 独立记忆、独立历史，跟包娜主对话完全隔离。
// 连接地址：设置 → 我的 → 万物互联里配置的「电脑端 · Agent」虚拟 IP 和端口。
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'api.dart';
import 'main.dart'; // ★v27.0.30 app.bg 全局壁纸
import 'theme.dart';

class AgentChatPage extends StatefulWidget {
  const AgentChatPage({super.key});
  @override
  State<AgentChatPage> createState() => _AgentChatPageState();
}

class _AgentChatPageState extends State<AgentChatPage> {
  final TextEditingController _ctl = TextEditingController();
  final ScrollController _sc = ScrollController();
  List<Map<String, dynamic>> _msgs = [];
  bool _online = false;
  bool _busy = false;
  bool _checked = false;

  // 独立会话：电脑 Agent 用自己的 session，不碰包娜的任何记忆
  static const String _sid = 'pc-agent';

  String _host() {
    final pc = Store.devices['pc'];
    if (pc is Map) {
      final ip = '${pc['ip'] ?? ''}'.trim();
      final port = '${pc['port'] ?? ''}'.trim();
      if (ip.isNotEmpty && port.isNotEmpty) return 'http://$ip:$port';
    }
    return '';
  }

  @override
  void initState() {
    super.initState();
    _loadLocal();
    _probe();
  }

  void _loadLocal() {
    final raw = Store.getString('pcagent.msgs');
    if (raw.isNotEmpty) {
      try {
        final l = jsonDecode(raw);
        if (l is List) _msgs = List<Map<String, dynamic>>.from(l);
      } catch (_) {}
    }
  }

  Future<void> _saveLocal() async {
    await Store.setString('pcagent.msgs', jsonEncode(_msgs));
  }

  Future<void> _probe() async {
    final base = _host();
    var on = false;
    if (base.isNotEmpty) {
      try {
        final c = HttpClient()..connectionTimeout = const Duration(seconds: 3);
        try {
          final r = await c.getUrl(Uri.parse('$base/ping')).timeout(const Duration(seconds: 3));
          on = (await r.close()).statusCode == 200;
        } finally {
          c.close(force: true);
        }
      } catch (_) {
        on = false;
      }
    }
    if (mounted) {
      setState(() {
        _online = on;
        _checked = true;
      });
    }
  }

  void _scrollBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_sc.hasClients) _sc.animateTo(_sc.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    });
  }

  Future<void> _send() async {
    final text = _ctl.text.trim();
    if (text.isEmpty || _busy) return;
    final base = _host();
    if (base.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('还没配电脑端地址：请到 我的 → 万物互联 填电脑端虚拟 IP 和端口')));
      return;
    }
    setState(() {
      _msgs.add({'role': 'me', 'text': text, 'time': DateTime.now().millisecondsSinceEpoch});
      _busy = true;
    });
    _ctl.clear();
    _scrollBottom();
    await _saveLocal();

    String reply;
    try {
      final r = await http
          .post(Uri.parse('$base/chat'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'session': _sid, 'message': text}))
          .timeout(const Duration(seconds: 120));
      final j = jsonDecode(utf8.decode(r.bodyBytes));
      if (r.statusCode == 200 && j['ok'] == true) {
        reply = '${j['reply'] ?? ''}';
      } else {
        reply = '电脑端返回错误：${j['error'] ?? r.statusCode}';
      }
    } catch (e) {
      reply = '连接电脑端失败（$e）。确认电脑端服务已启动、网络通（同一蒲公英网络）。';
    }

    if (mounted) {
      setState(() {
        _msgs.add({'role': 'agent', 'text': reply, 'time': DateTime.now().millisecondsSinceEpoch});
        _busy = false;
      });
    }
    _scrollBottom();
    await _saveLocal();
    // 顺带刷新在线状态
    await _probe();
  }

  Future<void> _clear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (cc) => AlertDialog(
        title: const Text('清除对话'),
        content: const Text('清空电脑 Agent 的这段对话记录？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(cc, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(cc, true), child: const Text('清除')),
        ],
      ),
    );
    if (ok != true) return;
    final base = _host();
    if (base.isNotEmpty) {
      try {
        await http
            .post(Uri.parse('$base/clear'), headers: {'Content-Type': 'application/json'}, body: jsonEncode({'session': _sid}))
            .timeout(const Duration(seconds: 10));
      } catch (_) {}
    }
    setState(() => _msgs = []);
    await _saveLocal();
  }

  @override
  Widget build(BuildContext context) {
    final base = _host();
    return Scaffold(
      backgroundColor: Colors.transparent, // ★v27.0.30 全局壁纸透出（原来 kBg 纯黑盖住壁纸）
      body: Wall(
        url: app.bg,
        blur: app.bgBlur,
        opacity: app.bgOpacity,
        child: SafeArea(
          child: Column(children: [
            _header(),
            const Divider(height: 1, color: kLine),
            Expanded(
              child: _msgs.isEmpty
                  ? _empty(base)
                  : ListView.builder(
                      controller: _sc,
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                      itemCount: _msgs.length,
                      itemBuilder: (_, i) => _bubble(_msgs[i]),
                    ),
            ),
            _input(),
          ]),
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 4, 12, 4),
      child: Row(children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: kText),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            color: kAccent.withValues(alpha: 0.15), shape: BoxShape.circle),
          child: const Icon(Icons.computer_outlined, size: 19, color: kAccent),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('电脑 Agent', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: kText)),
            Row(children: [
              Container(width: 7, height: 7, decoration: BoxDecoration(
                  color: _online ? const Color(0xFF34C759) : kSub.withValues(alpha: 0.4),
                  shape: BoxShape.circle)),
              const SizedBox(width: 5),
              Text(_online ? '在线 · 独立对话' : (_checked ? '离线' : '检测中…'),
                  style: TextStyle(fontSize: 12, color: kSub)),
            ]),
          ]),
        ),
        IconButton(
          tooltip: '清除对话',
          icon: Icon(Icons.delete_outline_rounded, size: 20, color: kSub),
          onPressed: _msgs.isEmpty ? null : _clear,
        ),
      ]),
    );
  }

  Widget _empty(String base) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.computer_outlined, size: 46, color: kSub.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text(base.isEmpty ? '还没配置电脑端地址' : '电脑 Agent · 独立对话',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: kText)),
          const SizedBox(height: 8),
          Text(
            base.isEmpty
                ? '到 我的 → 万物互联，填电脑端的虚拟 IP 和端口，填完点「测试」让状态变绿。'
                : '这是独立会话，和包娜不互通。你可以让电脑 Agent 帮你操控电脑：执行命令、读写文件、查信息等。',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12.5, color: kSub, height: 1.5),
          ),
        ]),
      ),
    );
  }

  Widget _bubble(Map<String, dynamic> m) {
    final me = m['role'] == 'me';
    final t = '${m['text'] ?? ''}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: me ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!me) ...[
            Container(width: 30, height: 30, decoration: BoxDecoration(
                color: kAccent.withValues(alpha: 0.15), shape: BoxShape.circle),
                child: const Icon(Icons.computer_outlined, size: 17, color: kAccent)),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
              decoration: BoxDecoration(
                color: me ? kAccent : kBg2,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(14),
                  topRight: const Radius.circular(14),
                  bottomLeft: Radius.circular(me ? 14 : 3),
                  bottomRight: Radius.circular(me ? 3 : 14),
                ),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 2)),
                ],
              ),
              child: Text(t, style: TextStyle(fontSize: 15, color: me ? Colors.white : kText, height: 1.4)),
            ),
          ),
          if (me) ...[
            const SizedBox(width: 8),
            Container(width: 30, height: 30, decoration: BoxDecoration(
                color: kText.withValues(alpha: 0.12), shape: BoxShape.circle),
                child: const Icon(Icons.person_outline, size: 17, color: kText)),
          ],
        ],
      ),
    );
  }

  Widget _input() {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      color: Colors.transparent, // ★v27.0.30 输入栏也让壁纸透出（输入框本身半透明玻璃）
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(
          child: TextField(
            controller: _ctl,
            minLines: 1,
            maxLines: 4,
            enabled: !_busy,
            style: const TextStyle(fontSize: 15, color: kText),
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: '跟电脑 Agent 说点什么…',
              hintStyle: const TextStyle(color: kSub),
              isDense: true,
              filled: true,
              fillColor: kBg2,
              contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _busy ? null : _send,
          child: Container(
            width: 38, height: 38,
            decoration: BoxDecoration(color: kAccent, shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: kAccent.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 3))]),
            child: _busy
                ? const Padding(padding: EdgeInsets.all(9), child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : const Icon(Icons.arrow_upward_rounded, size: 20, color: Colors.white),
          ),
        ),
      ]),
    );
  }

  @override
  void dispose() {
    _ctl.dispose();
    _sc.dispose();
    super.dispose();
  }
}
