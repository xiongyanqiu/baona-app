// 包娜 App · 商城：商城 / 背包 / 钱包（双钱包 + 真的买东西，她知道）
import 'package:flutter/material.dart';

import 'api.dart';
import 'main.dart';
import 'theme.dart';

class ShopPage extends StatefulWidget {
  const ShopPage({super.key});

  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> {
  ShopState? _s;
  List<ShopItem> _all = [];
  String _cat = 'Q';
  int _tab = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final a = app.api;
    if (a == null) return;
    final s = await a.shop();
    final c = await a.catalog();
    if (!mounted) return;
    setState(() {
      if (s['ok'] == true) _s = ShopState.fromJson(s);
      final items = ((c['items'] as List?) ?? []).map((e) => ShopItem.fromJson(Map.from(e))).toList();
      if (items.isNotEmpty) _all = items;
      if (_s != null && _s!.cats.isNotEmpty && !_s!.cats.any((x) => '${x['k']}' == _cat)) _cat = '${_s!.cats.first['k']}';
      _loading = false;
    });
  }

  Future<void> _buy(ShopItem it, bool forHer) async {
    final a = app.api;
    if (a == null) return;
    final r = await a.shopBuy(it.code, forHer);
    if (!mounted) return;
    if (r['ok'] != true) {
      toast(context, '${r['error'] ?? '买不了'}');
      return;
    }
    if (r['state'] is Map) setState(() => _s = ShopState.fromJson(Map.from(r['state'] as Map)));
    toast(context, forHer ? '买给她了，她收到啦～' : '买好了，收进背包');
  }

