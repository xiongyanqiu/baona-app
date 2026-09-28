// 她的消息 → 手机通知
//
// 为什么不用系统推送：自签的 App 没有 APNs 权限（要苹果开发者账号）。
// 所以走这条自签能用、又不违法的路：
//   1) App 在后台时循环播一段「静音」，iOS 就不会把 App 冻住 → 长连接还活着
//   2) 她的消息从长连接一到，就用「本地通知」弹出来（+ 声音 + 角标）
// 代价：后台常驻会耗一点电。你从后台划掉 App 就收不到了（这个真没办法）。
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class Notify {
  Notify._();
  static final Notify i = Notify._();

  static bool get _mobile => !kIsWeb && (Platform.isIOS || Platform.isAndroid);

  final _p = FlutterLocalNotificationsPlugin();
  final _bg = AudioPlayer();
  bool _ready = false;
  bool _bgOn = false;
  bool _asked = false;
  int _seq = 1;

  /// App 现在在前台吗（在后台才弹通知，不然你在里面聊着还叮叮响）
  bool foreground = true;

  Future<void> init() async {
    if (!_mobile || _ready) return;
    _ready = true;
    try {
      const ios = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      await _p.initialize(const InitializationSettings(
        iOS: ios,
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ));
    } catch (_) {}
  }

  /// 登录进 App 后问一次通知权限
  Future<void> ask() async {
    if (!_mobile || _asked) return;
    _asked = true;
    await init();
    try {
      await _p
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } catch (_) {}
  }

  /// 弹一条通知
  Future<void> show(String title, String body, {bool vibrate = true}) async {
    if (!_mobile) return;
    await init();
    final t = clean(body);
    if (t.isEmpty) return;
    try {
      await _p.show(
        _seq++,
        title,
        t,
        NotificationDetails(
          iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true, presentBadge: true),
          android: AndroidNotificationDetails(
            'baona-msg',
            '包娜的消息',
            channelDescription: '她发消息时弹出来',
            importance: Importance.high,
            priority: Priority.high,
            enableVibration: vibrate,
          ),
        ),
      );
    } catch (_) {}
  }

  /// 清掉不该给用户看的标记（工具标记 / 眼镜指令），并压短一点
  static String clean(String s) {
    var t = s
        .replaceAll(RegExp(r'<<[^>]*>>'), '')
        .replaceAll(RegExp(r'\[\[[^\]]*\]\]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (t.length > 60) t = '${t.substring(0, 60)}…';
    return t;
  }

  /// 切后台/回前台
  Future<void> background(bool bg) async {
    foreground = !bg;
    if (!_mobile) return;
    try {
      if (bg) {
        if (_bgOn) return;
        _bgOn = true;
        await _bg.setReleaseMode(ReleaseMode.loop);
        await _bg.setVolume(0);
        await _bg.setAudioContext(AudioContext(
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: const {AVAudioSessionOptions.mixWithOthers},
          ),
          android: AudioContextAndroid(isSpeakerphoneOn: false, stayAwake: true),
        ));
        await _bg.play(AssetSource('silence.wav'));
      } else {
        if (!_bgOn) return;
        _bgOn = false;
        await _bg.stop();
      }
    } catch (_) {}
  }

  void dispose() {
    try {
      _bg.dispose();
    } catch (_) {}
  }
}
