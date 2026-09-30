# -*- coding: utf-8 -*-
import io

# ============ main.dart：启动秒开 —— 先渲染本地缓存再网络刷新 ============
p = r'C:\Users\xilisi\Doubao\chats\2026-09-27\new-chat\baona-app\lib\main.dart'
s = io.open(p, encoding='utf-8').read()

old = """  Future<void> loadBootstrap() async {
    final a = app.api;
    if (a == null) return;
    // ★2026-09-29：以前这三件事是排队等的（bootstrap → herSettings → emoji），启动慢一截；
    //   现在一起发出去，谁先回来谁先用。
    final rs = await Future.wait<Map<String, dynamic>>([a.bootstrap(), a.herSettings(), a.emojiList()]);
    final j = rs[0];
    if (j['ok'] == true) {
      nick = '${j['nick'] ?? nick}';
      status = '${j['status'] ?? status}';
      voiceEnabled = j['voiceEnabled'] == true;
      coupleEnabled = j['coupleEnabled'] == true;
      herSet = Map<String, dynamic>.from((j['settings'] as Map?) ?? {});
      notifyListeners();
      Notify.i.ask();          // 连上了就问一次通知权限
    }
    final s = rs[1];
    if (s['ok'] == true && s['s'] is Map) {
      herSet = Map<String, dynamic>.from(s['s'] as Map);
      notifyListeners();
    }
    final e = rs[2];
    if (e['ok'] == true) {
      emoji = ((e['list'] as List?) ?? []).map((x) => {'name': '$x'}).toList();
      emojiMine = ((e['mine'] as List?) ?? []).map((x) => '$x').toSet();
      notifyListeners();
    }
  }"""

new = """  Future<void> loadBootstrap() async {
    final a = app.api;
    if (a == null) return;
    // ★b21 启动秒开：先把上次的缓存立刻渲染出来（名字/状态/头像/表情），网络回来再覆盖
    try {
      final raw = Store.bootCache;
      if (raw.isNotEmpty) {
        final c = jsonDecode(raw);
        if (c is Map && (c['t'] is int) && (DateTime.now().millisecondsSinceEpoch - (c['t'] as int)) < 86400000) {
          nick = '${c['nick'] ?? nick}';
          status = '${c['status'] ?? status}';
          voiceEnabled = c['voice'] == true;
          coupleEnabled = c['couple'] == true;
          if (c['set'] is Map) herSet = Map<String, dynamic>.from(c['set'] as Map);
          if (c['emoji'] is List) emoji = (c['emoji'] as List).map((x) => {'name': '$x'}).toList();
          if (c['mine'] is List) emojiMine = (c['mine'] as List).map((x) => '$x').toSet();
          notifyListeners();
        }
      }
    } catch (_) {/* 缓存坏了就正常走网络 */}
    // ★2026-09-29：以前这三件事是排队等的（bootstrap → herSettings → emoji），启动慢一截；
    //   现在一起发出去，谁先回来谁先用。
    final rs = await Future.wait<Map<String, dynamic>>([a.bootstrap(), a.herSettings(), a.emojiList()]);
    final j = rs[0];
    if (j['ok'] == true) {
      nick = '${j['nick'] ?? nick}';
      status = '${j['status'] ?? status}';
      voiceEnabled = j['voiceEnabled'] == true;
      coupleEnabled = j['coupleEnabled'] == true;
      herSet = Map<String, dynamic>.from((j['settings'] as Map?) ?? {});
      notifyListeners();
      Notify.i.ask();          // 连上了就问一次通知权限
    }
    final s = rs[1];
    if (s['ok'] == true && s['s'] is Map) {
      herSet = Map<String, dynamic>.from(s['s'] as Map);
      notifyListeners();
    }
    final e = rs[2];
    if (e['ok'] == true) {
      emoji = ((e['list'] as List?) ?? []).map((x) => {'name': '$x'}).toList();
      emojiMine = ((e['mine'] as List?) ?? []).map((x) => '$x').toSet();
      notifyListeners();
    }
    // ★b21 网络回来了 → 把最新数据存成缓存，下次启动秒开
    try {
      await Store.setBootCache(jsonEncode({
        't': DateTime.now().millisecondsSinceEpoch,
        'nick': nick,
        'status': status,
        'voice': voiceEnabled,
        'couple': coupleEnabled,
        'set': herSet,
        'emoji': emoji.map((x) => x['name']).toList(),
        'mine': emojiMine.toList(),
      }));
    } catch (_) {/* ignore */}
  }"""
assert old in s, 'main loadBootstrap fail'
s = s.replace(old, new)
io.open(p, 'w', encoding='utf-8', newline='').write(s)
print('main.dart 启动缓存完成')

# ============ chat.dart：头像也走磁盘缓存（_MiniAvatar + _ConvHeader） ============
p = r'C:\Users\xilisi\Doubao\chats\2026-09-27\new-chat\baona-app\lib\chat.dart'
s = io.open(p, encoding='utf-8').read()

old_mini = """class _MiniAvatar extends StatelessWidget {
  const _MiniAvatar();

  @override
  Widget build(BuildContext context) {
    final av = '${app.herSet['herAvatar'] ?? ''}';
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(colors: [kAccent, kAccent2]),
        image: avatarOf(av) == null ? null : DecorationImage(image: avatarOf(av)!, fit: BoxFit.cover),
      ),
      child: av.isEmpty ? const Center(child: Text('娜', style: TextStyle(fontSize: 13))) : null,
    );
  }
}"""
new_mini = """class _MiniAvatar extends StatelessWidget {
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
    }
    // ★b21 头像磁盘缓存：不再每次打开对话都重新下载
    return FutureBuilder<ImageProvider>(
      future: ImgCache.provider(avatarOf(av)!.toString()),
      builder: (c, s) => Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(colors: [kAccent, kAccent2]),
          image: s.data == null ? null : DecorationImage(image: s.data!, fit: BoxFit.cover),
        ),
      ),
    );
  }
}"""
assert old_mini in s, 'mini avatar fail'
s = s.replace(old_mini, new_mini)
io.open(p, 'w', encoding='utf-8', newline='').write(s)
print('chat.dart _MiniAvatar 缓存完成')
