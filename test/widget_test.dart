// 简单的自检：不联网、不依赖界面，只验数据层能不能读懂电脑端那套 JSON
import 'dart:convert';

import 'package:baona_app/api.dart';
import 'package:baona_app/notify.dart';
import 'package:baona_app/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('消息能读懂（含 idx / 贴纸 / 语音）', () {
    final m = Msg.fromJson(jsonDecode('{"role":"assistant","content":"老公~","sticker":"angry/angry-01.jpg","voice":null,"idx":137}'));
    expect(m.role, 'assistant');
    expect(m.sticker, 'angry/angry-01.jpg');
    expect(m.idx, 137);
  });

  test('商城状态能读懂（双钱包 + 背包）', () {
    final s = ShopState.fromJson(jsonDecode(
        '{"ok":true,"my":9988848,"her":11500,"bagMe":[],"bagHer":[{"id":"a1","code":"Q002","name":"跳蛋","price":91,"img":"/shop/img/Q002.jpg","used":2,"forHer":true}],"log":[{"t":1,"who":"me","act":"pay","name":"给她的钱","price":10000}],"cats":[{"k":"Q","name":"情趣用品","ico":"趣"}]}'));
    expect(s.my, 9988848);
    expect(s.bagHer.length, 1);
    expect(s.bagHer.first.used, 2);
    expect(s.cats.first['name'], '情趣用品');
  });

  test('飞行棋状态能读懂（48 格 + 蛇形格文案）', () {
    final g = GameState.fromJson(jsonDecode(
        '{"on":true,"me":3,"her":5,"n":48,"turn":"me","mode":"adv","wins":{"me":1,"her":0},"tiles":[{"i":1,"t":"起点","k":"start"},{"i":2,"t":"亲一下","k":"kiss"}]}'));
    expect(g.me, 3);
    expect(g.tiles.length, 2);
    expect(g.tiles[1].t, '亲一下');
    expect(g.winMe, 1);
  });

  test('地址拼接（表情 / 商城图 / 语音）', () {
    final a = Api('http://192.168.31.120:9000');
    expect(a.emojiUrl('angry/angry-01.jpg'), 'http://192.168.31.120:9000/emoji/angry/angry-01.jpg');
    expect(a.imgUrl('/shop/img/Q001.jpg'), 'http://192.168.31.120:9000/shop/img/Q001.jpg');
    expect(a.voiceUrl('v1.mp3'), 'http://192.168.31.120:9000/voice/v1.mp3');
  });

  test('通知文本：工具标记/眼镜指令不会弹给用户看', () {
    expect(Notify.clean('<<看:桌上>>哈啊~你回来啦'), '哈啊~你回来啦');
    expect(Notify.clean('老公\n\n人家等你半天了'), '老公 人家等你半天了');
    expect(Notify.clean('  [[表情]]  哼 '), '哼');
    final long = Notify.clean('老公' * 40);
    expect(long.length, lessThanOrEqualTo(61));
    expect(long.endsWith('…'), true);
    expect(Notify.clean('<<看:床上>>'), '');
  });

  test('相册照片地址必须带 k（2026-09-29 修的坑：以前丢了 k，手机上相册全是空白）', () {
    final a = Api('http://192.168.31.120:9000');
    a.albumKey = 'b2d2b9903ec5';
    expect(a.albumPhotoUrl('/api/album/photo/ph123'), 'http://192.168.31.120:9000/api/album/photo/ph123?k=b2d2b9903ec5');
    a.albumKey = '';
    expect(a.albumPhotoUrl('/api/album/photo/ph123'), 'http://192.168.31.120:9000/api/album/photo/ph123');
  });

  test('头像：dataURL 必须走内存图（iPhone 上 NetworkImage 读 dataURL 直接报错）', () {
    expect(avatarOf(''), isNull);
    expect(avatarOf('http://x/y.jpg'), isA<NetworkImage>());
    expect(
        avatarOf('data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8DwHwAFAAH/q842iQAAAABJRU5ErkJggg=='),
        isA<MemoryImage>());
    expect(avatarOf('data:image/png;base64,@@@这不是base64@@@'), isNull);
  });

  testWidgets('底栏高度按 Scaffold 报的 padding.bottom 算（别自己再加一遍）；键盘要问原始 view', (tester) async {
    Future<List<num>> probe(double navFromScaffold, double kb) async {
      tester.view.viewInsets = FakeViewPadding(bottom: kb);
      double nav = -1;
      bool up = false;
      await tester.pumpWidget(MediaQuery(
        data: MediaQueryData(padding: EdgeInsets.only(bottom: navFromScaffold)),
        child: MaterialApp(home: Builder(builder: (c) {
          nav = navSpace(c);
          up = kbUp(c);
          return const SizedBox();
        })),
      ));
      return [nav, up ? 1 : 0];
    }

    expect(await probe(113, 0), [123, 0]); // iPhone：底栏 113（含安全区）→ 留 10 呼吸
    expect(await probe(79, 0), [89, 0]); // 没有安全区的机器
    expect(await probe(0, 300), [94, 1]); // 键盘弹着 → kbUp 必须认出（布局会把留白归零）
  });
}
