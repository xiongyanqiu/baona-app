// 简单的自检：不联网、不依赖界面，只验数据层能不能读懂电脑端那套 JSON
import 'dart:convert';

import 'package:baona_app/api.dart';
import 'package:baona_app/notify.dart';
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
}
