// 包娜 App · 聊天页：她的话、你的话、表情包、照片、语音条、骰子、红包
import 'dart:async';
import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'api.dart';
import 'main.dart';
import 'theme.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final List<Msg> _msgs = [];
  final TextEditingController _inp = TextEditingController();
  final ScrollController _sc = ScrollController();
  final AudioPlayer _audio = AudioPlayer();
  StreamSubscription? _sub;
  bool _loading = true;
  bool _typing = false;
  bool _emojiPanel = false;
  bool _funPanel = false;
  int _limit = 30;
  bool _hasMore = false;
  String? _playingUrl;

  @override
  void initState() {
    super.initState();
    _load();
    _sub = app.api?.events.listen(_onEvent);
    _sc.addListener(() {
      if (_sc.position.pixels <= 40 && _hasMore && !_loading) _load(more: true);
    });
    _audio.onPlayerComplete.listen((_) => setState(() => _playingUrl = null));
  }

  @override
  void dispose() {
    _sub?.cancel();
    _inp.dispose();
    _sc.dispose();
    _audio.dispose();
    super.dispose();
  }

  Future<void> _load({bool more = false}) async {
    final a = app.api;
    if (a == null) return;
    if (more) _limit += 30;
    final j = await a.history(limit: _limit);
    if (!mounted) return;
    final list = ((j['messages'] as List?) ?? []).map((e) => Msg.fromJson(Map.from(e))).toList();
    setState(() {
      _msgs
        ..clear()
        ..addAll(list);
      _hasMore = j['hasMore'] == true;
      _loading = false;
    });
  }

  void _onEvent(Map<String, dynamic> e) {
    final t = '${e['type']}';
    if (t == 'msg') {
      final m = Msg.fromJson(e);
      if (m.role == 'user' || m.role == 'me') m.role = 'me';
      // 自己发的（乐观显示过）就就地升级，不重复
      final i = _msgs.lastIndexWhere((x) => x.st == 'pending' && x.role == 'me' && x.content == m.content);
      setState(() {
        if (m.role == 'me' && i >= 0) {
          _msgs[i] = m..st = 'ok';
        } else {
          _msgs.add(m);
        }
        _typing = false;
      });
      _toBottom();
    } else if (t == 'msg-patch') {
      final idx = Msg.toInt(e['idx']);
      final v = e['voice']?.toString();
      if (idx != null && v != null && v.isNotEmpty) {
        final i = _msgs.indexWhere((x) => x.idx == idx);
        if (i >= 0) setState(() => _msgs[i].voice = v);
      }
    } else if (t == 'typing') {
      setState(() => _typing = e['on'] != false);
      if (_typing) _toBottom();
    } else if (t == 'cleared') {
      setState(() => _msgs.clear());
    }
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_sc.hasClients) _sc.animateTo(_sc.position.maxScrollExtent, duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
    });
  }

  Future<void> _send(Map<String, dynamic> payload, {String? show}) async {
    final a = app.api;
    if (a == null) return;
    final text = '${payload['text'] ?? ''}';
    final m = Msg(role: 'me', content: show ?? text, st: 'pending', time: DateTime.now().millisecondsSinceEpoch, sticker: payload['sticker']?.toString());
    setState(() {
      _msgs.add(m);
      _emojiPanel = false;
      _funPanel = false;
    });
    _toBottom();
    final r = await a.send(payload);
    if (!mounted) return;
    setState(() => m.st = r['ok'] == true ? 'ok' : 'failed');
  }

  void _sendText() {
    final t = _inp.text.trim();
    if (t.isEmpty) return;
    _inp.clear();
    HapticFeedback.lightImpact();
    _send({'text': t});
  }

  Future<void> _sendPhoto() async {
    final a = app.api;
    if (a == null) return;
    try {
      final f = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1400, imageQuality: 82);
      if (f == null) return;
      final bytes = await f.readAsBytes();
      final data = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      toast(context, '正在发照片…');
      final up = await a.chatImg(data);
      if (up['ok'] != true) {
        if (mounted) toast(context, '传不上去：${up['error'] ?? ''}');
        return;
      }
      await _send({'text': '[图片]', 'img': '${up['img'] ?? ''}'}, show: '[照片]');
    } catch (e) {
      if (mounted) toast(context, '发图失败：$e');
    }
  }

  Future<void> _rollDice() async {
    final n = 1 + (DateTime.now().microsecond % 6);
    await _send({'text': '🎲 我掷了 $n 点', 'roll': n});
  }

  Future<void> _sendPacket() async {
    final amt = TextEditingController();
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('发红包'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: amt, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: '金额（元）')),
          const SizedBox(height: 10),
          TextField(controller: note, decoration: const InputDecoration(hintText: '祝福语（不填：恭喜发财，大吉大利）')),
          const SizedBox(height: 12),
          Wrap(spacing: 8, children: [
            for (final v in ['5.2', '13.14', '52', '520'])
              Chip2('¥$v', on: () => amt.text = v),
          ]),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('算了')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('发给她')),
        ],
      ),
    );
    if (ok != true) return;
    final a = double.tryParse(amt.text.trim()) ?? 0;
    if (a <= 0) return;
    final n = note.text.trim().isEmpty ? '恭喜发财，大吉大利' : note.text.trim();
    await _send({'text': '🧧 $n', 'packet': a, 'note': n});
  }

  Future<void> _play(String url) async {
    if (_playingUrl == url) {
      await _audio.stop();
      setState(() => _playingUrl = null);
      return;
    }
    setState(() => _playingUrl = url);
    await _audio.stop();
    await _audio.play(UrlSource(url));
  }

  @override
  Widget build(BuildContext context) {
    final a = app.api;
    if (a == null) return const Center(child: CircularProgressIndicator());
    return Column(children: [
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
                controller: _sc,
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                itemCount: _msgs.length + (_typing ? 1 : 0) + (_hasMore ? 1 : 0),
                itemBuilder: (c, i) {
                  if (_hasMore && i == 0) {
                    return const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Center(child: Text('往上滑看更早的', style: TextStyle(fontSize: 11.5, color: kSub))));
                  }
                  final k = i - (_hasMore ? 1 : 0);
                  if (k >= _msgs.length) return const _TypingBubble();
                  return _Bubble(m: _msgs[k], onResend: () => _send({'text': _msgs[k].content}), onPlay: _play, playing: _playingUrl, urlOf: a);
                },
              ),
      ),
      if (_emojiPanel) _EmojiPanel(onPick: (n) => _send({'text': '[表情]', 'sticker': n}), onClose: () => setState(() => _emojiPanel = false)),
      _Composer(
        ctl: _inp,
        onSend: _sendText,
        onPlus: () => setState(() {
          _funPanel = !_funPanel;
          _emojiPanel = false;
        }),
        onSticker: () => setState(() {
          _emojiPanel = !_emojiPanel;
          _funPanel = false;
        }),
      ),
      if (_funPanel)
        _FunPanel(
          onPhoto: _sendPhoto,
          onSticker: () => setState(() {
            _emojiPanel = true;
            _funPanel = false;
          }),
          onDice: () => setState(() {
            _funPanel = false;
            _rollDice();
          }),
          onPacket: () => setState(() {
            _funPanel = false;
            _sendPacket();
          }),
          onGame: () => setState(() => _funPanel = false),
          onShop: () => setState(() => _funPanel = false),
        ),
    ]);
  }
}

