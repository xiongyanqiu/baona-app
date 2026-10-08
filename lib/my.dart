// my.dart — 包娜 App v27.0.7 「我的」功能区
// 设计：iOS 27 风格（大标题 + 分组圆角卡片 + 系统色板，无紫色底板）
// 内容：模型接入（配好就能对话）/ 人设（可编辑）/ 设置（二级页）
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'api.dart';
import 'brain.dart';
import 'main.dart';
import 'theme.dart';
import 'us.dart'; // ★v27.0.9 壁纸：pickAlbumImage 从手机相册选背景图

// ================= 「我的」主页 =================
class MyPage extends StatefulWidget {
  const MyPage({super.key});
  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  Map<String, dynamic> _llm = {'activeId': '', 'providers': <dynamic>[]};
  String _personaPrev = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final b = app.brain;
    final llm = b == null ? <String, dynamic>{} : await b.llm();
    final p = Store.localPersona.trim().isNotEmpty ? Store.localPersona.trim() : kDefaultPersona;
    if (!mounted) return;
    setState(() {
      if (llm['ok'] == true) _llm = llm;
      _personaPrev = p.replaceAll(RegExp(r'\s+'), ' ');
    });
  }

  String get _modelSub {
    final ps = (_llm['providers'] as List?) ?? [];
    final id = '${_llm['activeId'] ?? ''}';
    for (final p in ps) {
      if ('${(p as Map)['id'] ?? ''}' == id) {
        final name = '${p['name'] ?? ''}'.trim();
        final m = '${p['model'] ?? ''}'.trim();
        if (name.isEmpty && m.isEmpty) return '未配置模型';
        return name.isEmpty ? m : (m.isEmpty ? name : '$name · $m');
      }
    }
    return '未配置模型';
  }

  @override
  Widget build(BuildContext context) {
    final herAv = '${app.herSet['herAvatar'] ?? ''}';
    final herName = '${app.herSet['nickName'] ?? ''}'.trim().isEmpty
        ? '包娜'
        : '${app.herSet['nickName'] ?? ''}';
    final herImg = avatarOf(herAv);
    return SafeArea(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // 大标题
        Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Text('我的',
              style: const TextStyle(
                  fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -0.6)),
        ),
        Expanded(
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
            // ★v27.0.14.10 Bento 主卡：她（头像 + 名字 + 在线 + 当前模型小卡）
            //   玻璃 2.0：强调色渐变 + 锐利描边 + 浮起投影（空间分层）
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    kAccent.withValues(alpha: 0.42),
                    kAccent.withValues(alpha: 0.12),
                  ],
                ),
                border: Border.all(color: const Color(0x33FFFFFF), width: 0.8),
                boxShadow: [
                  BoxShadow(
                      color: kAccent.withValues(alpha: 0.22),
                      blurRadius: 24,
                      offset: const Offset(0, 8)),
                ],
              ),
              child: Row(children: [
                ClipOval(
                  child: herImg == null
                      ? Container(
                          width: 54,
                          height: 54,
                          color: kBg2,
                          child: Center(
                              child: Text(herName.substring(0, 1),
                                  style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                      color: kText))))
                      : Image(
                          image: herImg,
                          width: 54,
                          height: 54,
                          fit: BoxFit.cover,
                          gaplessPlayback: true),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(herName,
                            style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.2)),
                        const SizedBox(height: 3),
                        Row(children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                                color: Color(0xFF34C759), shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 5),
                          const Text('在线',
                              style: TextStyle(
                                  fontSize: 12.5,
                                  color: kSub,
                                  fontWeight: FontWeight.w500)),
                        ]),
                      ]),
                ),
                // 右侧模型小卡（Bento 副卡）
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.black.withValues(alpha: 0.18),
                    border: Border.all(color: const Color(0x26FFFFFF), width: 0.6),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    const Text('模型',
                        style: TextStyle(fontSize: 9.5, color: kSub)),
                    Text(
                      _modelSub.length > 10
                          ? '${_modelSub.substring(0, 10)}…'
                          : _modelSub,
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w600, color: kText),
                    ),
                  ]),
                ),
              ]),
            ),
            _group([
              _row(
                icon: Icons.architecture,
                title: '模型接入',
                sub: _modelSub,
                onTap: () async {
                  await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ModelPage()));
                  _load();
                },
              ),
              _row(
                icon: Icons.face_retouching_natural,
                title: '人设',
                sub: _personaPrev.length > 26 ? '${_personaPrev.substring(0, 26)}…' : _personaPrev,
                onTap: () async {
                  await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const PersonaPage()));
                  _load();
                },
              ),
            ]),
            _group([
              _row(
                icon: Icons.settings_outlined,
                title: '设置',
                sub: '对话 · 记忆 · 外观',
                onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsPage())),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }

  /// iOS 分组卡片
  Widget _group(List<Widget> rows) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: kBg2,
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const Divider(height: 0.5, indent: 56, color: kHair),
          rows[i],
        ],
      ]),
    );
  }

  Widget _row({required IconData icon, required String title, required String sub, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: kAccent.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 17, color: kAccent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5, color: kSub)),
              ]),
            ),
            const Icon(Icons.chevron_right, size: 18, color: kSub),
          ]),
        ),
      ),
    );
  }
}