  Future<void> _act(String kind, String id) async {
    final a = app.api;
    if (a == null) return;
    final r = kind == 'use' ? await a.shopUse(id) : await a.shopGive(id);
    if (!mounted) return;
    if (r['ok'] != true) {
      toast(context, '${r['error'] ?? '不行'}');
      return;
    }
    if (r['state'] is Map) setState(() => _s = ShopState.fromJson(Map.from(r['state'] as Map)));
    toast(context, kind == 'use' ? (r['durable'] == false ? '用完了' : '用上了，她知道～') : '送到她手上了～');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final s = _s;
    if (s == null) return const Center(child: Text('商城没打开', style: TextStyle(color: kSub)));
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 2),
        child: Row(children: [
          _Tab('商城', 0, _tab, (i) => setState(() => _tab = i)),
          _Tab('背包', 1, _tab, (i) => setState(() => _tab = i)),
          _Tab('钱包', 2, _tab, (i) => setState(() => _tab = i)),
          const Spacer(),
          Glass(
            pad: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            radius: 10,
            child: Text('我的 ¥${s.my} · 她的 ¥${s.her}', style: const TextStyle(fontSize: 11.5)),
          ),
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh, size: 18)),
        ]),
      ),
      Expanded(child: _tab == 0 ? _mall(s) : (_tab == 1 ? _bag() : _wallet(s))),
    ]);
  }

  Widget _mall(ShopState s) {
    final items = _all.where((x) => x.cat == _cat).toList();
    final cats = s.cats.isEmpty
        ? [{'k': 'Q', 'name': '情趣用品', 'ico': '趣'}]
        : s.cats;
    return Column(children: [
      SizedBox(
        height: 40,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          children: [
            for (final c in cats)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Chip2('${c['ico'] ?? ''} ${c['name'] ?? ''}', on2: '${c['k']}' == _cat, on: () => setState(() => _cat = '${c['k']}')),
              ),
          ],
        ),
      ),
      Expanded(
        child: GridView.builder(
          padding: EdgeInsets.fromLTRB(12, 12, 12, navSpace(context) + 12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 0.72),
          itemCount: items.length,
          itemBuilder: (c, i) => _Card(it: items[i], url: app.api!.imgUrl(items[i].img), onBuy: (forHer) => _buy(items[i], forHer)),
        ),
      ),
    ]);
  }

  Widget _bag() {
    final s = _s!;
    return ListView(padding: EdgeInsets.fromLTRB(12, 12, 12, navSpace(context) + 12), children: [
      const Sec('我买的'),
      if (s.bagMe.isEmpty) const Text('背包空空的', style: TextStyle(color: kSub, fontSize: 13)),
      for (final b in s.bagMe) _BagRow(b: b, url: app.api!.imgUrl(b.img), onUse: () => _act('use', b.id), onGive: () => _act('give', b.id)),
      const Sec('她手里的'),
      if (s.bagHer.isEmpty) const Text('她手上还没有东西', style: TextStyle(color: kSub, fontSize: 13)),
      for (final b in s.bagHer) _BagRow(b: b, url: app.api!.imgUrl(b.img), onUse: null, onGive: null),
    ]);
  }

  Widget _wallet(ShopState s) {
    final amt = TextEditingController();
    return ListView(padding: EdgeInsets.fromLTRB(12, 12, 12, navSpace(context) + 12), children: [
      Row(children: [
        Expanded(child: Glass(child: Column(children: [const Text('我的钱包', style: TextStyle(color: kSub, fontSize: 12)), const SizedBox(height: 6), Text('¥${s.my}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600))]))),
        const SizedBox(width: 10),
        Expanded(child: Glass(child: Column(children: [const Text('她的钱包', style: TextStyle(color: kSub, fontSize: 12)), const SizedBox(height: 6), Text('¥${s.her}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: kAccent2))]))),
      ]),
      const Sec('给她转钱'),
      Row(children: [
        Expanded(child: TextField(controller: amt, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: '转多少（元）'))),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: () async {
            final v = int.tryParse(amt.text.trim()) ?? 0;
            if (v <= 0) return;
            final a = app.api!;
            final r = await a.shopPay(v);
            if (!mounted) return;
            if (r['ok'] == true) {
              if (r['state'] is Map) setState(() => _s = ShopState.fromJson(Map.from(r['state'] as Map)));
              amt.clear();
              toast(context, '转过去了～');
            } else {
              toast(context, '${r['error'] ?? '转不了'}');
            }
          },
          child: const Text('转'),
        ),
      ]),
      Wrap(spacing: 8, children: [
        for (final v in ['100', '520', '1314', '10000'])
          Chip2('¥$v', on: () => amt.text = v),
      ]),
      const Sec('她赚到的（你给她发奖励）'),
      Row(children: [
        Expanded(
          child: Chip2('奖励她 ¥520（陪老公的）', ico: Icons.redeem_outlined, on: () async {
            final r = await app.api!.shopEarn(520);
            if (!mounted) return;
            if (r['ok'] == true && r['state'] is Map) setState(() => _s = ShopState.fromJson(Map.from(r['state'] as Map)));
            toast(context, r['ok'] == true ? '她赚到啦～' : '${r['error'] ?? '不行'}');
          }),
        ),
      ]),
      const Sec('流水'),
      for (final l in s.log.reversed.take(40))
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(children: [
            Text(fmtClock(l.t), style: const TextStyle(fontSize: 11, color: kSub)),
            const SizedBox(width: 8),
            Expanded(child: Text('${l.who == 'her' ? '她' : '我'} · ${l.name}', style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
            Text('¥${l.price}', style: const TextStyle(fontSize: 13, color: kAccent2)),
          ]),
        ),
    ]);
  }
}

class _Tab extends StatelessWidget {
  const _Tab(this.t, this.i, this.cur, this.onTap);
  final String t;
  final int i, cur;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 6),
        child: Chip2(t, on2: i == cur, on: () => onTap(i)),
      );
}

class _Card extends StatelessWidget {
  const _Card({required this.it, required this.url, required this.onBuy});
  final ShopItem it;
  final String url;
  final void Function(bool forHer) onBuy;

  @override
  Widget build(BuildContext context) {
    final short = it.name.length > 26 ? '${it.name.substring(0, 26)}…' : it.name;
    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (c) => _Det(it: it, url: url, onBuy: onBuy),
      ),
      child: Container(
        decoration: BoxDecoration(color: kGlass, borderRadius: BorderRadius.circular(14), border: Border.all(color: kLine)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              child: Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const ColoredBox(color: kGlass2)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(short, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, height: 1.3)),
              const SizedBox(height: 5),
              Row(children: [
                Text('¥${it.price}', style: const TextStyle(fontSize: 14, color: kAccent2, fontWeight: FontWeight.w600)),
                const Spacer(),
                Text('${it.catName}', style: const TextStyle(fontSize: 10.5, color: kSub)),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Det extends StatelessWidget {
  const _Det({required this.it, required this.url, required this.onBuy});
  final ShopItem it;
  final String url;
  final void Function(bool forHer) onBuy;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
              child: Image.network(url, height: 240, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const ColoredBox(color: kGlass2, child: SizedBox(height: 240))),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(it.name, style: const TextStyle(fontSize: 15, height: 1.4)),
                const SizedBox(height: 8),
                Row(children: [
                  Text('¥${it.price}', style: const TextStyle(fontSize: 20, color: kAccent2, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 10),
                  Text('${it.catName} · ${it.code}', style: const TextStyle(fontSize: 11.5, color: kSub)),
                ]),
                if (it.note.isNotEmpty) ...[
                  const Sec('她看到会想'),
                  Text(it.note, style: const TextStyle(fontSize: 13, height: 1.5, color: kText)),
                ],
                if (it.use.isNotEmpty) ...[
                  const Sec('用起来'),
                  Text(it.use, style: const TextStyle(fontSize: 13, height: 1.5, color: kText)),
                ],
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(child: OutlinedButton(onPressed: () { onBuy(false); Navigator.pop(context); }, child: const Text('买给我'))),
                  const SizedBox(width: 10),
                  Expanded(child: FilledButton(onPressed: () { onBuy(true); Navigator.pop(context); }, child: const Text('买给她'))),
                ]),
              ]),
            ),
          ]),
        ),
      );
}

class _BagRow extends StatelessWidget {
  const _BagRow({required this.b, required this.url, required this.onUse, required this.onGive});
  final BagItem b;
  final String url;
  final VoidCallback? onUse, onGive;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: kGlass, borderRadius: BorderRadius.circular(12), border: Border.all(color: kLine)),
        child: Row(children: [
          ClipRRect(borderRadius: BorderRadius.circular(9), child: Image.network(url, width: 56, height: 56, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox(width: 56, height: 56))),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(b.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, height: 1.3)),
              const SizedBox(height: 3),
              Text('¥${b.price}${b.used > 0 ? ' · 用过 ${b.used} 次' : ''}', style: const TextStyle(fontSize: 11, color: kSub)),
            ]),
          ),
          if (onUse != null) ...[
            TextButton(onPressed: onUse, child: const Text('用', style: TextStyle(fontSize: 13))),
            TextButton(onPressed: onGive, child: const Text('送她', style: TextStyle(fontSize: 13))),
          ],
        ]),
      );
}