/* ------------------------------- 一条消息 ------------------------------- */
class _Bubble extends StatelessWidget {
  _Bubble({required this.m, required this.onResend, required this.onPlay, required this.playing, required this.urlOf});
  final Msg m;
  final VoidCallback onResend;
  final void Function(String) onPlay;
  final String? playing;
  final Api urlOf;

  static final RegExp _imgRe = RegExp(r'!\[[^\]]*\]\(([^)]+)\)');

  @override
  Widget build(BuildContext context) {
    final me = m.role == 'me' || m.role == 'user';
    final fs = app.fontSize;

    // 正文里的图片（她/他发的照片，服务端存成 ![](/api/chatimg/xxx)）
    String text = m.content;
    final imgs = <String>[];
    if (text.contains('/api/chatimg/')) {
      for (final mm in _imgRe.allMatches(text)) {
        imgs.add(mm.group(1)!);
      }
      text = text.replaceAll(_imgRe, '').trim();
    }

    final Widget body = Column(
      crossAxisAlignment: me ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        if (app.cfg['showTime'] == true && m.time != null)
          Padding(padding: const EdgeInsets.only(bottom: 3), child: Text(fmtClock(m.time!), style: const TextStyle(fontSize: 10.5, color: kSub))),
        if (m.sticker != null && m.sticker!.isNotEmpty && !m.content.contains('![表情]'))
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.network(urlOf.emojiUrl(m.sticker!), width: 132, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox(width: 80, height: 60, child: Center(child: Text('表情没了', style: TextStyle(fontSize: 11, color: kSub))))),
          ),
        for (final u in imgs)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network(urlOf.imgUrl(u), width: 210, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox(width: 160, height: 90, child: Center(child: Text('图没加载出来', style: TextStyle(fontSize: 11, color: kSub))))),
            ),
          ),
        if (m.voice != null && m.voice!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: GlassSurface(
              radius: kRCapsule,
              blur: 12,
              tint: me ? app.myColor : app.herColor,
              onTap: () => onPlay(urlOf.voiceUrl(m.voice!)),
              pad: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(playing == urlOf.voiceUrl(m.voice!) ? Icons.graphic_eq : Icons.play_arrow, size: 16),
                const SizedBox(width: 6),
                const Text('语音条 · 点开听', style: TextStyle(fontSize: 12.5)),
              ]),
            ),
          ),
        if (text.isNotEmpty)
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.76),
            child: GlassSurface(
              radius: 20,
              blur: 14,
              tint: me ? app.myColor : app.herColor,
              pad: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: SelectableText(text, style: TextStyle(fontSize: fs, height: 1.45)),
            ),
          ),
        if (m.st == 'failed')
          TextButton(onPressed: onResend, child: const Text('没发出去 · 点我重发', style: TextStyle(fontSize: 11.5, color: Color(0xFFFF9A9A)))),
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: me ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!me) ...[
            const _MiniAvatar(),
            const SizedBox(width: 7),
          ],
          Flexible(child: body),
        ],
      ),
    );
  }
}