// ================= 模型接入（二级页） =================
class ModelPage extends StatefulWidget {
  const ModelPage({super.key});
  @override
  State<ModelPage> createState() => _ModelPageState();
}

class _ModelPageState extends State<ModelPage> {
  List<Map<String, dynamic>> _providers = [];
  String _activeId = '';
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final b = app.brain;
    if (b == null) return;
    final r = await b.llm();
    if (!mounted) return;
    setState(() {
      _providers = ((r['providers'] as List?) ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      _activeId = '${r['activeId'] ?? ''}';
      _loaded = true;
    });
  }

  Future<void> _save() async {
    final b = app.brain;
    if (b == null) return;
    await b.llmSave(_providers, _activeId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('已保存'), behavior: SnackBarBehavior.floating));
    }
  }

  Future<void> _enable(String id) async {
    final b = app.brain;
    if (b == null) return;
    await b.llmUse(id);
    await _load();
  }

  /// 添加 / 编辑 模型（对话框表单）
  Future<void> _edit(Map<String, dynamic>? p) async {
    final isNew = p == null;
    final m = p ?? {'id': 'p${DateTime.now().millisecondsSinceEpoch}', 'name': '', 'baseUrl': '', 'apiKey': '', 'model': ''};
    final name = TextEditingController(text: '${m['name'] ?? ''}');
    final base = TextEditingController(text: '${m['baseUrl'] ?? ''}');
    final key = TextEditingController(text: '${m['apiKey'] ?? ''}');
    final model = TextEditingController(text: '${m['model'] ?? ''}');
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (cc) => AlertDialog(
        backgroundColor: kBg2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(isNew ? '添加模型' : '编辑模型', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _field(name, '名称（随便起，如 官方 DeepSeek）'),
            const SizedBox(height: 10),
            _field(base, 'API 地址（如 https://api.deepseek.com）', keyboard: TextInputType.url),
            const SizedBox(height: 10),
            _field(key, 'API Key（sk-...）', obscure: true),
            const SizedBox(height: 10),
            _field(model, '模型名（如 deepseek-chat）'),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(cc, false), child: const Text('取消', style: TextStyle(color: kSub))),
          TextButton(
            onPressed: () => Navigator.pop(cc, true),
            child: const Text('保存', style: TextStyle(color: kAccent, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    m['name'] = name.text.trim();
    m['baseUrl'] = base.text.trim();
    m['apiKey'] = key.text.trim();
    m['model'] = model.text.trim();
    setState(() {
      if (isNew) {
        _providers.add(m);
        if (_activeId.isEmpty) _activeId = '${m['id']}';
      } else {
        final i = _providers.indexWhere((x) => '${x['id']}' == '${m['id']}');
        if (i >= 0) _providers[i] = m;
      }
    });
    await _save();
  }

  Widget _field(TextEditingController c, String hint, {bool obscure = false, TextInputType? keyboard}) {
    return TextField(
      controller: c,
      obscureText: obscure,
      keyboardType: keyboard,
      enableSuggestions: false, // ★v27.0.13 关掉 iOS 拼写检查（双黄下划线）
      autocorrect: false,
      style: const TextStyle(fontSize: 14.5),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 13.5, color: kSub),
        isDense: true,
        filled: true,
        fillColor: kBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // 头部：返回 + 大标题
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 8, 20, 0),
            child: Row(children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: kAccent),
              ),
              const Text('模型接入',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
            ]),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 2, 20, 10),
            child: Text('对话用的模型。填 API 地址、Key、模型名，点「启用」切换当前使用的模型。',
                style: TextStyle(fontSize: 12.5, color: kSub, height: 1.4)),
          ),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
              if (_providers.isEmpty && _loaded)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 36),
                  alignment: Alignment.center,
                  child: const Text('还没有模型，点下面「添加模型」', style: TextStyle(fontSize: 13.5, color: kSub)),
                ),
              // 模型列表卡片
              if (_providers.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(color: kBg2, borderRadius: BorderRadius.circular(14)),
                  clipBehavior: Clip.antiAlias,
                  child: Column(children: [
                    for (var i = 0; i < _providers.length; i++) ...[
                      if (i > 0) const Divider(height: 0.5, indent: 16, color: kHair),
                      _modelRow(_providers[i]),
                    ],
                  ]),
                ),
              // 添加按钮
              Material(
                color: kBg2,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _edit(null),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 13),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.add, size: 18, color: kAccent),
                      SizedBox(width: 6),
                      Text('添加模型', style: TextStyle(fontSize: 15, color: kAccent, fontWeight: FontWeight.w500)),
                    ]),
                  ),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _modelRow(Map<String, dynamic> p) {
    final id = '${p['id'] ?? ''}';
    final active = id == _activeId;
    final name = '${p['name'] ?? ''}'.trim();
    final model = '${p['model'] ?? ''}'.trim();
    final base = '${p['baseUrl'] ?? ''}'.trim();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _edit(p),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  if (active) ...[
                    const Icon(Icons.check_circle, size: 15, color: kAccent),
                    const SizedBox(width: 5),
                  ],
                  Expanded(
                    child: Text(name.isEmpty ? '(未命名)' : name,
                        style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600)),
                  ),
                ]),
                const SizedBox(height: 3),
                Text(model.isEmpty ? base : (base.isEmpty ? model : '$model · $base'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: kSub)),
              ]),
            ),
            const SizedBox(width: 8),
            // 启用开关
            Switch(
              value: active,
              activeColor: kAccent,
              activeTrackColor: kAccent.withValues(alpha: 0.35),
              onChanged: (v) {
                if (v) _enable(id);
              },
            ),
          ]),
        ),
      ),
    );
  }
}

