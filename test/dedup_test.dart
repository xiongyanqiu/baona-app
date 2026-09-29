// ★2026-09-30 老公报"我发送消息会弹出我发送两条消息，重复的同样的"——
// 这条测试把那次事故的真实形状钉住：服务端把你说的话广播回来（带同一个 cid），
// 手机端必须认出是本地那条，而不是画第二条。
import 'package:flutter_test/flutter_test.dart';
import 'package:baona_app/api.dart';

void main() {
  group('回声去重（发一条不能出两条）', () {
    test('① 带同一个 cid → 认出是本地那条，不新增', () {
      final list = <Msg>[
        Msg(role: 'me', content: '在干嘛', st: 'pending', cid: 'c1'),
      ];
      final echo = Msg(role: 'me', content: '在干嘛', st: 'ok', cid: 'c1');
      final i = findEchoTarget(list, echo, 'c1');
      expect(i, 0);
      // 模拟页面逻辑：就地升级
      list[i] = echo;
      expect(list.length, 1);
      expect(list.first.st, 'ok');
    });

    test('② 本地已确认（st=ok）时广播才回来 → 依然认得出，不新增（当时就是这样出的两条）', () {
      final list = <Msg>[
        Msg(role: 'me', content: '在干嘛', st: 'ok', cid: 'c1'),
      ];
      final echo = Msg(role: 'me', content: '在干嘛', st: 'ok', cid: 'c1');
      expect(findEchoTarget(list, echo, 'c1'), 0);
    });

    test('③ 服务端推了两遍（同 cid）→ 第二遍还是认得出，列表长度不变', () {
      final list = <Msg>[Msg(role: 'me', content: '在干嘛', st: 'pending', cid: 'c1')];
      final e1 = Msg(role: 'me', content: '在干嘛', st: 'ok', cid: 'c1');
      final i1 = findEchoTarget(list, e1, 'c1');
      expect(i1, 0);
      list[i1] = e1;
      final e2 = Msg(role: 'me', content: '在干嘛', st: 'ok', cid: 'c1');
      final i2 = findEchoTarget(list, e2, 'c1');
      expect(i2, 0);
      list[i2] = e2;
      expect(list.length, 1);
    });

    test('④ 没带 cid 的旧形状 → 退回"内容 + pending"也能认', () {
      final list = <Msg>[Msg(role: 'me', content: '吃饭了没', st: 'pending')];
      final echo = Msg(role: 'me', content: '吃饭了没', st: 'ok');
      expect(findEchoTarget(list, echo, ''), 0);
    });

    test('⑤ 她的话（assistant）永远不该被当成"自己那条"', () {
      final list = <Msg>[Msg(role: 'assistant', content: '哈啊～老公', st: 'ok', cid: 'c1')];
      final echo = Msg(role: 'assistant', content: '哈啊～老公', st: 'ok', cid: 'c1');
      expect(findEchoTarget(list, echo, 'c1'), -1); // -1 = 新消息，正常加
    });

    test('⑥ 真的是新消息 → -1（要新增）', () {
      final list = <Msg>[Msg(role: 'me', content: '在干嘛', st: 'ok', cid: 'c1')];
      final fresh = Msg(role: 'me', content: '想你了', st: 'ok', cid: 'c2');
      expect(findEchoTarget(list, fresh, 'c2'), -1);
    });
  });
}