class _MiniAvatar extends StatelessWidget {
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
        image: av.isEmpty ? null : DecorationImage(image: NetworkImage(av), fit: BoxFit.cover),
      ),
      child: av.isEmpty ? const Center(child: Text('娜', style: TextStyle(fontSize: 13))) : null,
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          const _MiniAvatar(),
          const SizedBox(width: 7),
          GlassSurface(
            radius: 20,
            blur: 14,
            tint: app.herColor,
            pad: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: const Text('她正在打字…', style: TextStyle(fontSize: 12.5, color: kSub)),
          ),
        ]),
      );
}

/* ------------------------------- 输入区 ------------------------------- */
class _Composer extends StatelessWidget {
  _Composer({required this.ctl, required this.onSend, required this.onPlus, required this.onSticker});
  final TextEditingController ctl;
  final VoidCallback onSend, onPlus, onSticker;

  @override
  Widget build(BuildContext context) => Padding(
        // ★跟底栏配成一套：一样的左右留白(14)、一样的胶囊圆角、一样的玻璃
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
        child: GlassSurface(
          radius: kRCapsule,
          blur: kBlur,
          pad: const EdgeInsets.fromLTRB(6, 5, 6, 5),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            _RoundBtn(icon: Icons.add, on: onPlus),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: TextField(
                  controller: ctl,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                  style: const TextStyle(fontSize: 15.5, height: 1.35),
                  decoration: const InputDecoration(
                    hintText: '跟她说点什么…',
                    filled: false,
                    isDense: true,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 9),
                  ),
                ),
              ),
            ),
            _RoundBtn(icon: Icons.emoji_emotions_outlined, on: onSticker),
            const SizedBox(width: 2),
            PressScale(
              onTap: onSend,
              radius: kRCapsule,
              scale: 0.92,
              child: Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [kAccent, kAccent2])),
                child: const Icon(Icons.send_rounded, size: 18),
              ),
            ),
          ]),
        ),
      );
}