// ================= 人设（二级页） =================
class PersonaPage extends StatefulWidget {
  const PersonaPage({super.key});
  @override
  State<PersonaPage> createState() => _PersonaPageState();
}

class _PersonaPageState extends State<PersonaPage> {
  late final TextEditingController _ctl = TextEditingController(
      text: Store.localPersona.trim().isNotEmpty ? Store.localPersona.trim() : kDefaultPersona);

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final b = app.brain;
    if (b == null) return;
    await b.patchSettings({'patch': {'persona': _ctl.text.trim()}});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('人设已保存，她下次回复就会按这个来'), behavior: SnackBarBehavior.floating));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 8, 20, 0),
            child: Row(children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: kAccent),
              ),
              const Text('人设',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
            ]),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 2, 20, 10),
            child: Text('决定她是谁、怎么说话。改完保存，她下次回复就会按这个来。',
                style: TextStyle(fontSize: 12.5, color: kSub, height: 1.4)),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: TextField(
                controller: _ctl,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                enableSuggestions: false, // ★v27.0.13 关掉 iOS 拼写检查（双黄下划线）
                autocorrect: false,
                style: const TextStyle(fontSize: 14.5, height: 1.55),
                decoration: InputDecoration(
                  hintText: '在这里写她的人设……',
                  hintStyle: const TextStyle(fontSize: 14, color: kSub),
                  filled: true,
                  fillColor: kBg2,
                  contentPadding: const EdgeInsets.all(16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Material(
              color: kAccent,
              borderRadius: BorderRadius.circular(13),
              child: InkWell(
                borderRadius: BorderRadius.circular(13),
                onTap: _save,
                child: const SizedBox(
                  height: 48,
                  child: Center(
                      child: Text('保存人设',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white))),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ================= 设置（二级页） =================
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _useMem = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final b = app.brain;
    if (b == null) return;
    final r = await b.herSettings();
    final s = (r['s'] as Map?) ?? {};
    // ★v27.0.14.10 玻璃强度恢复（液态玻璃 2.0：iOS 27 透明度滑块）
    gGlassStrength = (app.cfg['glassStrength'] as num?)?.toDouble() ?? 0.75;
    if (mounted) {
      setState(() => _useMem = s['useMemories'] != false);
    }
  }

  Future<void> _rename() async {
    final b = app.brain;
    if (b == null) return;
    final ctl = TextEditingController(text: app.nick);
    final name = await showDialog<String>(
      context: context,
      builder: (cc) => AlertDialog(
        backgroundColor: kBg2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('改她的名字', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctl,
          autofocus: true,
          maxLength: 12,
          enableSuggestions: false, // ★v27.0.13 关掉 iOS 拼写检查（双黄下划线）
          autocorrect: false,
          style: const TextStyle(fontSize: 16),
          decoration: const InputDecoration(hintText: '输入新名字', counterText: ''),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(cc), child: const Text('取消', style: TextStyle(color: kSub))),
          TextButton(
            onPressed: () => Navigator.pop(cc, ctl.text.trim()),
            child: const Text('保存', style: TextStyle(color: kAccent, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    final n = (name ?? '').trim();
    if (n.isEmpty || n == app.nick) return;
    await b.patchSettings({'patch': {'nickName': n}});
    if (mounted) setState(() => app.nick = n);
  }

  Future<void> _confirmClear(String title, String msg, Future<void> Function() fn) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (cc) => AlertDialog(
        backgroundColor: kBg2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        content: Text(msg, style: const TextStyle(fontSize: 14.5, height: 1.4)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(cc, false), child: const Text('取消', style: TextStyle(color: kSub))),
          TextButton(
            onPressed: () => Navigator.pop(cc, true),
            child: Text('删除', style: TextStyle(color: kBad, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (ok == true) await fn();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 8, 20, 0),
            child: Row(children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: kAccent),
              ),
              const Text('设置',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
            ]),
          ),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
              _group([
                _row(
                  icon: Icons.edit_outlined,
                  title: '她的名字',
                  sub: '现在叫：${app.nick}',
                  onTap: _rename,
                ),
                _row(
                  icon: Icons.format_size,
                  title: '字号',
                  sub: '对话文字大小',
                  onTap: () {},
                  trailing: SizedBox(
                    width: 130,
                    child: Slider(
                      value: app.fontSize.clamp(13, 20).toDouble(),
                      min: 13,
                      max: 20,
                      divisions: 7,
                      activeColor: kAccent,
                      inactiveColor: const Color(0x33FFFFFF),
                      onChanged: (v) => app.put('fontSize', v.round()),
                    ),
                  ),
                ),
                // ★v27.0.14.10 玻璃强度（液态玻璃 2.0 透明度滑块）：越高玻璃越清晰锐利
                _row(
                  icon: Icons.blur_on,
                  title: '玻璃强度',
                  sub: '液态玻璃清晰度（iOS 27 透明度滑块）',
                  onTap: () {},
                  trailing: SizedBox(
                    width: 130,
                    child: Slider(
                      value: gGlassStrength,
                      min: 0.3,
                      max: 1.0,
                      divisions: 14,
                      activeColor: kAccent,
                      inactiveColor: const Color(0x33FFFFFF),
                      onChanged: (v) {
                        gGlassStrength = v;
                        app.cfg['glassStrength'] = v;
                        app.save();
                        setState(() {});
                      },
                    ),
                  ),
                ),
                _row(
                  icon: Icons.delete_outline,
                  title: '清空聊天记录',
                  sub: '和她的对话全部删掉',
                  danger: true,
                  onTap: () async {
                    final b = app.brain;
                    if (b == null) return;
                    await _confirmClear('清空聊天记录', '和她的聊天记录会全部删掉，确定吗？', () async {
                      await b.clearChat();
                    });
                  },
                ),
              ]),
              _group([
                _row(
                  icon: Icons.memory,
                  title: '用长期记忆',
                  sub: '她回复时会带上记得的事',
                  onTap: () {},
                  trailing: Switch(
                    value: _useMem,
                    activeColor: kAccent,
                    activeTrackColor: kAccent.withValues(alpha: 0.35),
                    onChanged: (v) async {
                      setState(() => _useMem = v);
                      final b = app.brain;
                      if (b != null) {
                        await b.patchSettings({'patch': {'useMemories': v}});
                      }
                    },
                  ),
                ),
                _row(
                  icon: Icons.delete_sweep,
                  title: '清掉她的长期记忆',
                  sub: '她记着的所有事都会忘掉',
                  danger: true,
                  onTap: () async {
                    final b = app.brain;
                    if (b == null) return;
                    await _confirmClear('清掉她的长期记忆', '她记着的所有事都会忘掉，确定吗？', () async {
                      await b.memoryClear();
                    });
                  },
                ),
              ]),
              // ★27.0.16 真人感对话（短句口语/情绪标记/模拟打字）
              _group([
                _row(
                  icon: Icons.psychology_outlined,
                  title: '真人感对话',
                  sub: Store.humanLike ? '开着：短句口语、有情绪立场、模拟打字' : '关闭：回复更直接',
                  onTap: () {},
                  trailing: Switch(
                    value: Store.humanLike,
                    activeColor: kAccent,
                    activeTrackColor: kAccent.withValues(alpha: 0.35),
                    onChanged: (v) async {
                      await Store.setHumanLike(v);
                      setState(() {});
                    },
                  ),
                ),
                if (Store.humanLike)
                  _row(
                    icon: Icons.sentiment_satisfied_outlined,
                    title: '情绪标记',
                    sub: Store.moodShow ? '她的回复会带情绪状态（影响下一轮语气）' : '关闭情绪标记',
                    onTap: () {},
                    trailing: Switch(
                      value: Store.moodShow,
                      activeColor: kAccent,
                      activeTrackColor: kAccent.withValues(alpha: 0.35),
                      onChanged: (v) async {
                        await Store.setMoodShow(v);
                        setState(() {});
                      },
                    ),
                  ),
              ]),
              // ★v27.0.9 聊天壁纸（复刻 b 系列：默认深色 / 从相册选一张 / 清掉 + 透明度/模糊）
              _group([
                _row(
                  icon: Icons.wallpaper,
                  title: '聊天壁纸',
                  sub: app.bg.isEmpty ? '现在是默认深色背景' : '已设置自定义背景',
                  onTap: _pickWall,
                ),
                _row(
                  icon: Icons.blur_on,
                  title: '模糊度',
                  sub: app.bg.isEmpty ? '先选一张壁纸才能调' : '当前 ${app.bgBlur.round()}',
                  onTap: app.bg.isEmpty ? null : () {},
                  trailing: app.bg.isEmpty
                      ? const Icon(Icons.chevron_right, size: 18, color: kSub)
                      : SizedBox(
                          width: 130,
                          child: Slider(
                            value: app.bgBlur,
                            min: 0,
                            max: 24,
                            divisions: 24,
                            activeColor: kAccent,
                            inactiveColor: const Color(0x33FFFFFF),
                            onChanged: (v) {
                              app.cfg['bgBlur'] = v;
                              app.save();
                              setState(() {});
                            },
                          ),
                        ),
                ),
                _row(
                  icon: Icons.opacity,
                  title: '照片透明度',
                  sub: app.bg.isEmpty ? '先选一张壁纸才能调' : '当前 ${(app.bgOpacity * 100).round()}%',
                  onTap: app.bg.isEmpty ? null : () {},
                  trailing: app.bg.isEmpty
                      ? const Icon(Icons.chevron_right, size: 18, color: kSub)
                      : SizedBox(
                          width: 130,
                          child: Slider(
                            value: app.bgOpacity,
                            min: 0.05,
                            max: 1,
                            divisions: 19,
                            activeColor: kAccent,
                            inactiveColor: const Color(0x33FFFFFF),
                            onChanged: (v) {
                              app.cfg['bgOpacity'] = v;
                              app.save();
                              setState(() {});
                            },
                          ),
                        ),
                ),
                if (app.bg.isNotEmpty)
                  _row(
                    icon: Icons.close,
                    title: '清掉壁纸',
                    sub: '回到默认深色背景',
                    danger: true,
                    onTap: () {
                      app.put('bg', '');
                      setState(() {});
                    },
                  ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  /// ★v27.0.9 选壁纸：默认深色 / 从相册选一张（本地相册）
  Future<void> _pickWall() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: kBg2,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Text('聊天壁纸',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.pop(c),
                child: Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(color: const Color(0x33FFFFFF), shape: BoxShape.circle),
                  child: const Icon(Icons.close, size: 16, color: kSub),
                ),
              ),
            ]),
            const SizedBox(height: 14),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.dark_mode_outlined, color: kAccent),
              title: const Text('默认深色', style: TextStyle(fontSize: 15.5)),
              subtitle: const Text('不设壁纸，用系统深色渐变'),
              trailing: app.bg.isEmpty ? const Icon(Icons.check, color: kAccent, size: 20) : const Icon(Icons.chevron_right, size: 18, color: kSub),
              onTap: () {
                app.put('bg', '');
                Navigator.pop(c);
                setState(() {});
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.photo_library_outlined, color: kAccent),
              title: const Text('从相册选一张', style: TextStyle(fontSize: 15.5)),
              subtitle: const Text('在手机相册里挑一张当聊天背景'),
              trailing: const Icon(Icons.chevron_right, size: 18, color: kSub),
              onTap: () async {
                // ★v27.0.12 修复"点了没反应"：先关第一层弹窗，等它的关闭动画走完（350ms）
                //   再开相册网格 —— 之前连着弹两层，第二层被动画竞态吃掉，看着像没反应
                Navigator.pop(c);
                await Future.delayed(const Duration(milliseconds: 350));
                if (!mounted) return;
                final url = await pickAlbumImage(context);
                if (!mounted) return;
                if (url.isEmpty) {
                  // 相册空 / 没选到 → 明确提示，不再静默
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: const Text('相册里还没有照片，先去「照片」里添加一些吧'),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: kBg2,
                    duration: const Duration(seconds: 2),
                  ));
                  return;
                }
                app.put('bg', url);
                if (app.bgBlur <= 0) {
                  app.cfg['bgBlur'] = 8;
                  app.cfg['bgOpacity'] = 0.9;
                  app.save();
                }
                setState(() {});
              },
            ),
            if (app.bg.isNotEmpty)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.close, color: kBad),
                title: const Text('清掉壁纸', style: TextStyle(fontSize: 15.5, color: kBad)),
                trailing: const Icon(Icons.chevron_right, size: 18, color: kSub),
                onTap: () {
                  app.put('bg', '');
                  Navigator.pop(c);
                  setState(() {});
                },
              ),
          ]),
        ),
      ),
    );
  }

  Widget _group(List<Widget> rows) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(color: kBg2, borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const Divider(height: 0.5, indent: 56, color: kHair),
          rows[i],
        ],
      ]),
    );
  }

  Widget _row({
    required IconData icon,
    required String title,
    required String sub,
    VoidCallback? onTap, // ★v27.0.9 可空：壁纸没选时滑块行点了没反应
    Widget? trailing,
    bool danger = false,
  }) {
    final c = danger ? kBad : kAccent;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: c.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 17, color: c),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title,
                    style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w500, color: danger ? kBad : null)),
                const SizedBox(height: 2),
                Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: kSub)),
              ]),
            ),
            if (trailing != null) trailing else const Icon(Icons.chevron_right, size: 18, color: kSub),
          ]),
        ),
      ),
    );
  }
}
