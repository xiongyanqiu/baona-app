// 包娜 App · 表情包面板（照微信那套做的）
//   · 一格一格的图，点一下就发给她
//   · 第一格是「＋」：从手机相册加一张进【共享库】——你加的她也能发（她的表情库和这个是同一个）
//   · 上面能切「全部 / 我加的」；我加的长按能删（内置的不让删）
//   · 加进去的图存在电脑端 %APPDATA%\色情女友桌宠\emojis\自定义\
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'main.dart';
import 'theme.dart';
import 'imgsrv.dart';

class EmojiPanel extends StatefulWidget {
  const EmojiPanel({super.key, required this.onPick, required this.onClose});
  final void Function(String) onPick;
  final VoidCallback onClose;

  @override
  State<EmojiPanel> createState() => _EmojiPanelState();
}

class _EmojiPanelState extends State<EmojiPanel> {
  bool _mineTab = false;
  bool _busy = false;

  Future<void> _reload() async {
    final dynamic a = app.brainOrApi;
    if (a == null) return;
    final e = await a.emojiList();
    if (!mounted) return;
    if (e['ok'] == true) {
      setState(() {
        app.emoji = ((e['list'] as List?) ?? []).map((x) => {'name': '$x'}).toList();
        app.emojiMine = ((e['mine'] as List?) ?? []).map((x) => '$x').toSet();
      });
    }
  }

  Future<void> _add() async {
    final dynamic a = app.brainOrApi;
    if (a == null) return;
    final f = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 512, imageQuality: 85);
    if (f == null) return;
    setState(() => _busy = true);
    final bytes = await f.readAsBytes();
    final r = await a.emojiAdd('data:image/jpeg;base64,${base64Encode(bytes)}', '我的');
    await _reload();
    if (!mounted) return;
    setState(() => _busy = false);
    toast(context, r['ok'] == true ? '加进库了，她想发就能发' : '${r['error'] ?? '没加上'}');
  }

  Future<void> _del(String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        content: const Text('把这张从表情库里删掉？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('算了')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('删掉')),
        ],
      ),
    );
    if (ok != true) return;
    final dynamic a = app.brainOrApi;
    if (a == null) return;
    final r = await a.emojiDel(name);
    await _reload();
    if (!mounted) return;
    toast(context, r['ok'] == true ? '删了' : '${r['error'] ?? '没删掉'}');
  }

  @override
  Widget build(BuildContext context) {
    // 没拿到列表时先用内置的占位（老逻辑，保证面板不空）
    final all = app.emoji.isEmpty
        ? List.generate(84, (i) => {'name': 'emoji-${'${i + 1}'.padLeft(3, '0')}.jpg'})
        : app.emoji;
    final list = _mineTab ? all.where((e) => app.emojiMine.contains('${e['name']}')).toList() : all;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 2, 14, 8),
      child: GlassSurface(
        radius: 26,
        blur: kBlur,
        pad: const EdgeInsets.fromLTRB(12, 4, 12, 10),
        child: SizedBox(
          height: 268,
          child: Column(children: [
            Row(children: [
              SegCtl(
                options: const [
                  {'v': 'all', 't': '全部'},
                  {'v': 'mine', 't': '我加的'},
                ],
                value: _mineTab ? 'mine' : 'all',
                onPick: (v) => setState(() => _mineTab = v == 'mine'),
              ),
              const SizedBox(width: 8),
              if (_busy) const Text('加着呢…', style: TextStyle(fontSize: 11.5, color: kSub)),
              if (_mineTab && !_busy)
                Text('${list.length} 张 · 长按能删', style: const TextStyle(fontSize: 11, color: kSub)),
              const Spacer(),
              PressScale(
                onTap: widget.onClose,
                radius: kRCapsule,
                child: const SizedBox(width: 34, height: 34, child: Center(child: Icon(Icons.keyboard_arrow_down, size: 20))),
              ),
            ]),
            const SizedBox(height: 6),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(2, 0, 2, 6),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, mainAxisSpacing: 8, crossAxisSpacing: 8),
                itemCount: list.length + (_mineTab ? 0 : 1),
                itemBuilder: (c, i) {
                  if (!_mineTab && i == 0) return _AddTile(onTap: _busy ? null : _add);
                  final e = list[_mineTab ? i : i - 1];
                  final n = '${e['name']}';
                  final mine = app.emojiMine.contains(n);
                  return PressScale(
                    onTap: () => widget.onPick(n),
                    onLong: mine ? () => _del(n) : null,
                    radius: 14,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Stack(children: [
                        Positioned.fill(
                          child: CacheImg(
                            app.brainOrApi?.emojiUrl(n) ?? '',
                            headers: {'x-wc-token': app.api?.token ?? ''},
                            fit: BoxFit.cover,
                          ),
                        ),
                        if (mine) const Positioned(right: 3, top: 3, child: Icon(Icons.more_horiz, size: 13, color: Color(0xCCFFFFFF))),
                      ]),
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

class _AddTile extends StatelessWidget {
  const _AddTile({this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => PressScale(
        onTap: onTap,
        radius: 14,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: kHair),
            color: const Color(0x14FFFFFF),
          ),
          child: const Center(child: Icon(Icons.add, size: 24, color: kSub)),
        ),
      );
}