class _RoundBtn extends StatelessWidget {
  const _RoundBtn({required this.icon, required this.on});
  final IconData icon;
  final VoidCallback on;

  @override
  Widget build(BuildContext context) => PressScale(
        onTap: on,
        radius: kRCapsule,
        scale: 0.9,
        child: SizedBox(width: 38, height: 38, child: Center(child: Icon(icon, size: 21, color: kText.withValues(alpha: 0.9)))),
      );
}

class _FunPanel extends StatelessWidget {
  const _FunPanel({required this.onPhoto, required this.onSticker, required this.onDice, required this.onPacket, required this.onGame, required this.onShop});
  final VoidCallback onPhoto, onSticker, onDice, onPacket, onGame, onShop;

  @override
  Widget build(BuildContext context) {
    const cells = [
      [Icons.photo_outlined, '照片'],
      [Icons.emoji_emotions_outlined, '表情包'],
      [Icons.casino_outlined, '骰子'],
      [Icons.redeem_outlined, '红包'],
      [Icons.sports_esports_outlined, '飞行棋'],
      [Icons.shopping_bag_outlined, '商城'],
    ];
    final ons = [onPhoto, onSticker, onDice, onPacket, onGame, onShop];
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 2, 14, 8),
      child: GlassSurface(
        radius: 26,
        blur: kBlur,
        pad: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          for (var i = 0; i < cells.length; i++)
            PressScale(
              onTap: ons[i],
              radius: kRCapsule,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(color: const Color(0x1FFFFFFF), shape: BoxShape.circle, border: Border.all(color: kHair)),
                  child: Icon(cells[i][0] as IconData, size: 21),
                ),
                const SizedBox(height: 5),
                Text('${cells[i][1]}', style: const TextStyle(fontSize: 11, color: kSub)),
              ]),
            ),
        ]),
      ),
    );
  }
}

class _EmojiPanel extends StatelessWidget {
  const _EmojiPanel({required this.onPick, required this.onClose});
  final void Function(String) onPick;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final a = app.api;
    final list = app.emoji.isEmpty ? List.generate(84, (i) => {'name': 'emoji-${'${i + 1}'.padLeft(3, '0')}.jpg'}) : app.emoji;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 2, 14, 8),
      child: GlassSurface(
        radius: 26,
        blur: kBlur,
        pad: const EdgeInsets.fromLTRB(12, 6, 12, 8),
        child: SizedBox(
      height: 246,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 2, 0, 2),
          child: Row(children: [
            const Text('表情包', style: TextStyle(fontSize: 12.5, color: kSub)),
            const Spacer(),
            IconButton(onPressed: onClose, icon: const Icon(Icons.keyboard_arrow_down, size: 20)),
          ]),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, mainAxisSpacing: 8, crossAxisSpacing: 8),
            itemCount: list.length,
            itemBuilder: (c, i) {
              final n = '${list[i]['name']}';
              return GestureDetector(
                onTap: () => onPick(n),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: a == null
                      ? const ColoredBox(color: kGlass)
                      : Image.network(a.emojiUrl(n), fit: BoxFit.cover, errorBuilder: (_, __, ___) => const ColoredBox(color: kGlass)),
                ),
              );
            },
          ),
        ),
      ]),
        ),
      ),
    );
  }
}
